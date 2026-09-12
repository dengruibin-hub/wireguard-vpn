#!/usr/bin/env python3
"""Minimal local WireGuard web console.

The MVP deliberately has no database and delegates operations to the existing
shell scripts. Bind to 127.0.0.1 and expose it through an SSH tunnel or a
proper authenticated reverse proxy.
"""

from flask import Flask, jsonify, request
import subprocess
from pathlib import Path

app = Flask(__name__)
ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"


def run_script(name, *args):
    result = subprocess.run(
        ["sudo", "bash", str(SCRIPTS / name), *args],
        text=True,
        capture_output=True,
        timeout=30,
    )
    return {
        "ok": result.returncode == 0,
        "code": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
    }


@app.get("/")
def index():
    return """<!doctype html>
<html><head><meta charset='utf-8'><title>WireGuard Console</title>
<style>body{font-family:system-ui;max-width:900px;margin:40px auto;padding:0 20px}pre{background:#f4f4f4;padding:16px;overflow:auto}button{margin:4px;padding:8px 12px}</style>
</head><body><h1>WireGuard Console</h1>
<p>MVP: service status, client list and health check.</p>
<button onclick="load('/api/status','status')">Status</button>
<button onclick="load('/api/clients','clients')">Clients</button>
<button onclick="load('/api/doctor','doctor')">Doctor</button>
<pre id='status'>Choose an action.</pre>
<script>async function load(url,id){const r=await fetch(url);document.getElementById('status').textContent=JSON.stringify(await r.json(),null,2)}</script>
</body></html>"""


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
    if not name or not all(c.isalnum() or c in "_-" for c in name):
        return jsonify({"ok": False, "error": "invalid client name"}), 400
    return jsonify(run_script("add-client.sh", name))


@app.delete("/api/clients/<name>")
def remove_client(name):
    if not name or not all(c.isalnum() or c in "_-" for c in name):
        return jsonify({"ok": False, "error": "invalid client name"}), 400
    return jsonify(run_script("remove-client.sh", name))


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080)
