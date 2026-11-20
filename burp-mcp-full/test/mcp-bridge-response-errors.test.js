'use strict';

const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const http = require('node:http');
const path = require('node:path');
const readline = require('node:readline');
const { test } = require('node:test');

async function runFixture(handler, check) {
  const server = http.createServer(handler);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const bridge = spawn(process.execPath, [path.join(__dirname, '..', 'mcp-bridge.js')], {
    env: {
      ...process.env,
      BURP_MCP_HOST: '127.0.0.1',
      BURP_MCP_PORT: String(server.address().port),
      BURP_MCP_TOKEN: 'response-error-fixture-token'
    },
    stdio: ['pipe', 'pipe', 'pipe']
  });
  const waiters = new Map();
  let stderr = '';
  bridge.stderr.setEncoding('utf8');
  bridge.stderr.on('data', chunk => { stderr += chunk; });
  const output = readline.createInterface({ input: bridge.stdout });
  output.on('line', line => {
    const message = JSON.parse(line);
    const waiter = waiters.get(message.id);
    if (waiter) waiter.resolve(message);
  });
  const closed = new Promise(resolve => bridge.once('close', code => {
    for (const waiter of waiters.values()) waiter.reject(new Error(`bridge exited ${code}: ${stderr}`));
    resolve();
  }));
  let nextId = 0;
  function request(method, params) {
    const id = ++nextId;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => finish(reject, new Error(`no response to ${method}: ${stderr}`)), 5000);
      function finish(callback, result) {
        clearTimeout(timer);
        waiters.delete(id);
        callback(result);
      }
      waiters.set(id, {
        resolve: result => finish(resolve, result),
        reject: error => finish(reject, error)
      });
      bridge.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
    });
  }
  try {
    await check(request, bridge);
  } finally {
    bridge.stdin.end();
    bridge.kill();
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    await closed;
    output.close();
  }
}

function interruptResponse(response) {
  response.writeHead(200, { 'Content-Type': 'application/json', 'Content-Length': 1000 });
  // Send headers and some body bytes before dropping the connection. This is
  // an IncomingMessage error after a response exists, not a connection refusal.
  response.write('{"partial":', () => setTimeout(() => response.destroy(), 30));
}

test('recovers when initial tool discovery loses its response body', async () => {
  let discoveries = 0;
  await runFixture((request, response) => {
    assert.equal(request.method, 'GET');
    assert.equal(request.url, '/tools');
    if (++discoveries === 1) {
      interruptResponse(response);
    } else {
      response.end(JSON.stringify(['proxy_history']));
    }
  }, async request => {
    const initialized = await request('initialize');
    assert.equal(initialized.result.serverInfo.name, 'burpsuite-mcp');
    // Initialization does not promise that background discovery has finished.
    // If it is still in flight, this request shares its failure; a later
    // explicit list request must then be able to discover the backend again.
    let listed = await request('tools/list');
    if (listed.error) {
      assert.equal(listed.error.code, -32000);
      listed = await request('tools/list');
    }
    assert.equal(listed.result.tools[0].name, 'burp_proxy_history');
    assert.equal(discoveries, 2);
  });
});

test('reports an interrupted tool response without replaying the call', async () => {
  let discoveries = 0;
  let calls = 0;
  await runFixture((request, response) => {
    if (request.method === 'GET') {
      discoveries++;
      response.end(JSON.stringify(['proxy_history']));
      return;
    }
    assert.equal(request.method, 'POST');
    request.resume();
    if (++calls === 1) {
      interruptResponse(response);
    } else {
      response.end(JSON.stringify({ ok: true }));
    }
  }, async (request, bridge) => {
    await request('initialize');
    const failed = await request('tools/call', { name: 'burp_proxy_history', arguments: { limit: 1 } });
    assert.equal(failed.error.code, -1);
    assert.match(failed.error.message, /aborted/i);
    assert.equal(calls, 1);
    assert.equal(bridge.exitCode, null);
    const listed = await request('tools/list');
    assert.equal(listed.result.tools[0].name, 'burp_proxy_history');
    assert.equal(discoveries, 2);
    assert.equal(calls, 1);
    const called = await request('tools/call', { name: 'burp_proxy_history', arguments: { limit: 1 } });
    assert.deepEqual(JSON.parse(called.result.content[0].text), { ok: true });
    assert.equal(calls, 2);
  });
});
