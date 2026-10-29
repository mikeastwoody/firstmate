# Local stand-in for api.typesafe.ai / openrouter.ai: records the Authorization
# header and whether the body carries any key, scans the resolver's temp files
# for any key while the request is in flight, and answers a canned Choice.
import http.server, json, pathlib, sys, time
LAB = pathlib.Path(sys.argv[1]); DTMP = pathlib.Path(sys.argv[2])
LOG = LAB / "logs" / "requests.jsonl"
NAMES = ("ts-canary", "or-canary", "env-canary", "dotenv-canary")
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n).decode()
        canaries = {p: (LAB / p).read_text() for p in NAMES if (LAB / p).exists()}
        recent = [f for g in ("tmp.*", "fm-*") for f in DTMP.glob(g) if f.is_file() and time.time() - f.stat().st_mtime < 120]
        files = [f for f in (LAB / "rtmp").rglob("*") if f.is_file()] + recent
        hits = []
        for f in files:
            try: data = f.read_text(errors="ignore")
            except Exception: continue
            hits += [f"{f.name}:{k}" for k, v in canaries.items() if v and v in data]
        auth = self.headers.get("Authorization") or ""
        named = [k for k, v in canaries.items() if v and auth == f"Bearer {v}"]
        rec = {"path": self.path, "authorization": auth, "authorization_is": named[0] if named else None,
               "body_has_any_key": any(v and v in body for v in canaries.values()),
               "key_in_resolver_files_in_flight": hits, "files_scanned_in_flight": len(files),
               "body_model": (json.loads(body).get("model") if body else None)}
        with LOG.open("a") as fh: fh.write(json.dumps(rec) + "\n")
        resp = (LAB / "fixtures" / "response.json").read_bytes()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(resp))); self.end_headers(); self.wfile.write(resp)
srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H)
(LAB / "port").write_text(str(srv.server_address[1]))
srv.serve_forever()
