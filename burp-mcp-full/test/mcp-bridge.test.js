'use strict';

const assert = require('node:assert/strict');
const { once } = require('node:events');
const http = require('node:http');
const net = require('node:net');
const { spawn } = require('node:child_process');
const { test } = require('node:test');
const path = require('node:path');

class LineReader {
  constructor(stream) {
    this.lines = [];
    this.waiters = [];
    this.buffer = '';
    stream.setEncoding('utf8');
    stream.on('data', chunk => {
      this.buffer += chunk;
      const parts = this.buffer.split('\n');
      this.buffer = parts.pop();
      for (const line of parts) {
        this.push(line.replace(/\r$/, ''));
      }
    });
  }

  push(line) {
    const waiter = this.waiters.shift();
    if (waiter) {
      waiter.resolve(line);
    } else {
      this.lines.push(line);
    }
  }

  next(timeoutMs = 5000) {
    if (this.lines.length > 0) return Promise.resolve(this.lines.shift());
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        const index = this.waiters.indexOf(waiter);
        if (index >= 0) this.waiters.splice(index, 1);
        reject(new Error('Timed out waiting for a line'));
      }, timeoutMs);
      const waiter = {
        resolve: line => {
          clearTimeout(timeout);
          resolve(line);
        }
      };
      this.waiters.push(waiter);
    });
  }
}

function getFreePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });
}

function close(server) {
  if (!server) return Promise.resolve();
  return new Promise(resolve => server.close(() => resolve()));
}

for (const initialStatus of [200, 503]) {
  test(`initializes during pending tool discovery (HTTP ${initialStatus})`, async () => {
    let toolsResponse;
    let toolsRequests = 0;
    const calls = [];
    const server = http.createServer((request, response) => {
      if (request.method === 'GET' && request.url === '/tools') {
        toolsRequests++;
        if (toolsRequests === 1) {
          // Release startup discovery only after initialize and concurrent requests.
          toolsResponse = response;
        } else {
          response.writeHead(200, { 'Content-Type': 'application/json' });
          response.end(JSON.stringify(['proxy_history']));
        }
        return;
      }
      assert.equal(request.method, 'POST');
      assert.equal(request.url, '/');
      let body = '';
      request.on('data', chunk => { body += chunk; });
      request.on('end', () => {
        calls.push(JSON.parse(body));
        response.writeHead(200, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify({ ok: true }));
      });
    });
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const toolsRequested = once(server, 'request', { signal: AbortSignal.timeout(5000) });
    const bridge = spawn(process.execPath, [path.join(__dirname, '..', 'mcp-bridge.js')], {
      env: {
        ...process.env,
        BURP_MCP_HOST: '127.0.0.1',
        BURP_MCP_PORT: String(server.address().port),
        BURP_MCP_TOKEN: 'test-token'
      },
      stdio: ['pipe', 'pipe', 'pipe']
    });
    const stdout = new LineReader(bridge.stdout);
    const stderr = new LineReader(bridge.stderr);
    const send = message => bridge.stdin.write(JSON.stringify({ jsonrpc: '2.0', ...message }) + '\n');
    try {
      await toolsRequested;
      send({
        id: 1, method: 'initialize',
        params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'fixture', version: '1' } }
      });
      const initialized = JSON.parse(await stdout.next());
      assert.equal(initialized.id, 1);
      assert.equal(initialized.result.serverInfo.name, 'burpsuite-mcp');

      send({ method: 'notifications/initialized' });
      send({ id: 2, method: 'tools/list' });
      send({ id: 3, method: 'tools/list' });
      send({ id: 4, method: 'tools/call', params: { name: 'burp_proxy_history', arguments: { limit: 1 } } });
      // An unrelated method response proves all preceding lines were read while
      // the same backend discovery request was still pending.
      send({ id: 5, method: 'fixture/barrier' });
      const barrier = JSON.parse(await stdout.next());
      assert.equal(barrier.id, 5);
      assert.equal(barrier.error.code, -32601);
      assert.equal(toolsRequests, 1);
      assert.deepEqual(calls, []);

      toolsResponse.writeHead(initialStatus, { 'Content-Type': 'application/json' });
      toolsResponse.end(JSON.stringify(initialStatus === 200 ? ['proxy_history'] : { error: 'not ready' }));
      assert.match(await stderr.next(), initialStatus === 200 ? /Connected to Burp/ : /Cannot connect to Burp/);
      const responses = new Map();
      for (let i = 0; i < 3; i++) {
        const response = JSON.parse(await stdout.next());
        responses.set(response.id, response);
      }
      assert.deepEqual([...responses.keys()].sort(), [2, 3, 4]);
      assert.equal(toolsRequests, 1);
      if (initialStatus === 200) {
        for (const id of [2, 3]) {
          assert.equal(responses.get(id).result.tools[0].name, 'burp_proxy_history');
        }
        assert.match(responses.get(4).result.content[0].text, /"ok": true/);
      } else {
        for (const response of responses.values()) {
          assert.equal(response.error.code, -32000);
        }
        assert.deepEqual(calls, []);
        send({ id: 6, method: 'tools/list' });
        const retried = JSON.parse(await stdout.next());
        assert.equal(retried.id, 6);
        assert.equal(retried.result.tools[0].name, 'burp_proxy_history');
        assert.match(await stderr.next(), /Connected to Burp/);
        assert.equal(toolsRequests, 2);
        send({ id: 7, method: 'tools/call', params: { name: 'burp_proxy_history', arguments: { limit: 1 } } });
        const called = JSON.parse(await stdout.next());
        assert.equal(called.id, 7);
        assert.match(called.result.content[0].text, /"ok": true/);
      }
      assert.deepEqual(calls, [{ tool: 'proxy_history', params: { limit: 1 } }]);
    } finally {
      const childClosed = bridge.exitCode === null && bridge.signalCode === null
        ? once(bridge, 'close')
        : Promise.resolve();
      bridge.stdin.end();
      bridge.kill();
      await close(server);
      await childClosed.catch(() => {});
    }
  });
}

test('reconnects after Burp starts and handles a later tool call', async () => {
  const port = await getFreePort();
  const bridgePath = path.join(__dirname, '..', 'mcp-bridge.js');
  const bridge = spawn(process.execPath, [bridgePath], {
    env: {
      ...process.env,
      BURP_MCP_HOST: '127.0.0.1',
      BURP_MCP_PORT: String(port),
      BURP_MCP_TOKEN: 'test-token'
    },
    stdio: ['pipe', 'pipe', 'pipe']
  });
  const stdout = new LineReader(bridge.stdout);
  const stderr = new LineReader(bridge.stderr);
  let server;
  const requests = [];

  try {
    const warning = await stderr.next();
    assert.match(warning, /Cannot connect to Burp/);

    server = http.createServer((request, response) => {
      if (request.method === 'GET' && request.url === '/tools') {
        response.writeHead(200, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify(['proxy_history']));
        return;
      }

      let body = '';
      request.on('data', chunk => { body += chunk; });
      request.on('end', () => {
        requests.push(JSON.parse(body));
        response.writeHead(200, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify({ ok: true }));
      });
    });
    await new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(port, '127.0.0.1', resolve);
    });

    bridge.stdin.write(JSON.stringify({
      jsonrpc: '2.0',
      id: 1,
      method: 'tools/list',
      params: {}
    }) + '\n');
    const listResponse = JSON.parse(await stdout.next());
    assert.equal(listResponse.id, 1);
    assert.equal(listResponse.result.tools[0].name, 'burp_proxy_history');

    bridge.stdin.write(JSON.stringify({
      jsonrpc: '2.0',
      id: 2,
      method: 'tools/call',
      params: { name: 'burp_proxy_history', arguments: { limit: 1 } }
    }) + '\n');
    const callResponse = JSON.parse(await stdout.next());
    assert.equal(callResponse.id, 2);
    assert.deepEqual(requests[0], { tool: 'proxy_history', params: { limit: 1 } });
    assert.match(callResponse.result.content[0].text, /"ok": true/);
  } finally {
    const childClosed = bridge.exitCode === null && bridge.signalCode === null
      ? once(bridge, 'close')
      : Promise.resolve();
    bridge.stdin.end();
    bridge.kill();
    await close(server);
    await childClosed.catch(() => {});
  }
});
