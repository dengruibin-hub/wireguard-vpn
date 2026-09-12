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
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>WireGuard Console</title>
<style>
body{font-family:system-ui,-apple-system,sans-serif;max-width:1100px;margin:0 auto;padding:24px;background:#f6f7f9;color:#17202a}
.card{background:#fff;border:1px solid #ddd;border-radius:12px;padding:18px;margin:14px 0}h1{margin-bottom:4px}.muted{color:#667085}
button{border:0;border-radius:8px;padding:9px 13px;cursor:pointer;background:#17202a;color:#fff}button.danger{background:#b42318}
input{padding:9px;border:1px solid #bbb;border-radius:8px}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:9px;border-bottom:1px solid #eee;font-size:14px}
pre{white-space:pre-wrap;background:#f4f5f7;padding:12px;border-radius:8px;overflow:auto;max-height:300px}.row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
</style></head><body>
<h1>WireGuard Console</h1><p class="muted">Local administration MVP. Keep this service on 127.0.0.1 and access it through an SSH tunnel.</p>
<div class="card"><div class="row"><button onclick="status()">Refresh status</button><button onclick="doctor()">Run doctor</button></div><pre id="output">Ready.</pre></div>
<div class="card"><h2>Clients</h2><form class="row" onsubmit="addClient(event)"><input id="name" maxlength="64" pattern="[A-Za-z0-9_-]+" placeholder="client name" required><button>Add client</button></form><div id="clients" style="margin-top:14px"></div></div>
<script>
async function api(url,options){const r=await fetch(url,options);const d=await r.json();if(!r.ok)throw new Error(d.error||'request failed');return d}
function show(d){document.getElementById('output').textContent=(d.stdout||'')+(d.stderr?'\n'+d.stderr:'')||JSON.stringify(d,null,2)}
async function status(){try{show(await api('/api/status'))}catch(e){document.getElementById('output').textContent=e}}
async function doctor(){try{show(await api('/api/doctor'))}catch(e){document.getElementById('output').textContent=e}}
async function refreshClients(){try{const d=await api('/api/clients');const lines=(d.stdout||'').trim().split('\n').filter(Boolean);if(lines.length<3){document.getElementById('clients').textContent=d.stdout||'No clients.';return}const rows=lines.slice(2).map(x=>{const p=x.trim().split(/\s+/);if(p.length<4||p[0]==='No')return '';const n=esc(p[0]);return `<tr><td>${n}</td><td>${esc(p[1])}</td><td>${esc(p[3])}</td><td><button class="danger" onclick="removeClient('${n}')">Remove</button></td></tr>`}).join('');document.getElementById('clients').innerHTML='<table><thead><tr><th>Client</th><th>VPN IP</th><th>Status</th><th></th></tr></thead><tbody>'+rows+'</tbody></table>'}catch(e){document.getElementById('clients').textContent=e}}
async function addClient(e){e.preventDefault();const name=document.getElementById('name').value;try{show(await api('/api/clients',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name})}));document.getElementById('name').value='';await refreshClients()}catch(e){document.getElementById('output').textContent=e}}
async function removeClient(name){if(!confirm('Remove client '+name+'?'))return;try{show(await api('/api/clients/'+encodeURIComponent(name),{method:'DELETE'}));await refreshClients()}catch(e){document.getElementById('output').textContent=e}}
function esc(s){return s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
status();refreshClients();
</script></body></html>"""


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
