import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const html = readFileSync(resolve('admin.html'), 'utf8');
const css = readFileSync(resolve('css/admin.css'), 'utf8');
const js = readFileSync(resolve('js/admin.js'), 'utf8');

assert.match(html, /<section class="login-panel" id="login-panel">/);
assert.match(html, /<input id="admin-token"[^>]*type="password"/);
assert.match(html, /<section class="dashboard" id="dashboard" hidden>/);
assert.match(html, /\/js\/admin\.js\?v=20260516-admin-monitor/);
assert.match(html, /\/css\/admin\.css\?v=20260516-admin-monitor/);

assert.match(css, /--bg:\s*#ffffff/);
assert.match(css, /--fg:\s*#0a0a0a/);
assert.match(css, /\.metric-grid\s*\{/);
assert.match(css, /\.panel\s*\{/);

assert.match(js, /'X-Admin-Token':\s*adminToken/);
assert.match(js, /fetchJson\('\/api\/v1\/admin\/monitor\/summary'\)/);
assert.match(js, /fetchJson\('\/api\/v1\/admin\/monitor\/users'\)/);
assert.match(js, /fetchJson\('\/api\/v1\/admin\/monitor\/schedule-logs\?limit=100'\)/);
assert.match(js, /loginPanel\.hidden\s*=\s*true/);
assert.match(js, /dashboard\.hidden\s*=\s*false/);
assert.doesNotMatch(js, /localStorage|sessionStorage/);
