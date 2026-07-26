'use strict';

const assert = require('assert');
const {
  resolveBurpHost,
  resolveBurpPort,
  resolveBurpToken,
} = require('./mcp-bridge');

assert.strictEqual(resolveBurpHost('localhost'), '127.0.0.1');
assert.strictEqual(resolveBurpPort('9876'), 9876);
assert.strictEqual(resolveBurpToken('0123456789abcdef0123456789abcdef'), '0123456789abcdef0123456789abcdef');
assert.throws(() => resolveBurpHost('example.com'), /loopback/);
assert.throws(() => resolveBurpPort('9876abc'), /integer/);
assert.throws(() => resolveBurpPort('0'), /1-65535/);
assert.throws(() => resolveBurpToken(''), /required/);
assert.throws(() => resolveBurpToken('12345678'), /32 characters/);

process.stdout.write('BRIDGE SECURITY TESTS PASSED\n');
