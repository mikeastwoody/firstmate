# Local System One endpoint: answers every POST /v1/systemone with rule_1 at 0.95 and logs the request body.
import http.server, json, sys
log = sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        open(log, "ab").write(self.path.encode() + b" " + body + b"\n")
        req = json.loads(body)
        opts = list(req["questions"]["rule"]["criteria"].keys())
        probs = {k: (0.95 if k == "rule_1" else round(0.05 / (len(opts) - 1), 6)) for k in opts}
        out = json.dumps({"model": req["model"], "answers": {"rule": {"type": "choice", "choice": "rule_1", "confidence": 0.95, "probabilities": probs}},
                          "usage": {"input_tokens": 100, "output_tokens": 10}}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(out))); self.end_headers(); self.wfile.write(out)
    def log_message(self, *a): pass
http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
