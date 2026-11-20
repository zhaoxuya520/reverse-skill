#!/usr/bin/env node
/**
 * BurpSuite MCP Stdio Bridge
 * 
 * Bridges the custom HTTP API (port 9876) to standard MCP JSON-RPC 2.0 stdio protocol.
 * This allows any MCP client (Claude Code, Kiro, Cursor, Cline, etc.) to use all 78 Burp tools.
 * 
 * Cross-platform: Works on Windows, Linux (Kali), macOS.
 * 
 * Usage in MCP config (all platforms):
 *   { "command": "node", "args": ["<path-to-this-file>/mcp-bridge.js"] }
 * 
 * Environment variables:
 *   BURP_MCP_HOST - Burp HTTP API host (default: 127.0.0.1)
 *   BURP_MCP_PORT - Burp HTTP API port (default: 9876)
 */

const http = require('http');
const readline = require('readline');
const fs = require('fs');
const os = require('os');
const path = require('path');

const BURP_HOST = process.env.BURP_MCP_HOST || '127.0.0.1';
const BURP_PORT = parseInt(process.env.BURP_MCP_PORT || '9876', 10);

function resolveToken() {
  if (process.env.BURP_MCP_TOKEN) return process.env.BURP_MCP_TOKEN;
  try {
    const tokenFile = path.join(os.homedir(), '.burp-mcp-token');
    if (fs.existsSync(tokenFile)) return fs.readFileSync(tokenFile, 'utf8').trim();
  } catch (e) { /* ignore */ }
  return null;
}

const BURP_TOKEN = resolveToken();
const AUTH_HEADERS = BURP_TOKEN ? { 'Authorization': `Bearer ${BURP_TOKEN}` } : {};

let TOOLS = null;
let toolsRequest = null;

async function fetchTools() {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: BURP_HOST, port: BURP_PORT, path: '/tools', method: 'GET',
      headers: AUTH_HEADERS
    }, (res) => {
      res.on('error', reject);
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode !== 200) {
          reject(new Error(`Cannot fetch tools: HTTP ${res.statusCode} ${data.slice(0, 200)}`));
          return;
        }
        try { resolve(JSON.parse(data)); } catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

function disconnectedResponse(id) {
  return {
    jsonrpc: '2.0',
    id,
    error: {
      code: -32000,
      message: `Burp MCP not connected at ${BURP_HOST}:${BURP_PORT}. Start Burp with the "MCP Full Control" extension loaded, then retry.`
    }
  };
}

async function ensureTools() {
  if (TOOLS) return TOOLS;
  if (!toolsRequest) {
    toolsRequest = fetchTools()
      .then(tools => {
        TOOLS = tools;
        process.stderr.write(`[burp-mcp-bridge] Connected to Burp. ${TOOLS.length} tools available.\n`);
        return TOOLS;
      })
      .finally(() => {
        toolsRequest = null;
      });
  }
  return toolsRequest;
}

async function callTool(toolName, params) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ tool: toolName, params: params || {} });
    const req = http.request({
      hostname: BURP_HOST, port: BURP_PORT, path: '/', method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body), ...AUTH_HEADERS }
    }, (res) => {
      res.on('error', reject);
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 403) {
          reject(new Error('Burp MCP rejected the request: missing or invalid BURP_MCP_TOKEN. Set BURP_MCP_TOKEN to match the token in ~/.burp-mcp-token.'));
          return;
        }
        try { resolve(JSON.parse(data)); } catch (e) { resolve({ error: data }); }
      });
    });
    req.on('error', (err) => {
      reject(new Error(
        `Cannot reach Burp MCP at ${BURP_HOST}:${BURP_PORT} (${err.code || err.message}). ` +
        `Ensure Burp Suite is running with the "MCP Full Control" extension loaded. ` +
        `If the port differs, set BURP_MCP_PORT and -Dburp.mcp.port=<same> on Burp.`
      ));
    });
    req.write(body);
    req.end();
  });
}

function buildToolDefinitions(toolNames) {
  return toolNames.map(name => ({
    name: `burp_${name}`,
    description: getToolDescription(name),
    inputSchema: {
      type: 'object',
      properties: getToolParams(name),
    }
  }));
}

function getToolDescription(name) {
  const descriptions = {
    proxy_history: 'Get Burp proxy history with optional filtering by URL, method, status code',
    proxy_detail: 'Get full request/response details for a specific proxy history item by index',
    proxy_websocket: 'Get WebSocket message history',
    proxy_clear: 'Clear proxy history',
    proxy_history_filtered: 'Filter proxy history by annotation color or notes',
    send_request: 'Send an HTTP request through Burp and get the response',
    send_to_repeater: 'Send a raw request to Burp Repeater tab',
    repeater_send: 'Send a request and get response (like Repeater)',
    repeater_modify_send: 'Modify headers/body of a request then send it',
    send_to_intruder: 'Send a request to Burp Intruder',
    intruder_attack: 'Run a numeric range brute force attack (synchronous)',
    intruder_attack_async: 'Run a multi-threaded numeric range brute force attack',
    intruder_attack_wordlist: 'Run a wordlist-based attack',
    intruder_pitchfork: 'Run a Pitchfork attack (parallel multi-param)',
    intruder_cluster_bomb: 'Run a Cluster Bomb attack (cartesian product multi-param)',
    intruder_battering_ram: 'Run a Battering Ram attack (same payload all positions)',
    intruder_with_options: 'Run attack with advanced options (throttle, encoding, grep, timing)',
    sitemap: 'Get site map entries with optional URL prefix filter',
    target_info: 'Get target information (hosts, technologies detected)',
    intercept_toggle: 'Enable or disable proxy intercept',
    encode: 'Encode a string (base64, url, hex)',
    decode: 'Decode a string (base64, url)',
    convert_request: 'Convert HTTP request method (e.g. GET to POST)',
    export_request: 'Export a request as curl command',
    generate_csrf_poc: 'Generate a CSRF proof-of-concept HTML page',
    extract_from_response: 'Extract data from a response using regex',
    payload_process: 'Process a payload (hash, encode, reverse, etc.)',
    scan: 'Start a vulnerability scan',
    scan_active: 'Start active scan on a specific request',
    scan_results: 'Get scan results (discovered vulnerabilities)',
    scan_issue_detail: 'Get detailed information about a specific scan issue',
    crawl: 'Start crawling a URL (adds to scope)',
    get_scope: 'Check if a URL is in Burp scope',
    add_to_scope: 'Add a URL to Burp scope',
    remove_from_scope: 'Remove a URL from Burp scope',
    collaborator_generate: 'Generate Burp Collaborator payloads for OOB testing',
    collaborator_poll: 'Poll for Collaborator interactions (DNS/HTTP callbacks)',
    search_history: 'Search proxy history with regex (in URL, request, or response)',
    highlight: 'Highlight a proxy history item with a color',
    annotate: 'Add a note/annotation to a proxy history item',
    compare: 'Compare two proxy history responses (diff)',
    export_config: 'Export Burp project configuration as JSON',
    import_config: 'Import Burp project configuration from JSON',
    set_upstream_proxy: 'Set upstream proxy (SOCKS/HTTP) for all Burp traffic',
    set_dns_override: 'Override DNS resolution for a hostname',
    set_http2: 'Enable or disable HTTP/2',
    cookie_jar: 'View cookies in Burp cookie jar (with optional domain filter)',
    token_analysis: 'Analyze token entropy and randomness',
    sequencer: 'Analyze a batch of tokens for randomness quality',
    save_project: 'Save the current Burp project',
    burp_version: 'Get Burp Suite version information',
    add_issue: 'Manually add a vulnerability issue to the site map',
    register_http_handler: 'Register an auto-modify rule for HTTP requests (add header or replace text)',
    remove_http_handler: 'Remove/clear HTTP handler rules',
    register_proxy_rule: 'Register a proxy intercept rule (intercept URLs containing a string)',
    remove_proxy_rule: 'Remove/clear proxy intercept rules',
    extensions_list: 'Get information about loaded extensions',
    log: 'Write a message to Burp extension output log',
    audit_log: 'View audit log entries',
    privacy_mode: 'Set privacy mode (strict/off)',
    scope_gate: 'Enable/disable scope gate',
    inline_fuzzer: 'FUZZ marker fuzzing',
    race_condition: 'Race condition testing',
    access_control_sweep: 'Test different auth levels',
    injection_probe: 'SQLi/SSTI/LFI probe',
    jwt_attack: 'JWT attacks (alg:none)',
    jwt_decode: 'Decode JWT tokens',
    session_remove_rule: 'Remove session rule',
    session_list_rules: 'List session rules',
    session_create_rule: 'Create session handling rule',
    passive_intel: 'Extract secrets from proxy history',
    websocket_list: 'List active WebSockets',
    websocket_close: 'Close WebSocket',
    websocket_send_binary: 'Send binary on WebSocket',
    websocket_send_text: 'Send text on WebSocket',
    websocket_create: 'Create WebSocket connection',
    send_request_parallel: 'Send parallel HTTP requests',
    cookie_jar_set: 'Set cookie in Burp cookie jar',
  };
  return descriptions[name] || `Burp Suite tool: ${name}`;
}

function getToolParams(name) {
  // Common parameter schemas
  const schemas = {
    proxy_history: { limit: {type:'number',description:'Max items (default 100)'}, offset: {type:'number'}, url_filter: {type:'string'}, method_filter: {type:'string'}, status_filter: {type:'number'} },
    proxy_detail: { index: {type:'number',description:'History item index'} },
    proxy_websocket: { limit: {type:'number'} },
    proxy_history_filtered: { has_notes: {type:'string'}, color: {type:'string'}, limit: {type:'number'} },
    send_request: { method: {type:'string'}, url: {type:'string',description:'Full URL'}, body: {type:'string'}, headers: {type:'object'} },
    repeater_send: { request: {type:'string',description:'Raw HTTP request'}, host: {type:'string'}, port: {type:'number'}, https: {type:'boolean'} },
    repeater_modify_send: { request: {type:'string'}, host: {type:'string'}, port: {type:'number'}, https: {type:'boolean'}, replace_header: {type:'object'}, add_header: {type:'object'}, replace_body: {type:'string'} },
    send_to_repeater: { request: {type:'string'}, tab_name: {type:'string'} },
    send_to_intruder: { request: {type:'string'} },
    intruder_attack: { url_template: {type:'string',description:'URL with @@ placeholder'}, from: {type:'number'}, to: {type:'number'}, pad_digits: {type:'number'}, method: {type:'string'}, headers: {type:'object'}, success_length_not: {type:'number'}, success_contains: {type:'string'} },
    intruder_attack_async: { url_template: {type:'string'}, from: {type:'number'}, to: {type:'number'}, pad_digits: {type:'number'}, method: {type:'string'}, headers: {type:'object'}, success_length_not: {type:'number'}, threads: {type:'number'} },
    intruder_attack_wordlist: { url_template: {type:'string'}, wordlist: {type:'array',items:{type:'string'}}, method: {type:'string'}, headers: {type:'object'}, success_length_not: {type:'number'}, body_template: {type:'string'} },
    intruder_pitchfork: { url_template: {type:'string'}, placeholders: {type:'object'}, method: {type:'string'}, headers: {type:'object'}, success_length_not: {type:'number'} },
    intruder_cluster_bomb: { url_template: {type:'string'}, placeholders: {type:'object'}, method: {type:'string'}, headers: {type:'object'}, success_length_not: {type:'number'}, max_requests: {type:'number'} },
    intruder_battering_ram: { url_template: {type:'string'}, wordlist: {type:'array',items:{type:'string'}}, placeholder: {type:'string'}, method: {type:'string'}, headers: {type:'object'}, success_length_not: {type:'number'} },
    intruder_with_options: { url_template: {type:'string'}, from: {type:'number'}, to: {type:'number'}, pad_digits: {type:'number'}, method: {type:'string'}, headers: {type:'object'}, success_length_not: {type:'number'}, throttle_ms: {type:'number'}, payload_prefix: {type:'string'}, payload_suffix: {type:'string'}, payload_encoding: {type:'string'}, grep_extract: {type:'string'}, record_time: {type:'boolean'} },
    sitemap: { url_prefix: {type:'string'}, limit: {type:'number'} },
    target_info: { url: {type:'string'} },
    intercept_toggle: { enable: {type:'boolean'} },
    encode: { input: {type:'string'}, type: {type:'string',description:'base64, url, or hex'} },
    decode: { input: {type:'string'}, type: {type:'string',description:'base64 or url'} },
    convert_request: { request: {type:'string'}, convert_to: {type:'string'} },
    export_request: { request: {type:'string'}, host: {type:'string'}, format: {type:'string',description:'curl or python'}, https: {type:'boolean'} },
    generate_csrf_poc: { request: {type:'string'}, host: {type:'string'}, https: {type:'boolean'} },
    extract_from_response: { index: {type:'number'}, regex: {type:'string'} },
    payload_process: { input: {type:'string'}, operation: {type:'string',description:'base64_encode/decode, url_encode/decode, md5, sha1, sha256, hex_encode, lowercase, uppercase, reverse, length'} },
    scan_active: { request: {type:'string'}, host: {type:'string'}, port: {type:'number'}, https: {type:'boolean'} },
    scan_results: { limit: {type:'number'} },
    scan_issue_detail: { index: {type:'number'} },
    crawl: { url: {type:'string'} },
    get_scope: { url: {type:'string'} },
    add_to_scope: { url: {type:'string'} },
    remove_from_scope: { url: {type:'string'} },
    collaborator_generate: { count: {type:'number'} },
    search_history: { regex: {type:'string'}, search_in: {type:'string',description:'url, request, or response'}, limit: {type:'number'} },
    highlight: { index: {type:'number'}, color: {type:'string'} },
    annotate: { index: {type:'number'}, note: {type:'string'} },
    compare: { index1: {type:'number'}, index2: {type:'number'} },
    import_config: { config: {type:'string'} },
    set_upstream_proxy: { proxy_host: {type:'string'}, proxy_port: {type:'number'}, type: {type:'string'} },
    set_dns_override: { hostname: {type:'string'}, ip: {type:'string'} },
    set_http2: { enable: {type:'boolean'} },
    cookie_jar: { limit: {type:'number'}, domain: {type:'string'} },
    token_analysis: { tokens: {type:'array',items:{type:'string'}} },
    sequencer: { tokens: {type:'array',items:{type:'string'}} },
    add_issue: { name: {type:'string'}, url: {type:'string'}, detail: {type:'string'}, severity: {type:'string'}, confidence: {type:'string'} },
    register_http_handler: { header_name: {type:'string'}, header_value: {type:'string'}, match: {type:'string'}, replace: {type:'string'} },
    register_proxy_rule: { url_contains: {type:'string'} },
    log: { message: {type:'string'}, level: {type:'string'} },
    audit_log: { limit: {type:'number'} },
    privacy_mode: { mode: {type:'string'} },
    scope_gate: { action: {type:'string'} },
    inline_fuzzer: { template: {type:'string'}, host: {type:'string'}, wordlist: {type:'array'} },
    race_condition: { request: {type:'string'}, host: {type:'string'}, count: {type:'number'} },
    access_control_sweep: { request: {type:'string'}, host: {type:'string'}, auth_headers: {type:'string'} },
    injection_probe: { url: {type:'string'}, param: {type:'string'}, type: {type:'string'} },
    jwt_attack: { token: {type:'string'}, attack: {type:'string'} },
    jwt_decode: { token: {type:'string'} },
    session_remove_rule: {},
    session_list_rules: {},
    session_create_rule: { find: {type:'string'}, replace: {type:'string'} },
    passive_intel: { limit: {type:'number'} },
    websocket_list: {},
    websocket_close: { id: {type:'string'} },
    websocket_send_binary: { id: {type:'string'}, data: {type:'string'} },
    websocket_send_text: { id: {type:'string'}, text: {type:'string'} },
    websocket_create: { host: {type:'string'}, port: {type:'number'} },
    send_request_parallel: { requests: {type:'array'} },
    cookie_jar_set: { url: {type:'string'}, name: {type:'string'}, value: {type:'string'} },
  };
  return schemas[name] || {};
}

async function handleRequest(msg) {
  const { method, id, params } = msg;

  switch (method) {
    case 'initialize':
      return { jsonrpc: '2.0', id, result: {
        protocolVersion: '2024-11-05',
        capabilities: { tools: {} },
        serverInfo: { name: 'burpsuite-mcp', version: '2.0.0' }
      }};

    case 'notifications/initialized':
      return null; // No response needed

    case 'tools/list':
      try {
        const tools = await ensureTools();
        return { jsonrpc: '2.0', id, result: { tools: buildToolDefinitions(tools) } };
      } catch (err) {
        return disconnectedResponse(id);
      }

    case 'tools/call': {
      try {
        await ensureTools();
      } catch (err) {
        return disconnectedResponse(id);
      }
      if (!params || typeof params.name !== 'string') {
        return { jsonrpc: '2.0', id, error: { code: -32602, message: 'tools/call requires params.name' } };
      }
      const toolName = params.name.replace(/^burp_/, '');
      const toolArgs = params.arguments || {};
      try {
        const result = await callTool(toolName, toolArgs);
        return { jsonrpc: '2.0', id, result: { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] } };
      } catch (err) {
        TOOLS = null;
        return { jsonrpc: '2.0', id, error: { code: -1, message: err.message || 'Tool call failed' } };
      }
    }

    default:
      return { jsonrpc: '2.0', id, error: { code: -32601, message: `Method not found: ${method}` } };
  }
}

// Main stdio loop
async function main() {
  try {
    await ensureTools();
  } catch (e) {
    process.stderr.write(`[burp-mcp-bridge] WARNING: Cannot connect to Burp at ${BURP_HOST}:${BURP_PORT}. Start Burp first.\n`);
  }

  const rl = readline.createInterface({ input: process.stdin, terminal: false });
  let pending = 0;
  let stdinClosed = false;

  rl.on('line', (line) => {
    if (!line.trim()) return;
    let msg;
    try {
      msg = JSON.parse(line);
    } catch (e) {
      process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: null, error: { code: -32700, message: 'Parse error' } }) + '\n');
      return;
    }

    pending++;
    handleRequest(msg)
      .then(response => {
        if (response) process.stdout.write(JSON.stringify(response) + '\n');
      })
      .catch(err => {
        process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: msg.id ?? null, error: { code: -1, message: err.message || 'Handler error' } }) + '\n');
      })
      .finally(() => {
        pending--;
        if (stdinClosed && pending === 0) process.exit(0);
      });
  });

  rl.on('close', () => {
    stdinClosed = true;
    if (pending === 0) process.exit(0);
  });
}

main();
