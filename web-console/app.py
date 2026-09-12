#!/usr/bin/env python3
"""Local WireGuard web console.

The MVP has no database or login system. It binds to 127.0.0.1 and is intended
to be reached through an SSH tunnel. All WireGuard changes are delegated to
the existing shell scripts.
"""

from flask import Flask, jsonify, request
import os
import re
import subprocess
from pathlib import Path

app = Flask(__name__)
ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
NAME_RE = re.compile(r"^[A-Za-z0-9_-]+$")


def run_script(name, *args):
    command = ["bash", str(SCRIPTS / name), *args]
    if os.geteuid() != 0:
        command.insert(0, "sudo")
    try:
        result = subprocess.run(command, text=True, capture_output=True, timeout=30)
    except subprocess.TimeoutExpired:
        return {"ok": False, "code": 124, "stdout": "", "stderr": "command timed out"}
    return {
        "ok": result.returncode == 0,
        "code": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
    }


def valid_name(name):
    return bool(name and len(name) <= 64 and NAME_RE.fullmatch(name))


@app.get("/")
def index():
    return """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>WireGuard Console</title>
<style>
body{font-family:system-ui,-apple-system,sans-serif;max-width:1100px;margin:0 auto;padding:24px;background:#f6f7f9;color:#17202a}
.card{background:#fff;border:1px solid #ddd;border-radius:12px;padding:18px;margin:14px 0}
h1{margin-bottom:4px}.muted{color:#667085}
button{border:0;border-radius:8px;padding:9px 13px;cursor:pointer;background:#17202a;color:#fff}
button.danger{background:#b42318}button:disabled{opacity:.6;cursor:wait}
input{padding:9px;border:1px solid #bbb;border-radius:8px}
table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:9px;border-bottom:1px solid #eee;font-size:14px}
pre{white-space:pre-wrap;background:#f4f5f7;padding:12px;border-radius:8px;overflow:auto;max-height:300px}
.row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.error{color:#b42318}
</style>
</head>
<body>
<h1>WireGuard Console</h1>
<p class="muted">Local administration MVP. Keep this service on 127.0.0.1 and access it through an SSH tunnel.</p>
<div class="card">
  <div class="row">
    <button id="statusButton" type="button">Refresh status</button>
    <button id="doctorButton" type="button">Run doctor</button>
  </div>
  <pre id="output">Loading...</pre>
</div>
<div class="card">
  <h2>Clients</h2>
  <form id="addForm" class="row">
    <input id="name" maxlength="64" pattern="[A-Za-z0-9_-]+" placeholder="client name" required>
    <button id="addButton" type="submit">Add client</button>
  </form>
  <div id="clients" style="margin-top:14px">Loading clients...</div>
</div>
<script>
'use strict';

async function api(url, options) {
  const response = await fetch(url, options || {});
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || 'request failed');
  return data;
}

function show(data) {
  const output = document.getElementById('output');
  const text = (data.stdout || '') + (data.stderr ? '\n' + data.stderr : '');
  output.textContent = text || JSON.stringify(data, null, 2);
}

function setBusy(button, busy) {
  if (button) button.disabled = busy;
}

async function loadStatus() {
  const button = document.getElementById('statusButton');
  setBusy(button, true);
  try {
    show(await api('/api/status'));
  } catch (error) {
    document.getElementById('output').textContent = 'Error: ' + error.message;
  } finally {
    setBusy(button, false);
  }
}

async function loadDoctor() {
  const button = document.getElementById('doctorButton');
  setBusy(button, true);
  try {
    show(await api('/api/doctor'));
  } catch (error) {
    document.getElementById('output').textContent = 'Error: ' + error.message;
  } finally {
    setBusy(button, false);
  }
}

function escapeHtml(value) {
  return String(value).replace(/[&<>\"']/g, function (char) {
    const entities = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '\"': '&quot;',
      "'": '&#39;'
    };
    return entities[char];
  });
}

async function loadClients() {
  const container = document.getElementById('clients');
  try {
    const data = await api('/api/clients');
    const lines = (data.stdout || '').trim().split('\n').filter(Boolean);
    if (lines.length < 3) {
      container.textContent = data.stdout || 'No clients.';
      return;
    }

    const rows = lines.slice(2).map(function (line) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 4 || parts[0] === 'No') return '';
      const name = parts[0];
      return '<tr>' +
        '<td>' + escapeHtml(name) + '</td>' +
        '<td>' + escapeHtml(parts[1]) + '</td>' +
        '<td>' + escapeHtml(parts[3]) + '</td>' +
        '<td><button type="button" class="danger remove-button" data-name="' + escapeHtml(name) + '">Remove</button></td>' +
        '</tr>';
    }).join('');

    container.innerHTML = '<table><thead><tr><th>Client</th><th>VPN IP</th><th>Status</th><th></th></tr></thead><tbody>' + rows + '</tbody></table>';
    container.querySelectorAll('.remove-button').forEach(function (button) {
      button.addEventListener('click', function () { removeClient(button.dataset.name); });
    });
  } catch (error) {
    container.innerHTML = '<span class="error">Error: ' + escapeHtml(error.message) + '</span>';
  }
}

async function addClient(event) {
  event.preventDefault();
  const input = document.getElementById('name');
  const button = document.getElementById('addButton');
  setBusy(button, true);
  try {
    show(await api('/api/clients', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({name: input.value})
    }));
    input.value = '';
    await loadClients();
  } catch (error) {
    document.getElementById('output').textContent = 'Error: ' + error.message;
  } finally {
    setBusy(button, false);
  }
}

async function removeClient(name) {
  if (!window.confirm('Remove client ' + name + '?')) return;
  try {
    show(await api('/api/clients/' + encodeURIComponent(name), {method: 'DELETE'}));
    await loadClients();
  } catch (error) {
    document.getElementById('output').textContent = 'Error: ' + error.message;
  }
}

document.getElementById('statusButton').addEventListener('click', loadStatus);
document.getElementById('doctorButton').addEventListener('click', loadDoctor);
document.getElementById('addForm').addEventListener('submit', addClient);
loadStatus();
loadClients();
</script>
</body>
</html>"""


@app.get("/api/status")
def status():
    return jsonify(run_script("status.sh"))


@app.get("/api/clients")
def clients():
    return jsonify(run_script("list-clients.sh"))


@app.get("/api/doctor")
def doctor():
    return jsonify(run_script("doctor.sh"))


@app.post("/api/clients")
def add_client():
    name = request.json.get("name", "") if request.is_json else ""
    if not valid_name(name):
        return jsonify({"ok": False, "error": "invalid client name"}), 400
    return jsonify(run_script("add-client.sh", name))


@app.delete("/api/clients/<name>")
def remove_client(name):
    if not valid_name(name):
        return jsonify({"ok": False, "error": "invalid client name"}), 400
    return jsonify(run_script("remove-client.sh", name))


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080)
