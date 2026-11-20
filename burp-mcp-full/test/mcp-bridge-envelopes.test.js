'use strict';

const assert = require('node:assert/strict');
const { once } = require('node:events');
const http = require('node:http');
const { spawn } = require('node:child_process');
const { test } = require('node:test');
const path = require('node:path');

async function exchange(lines, { rejectCalls = false } = {}) {
  const calls = [];
  const server = http.createServer((request, response) => {
    if (request.url === '/tools') {
      response.writeHead(200, { 'Content-Type': 'application/json' });
      response.end(JSON.stringify(['fixture']));
      return;
    }
    let body = '';
    request.setEncoding('utf8');
    request.on('data', chunk => { body += chunk; });
    request.on('end', () => {
      calls.push(JSON.parse(body));
      response.writeHead(rejectCalls ? 403 : 200, { 'Content-Type': 'application/json' });
      response.end(JSON.stringify({ ok: !rejectCalls }));
    });
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const bridge = spawn(process.execPath, [path.join(__dirname, '..', 'mcp-bridge.js')], {
    env: { ...process.env, BURP_MCP_HOST: '127.0.0.1', BURP_MCP_PORT: String(server.address().port),
      BURP_MCP_TOKEN: 'envelope-fixture-token' },
    stdio: ['pipe', 'pipe', 'pipe']
  });
  let output = '';
  let errors = '';
  bridge.stdout.setEncoding('utf8');
  bridge.stderr.setEncoding('utf8');
  bridge.stdout.on('data', chunk => { output += chunk; });
  const closed = once(bridge, 'close');
  const ready = new Promise(resolve => {
    bridge.stderr.on('data', chunk => {
      errors += chunk;
      if (errors.includes('Connected to Burp.')) resolve();
    });
  });
  let timeout;
  const deadline = new Promise((_, reject) => {
    timeout = setTimeout(() => reject(new Error('Bridge fixture timed out: ' + errors)), 5000);
  });
  // Install the deadline handler immediately, including while awaiting startup.
  try {
    await Promise.race([ready, closed.then(() => { throw new Error('Bridge exited before discovery: ' + errors); }), deadline]);
    bridge.stdin.end(lines.map(value => typeof value === 'string' ? value : JSON.stringify(value)).join('\n') + '\n');
    const [code, signal] = await Promise.race([closed, deadline]);
    assert.equal(signal, null, errors);
    assert.equal(code, 0, errors);
    return { responses: output.trim() ? output.trim().split('\n').map(line => JSON.parse(line)) : [], calls, errors };
  } finally {
    clearTimeout(timeout);
    if (bridge.exitCode === null && bridge.signalCode === null) bridge.kill();
    await closed.catch(() => {});
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
  }
}

const request = (id, method, params) => ({ jsonrpc: '2.0', id, method, ...(params === undefined ? {} : { params }) });

test('null input is rejected without losing following initialization and tool requests', async () => {
  const { responses, calls } = await exchange([
    'null', request('initialize-after-null', 'initialize'),
    request(0, 'tools/call', { name: 'burp_fixture', arguments: { value: 'kept' } })
  ]);
  assert.equal(responses.length, 3);
  assert.deepEqual(responses.find(response => response.id === null), {
    jsonrpc: '2.0', id: null, error: { code: -32600, message: 'Invalid Request' }
  });
  assert.equal(responses.find(response => response.id === 'initialize-after-null').result.serverInfo.name, 'burpsuite-mcp');
  assert.match(responses.find(response => response.id === 0).result.content[0].text, /"ok": true/);
  assert.deepEqual(calls, [{ tool: 'fixture', params: { value: 'kept' } }]);
});

test('malformed MCP envelopes cannot reach tool dispatch and preserve parse errors', async () => {
  const invalid = [
    'true', '42', '"text"', '[]', '{}',
    { id: 1, method: 'tools/call', params: { name: 'burp_fixture' } },
    { jsonrpc: '1.0', id: 2, method: 'tools/call', params: { name: 'burp_fixture' } },
    { jsonrpc: '2.0', id: 3, method: 1 },
    { jsonrpc: '2.0', id: 4 },
    request(true, 'tools/call', { name: 'burp_fixture' }),
    request({}, 'tools/call', { name: 'burp_fixture' }),
    request([], 'tools/call', { name: 'burp_fixture' }),
    request(null, 'tools/call', { name: 'burp_fixture' }),
    request(5, 'tools/call', null), request(6, 'tools/call', []),
    request(7, 'tools/call', 'wrong')
  ];
  const { responses, calls } = await exchange([...invalid, '{', request('alive', 'initialize')]);
  assert.equal(responses.length, invalid.length + 2);
  const rejected = responses.filter(response => response.error?.code === -32600);
  assert.equal(rejected.length, invalid.length);
  assert.ok(rejected.every(response => response.jsonrpc === '2.0' && response.id === null));
  assert.equal(responses.filter(response => response.error?.code === -32700).length, 1);
  assert.ok(responses.find(response => response.id === 'alive').result);
  assert.deepEqual(calls, []);
});

test('valid notifications produce no response while request identifiers remain intact', async () => {
  const { responses, calls } = await exchange([
    { jsonrpc: '2.0', method: 'notifications/initialized' },
    { jsonrpc: '2.0', method: 'notifications/cancelled', params: { requestId: 999 } },
    { jsonrpc: '2.0', method: 'notifications/unknown', params: {} },
    request(0, 'unknown-method'), request('missing-name', 'tools/call', {}),
    request('ordinary', 'initialize')
  ]);
  assert.equal(responses.length, 3);
  assert.equal(responses.find(response => response.id === 0).error.code, -32601);
  assert.equal(responses.find(response => response.id === 'missing-name').error.code, -32602);
  assert.ok(responses.find(response => response.id === 'ordinary').result);
  assert.deepEqual(calls, []);
});

test('a failing notification stays silent and does not stop the following request', async () => {
  const { responses, calls } = await exchange([
    { jsonrpc: '2.0', method: 'tools/call', params: { name: 'burp_fixture' } },
    request('after-notification', 'initialize')
  ], { rejectCalls: true });
  assert.equal(calls.length, 1);
  assert.equal(responses.length, 1);
  assert.equal(responses[0].id, 'after-notification');
  assert.ok(responses[0].result);
});
