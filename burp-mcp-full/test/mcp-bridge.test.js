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

test('preserves UTF-8 characters split across HTTP response chunks', async () => {
  const values = ['caf\u00e9', '\u767b\u5f55\u6210\u529f', '\ud83d\ude80'];
  let calls = 0;
  const server = http.createServer((request, response) => {
    if (request.method === 'GET' && request.url === '/tools') {
      response.writeHead(200, { 'Content-Type': 'application/json' });
      response.end(JSON.stringify(['proxy_detail']));
      return;
    }
    request.resume();
    request.on('end', () => {
      const text = values[calls++];
      const data = Buffer.from(JSON.stringify({ response: text }), 'utf8');
      const split = data.findIndex(byte => byte >= 0x80) + 1;
      response.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      // Flush an incomplete two-, three- or four-byte character separately.
      response.write(data.subarray(0, split));
      setTimeout(() => response.end(data.subarray(split)), 20);
    });
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
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
  try {
    assert.match(await stderr.next(), /Connected to Burp/);
    for (let index = 0; index < values.length; index++) {
      bridge.stdin.write(JSON.stringify({
        jsonrpc: '2.0', id: index + 1, method: 'tools/call',
        params: { name: 'burp_proxy_detail', arguments: { index } }
      }) + '\n');
      const result = JSON.parse(await stdout.next());
      assert.equal(result.id, index + 1);
      assert.deepEqual(JSON.parse(result.result.content[0].text), { response: values[index] });
    }
    assert.equal(calls, values.length);
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
