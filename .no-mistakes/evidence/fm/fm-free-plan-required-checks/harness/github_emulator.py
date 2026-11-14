#!/usr/bin/env python3
"""Minimal local GitHub API emulator for driving the real `gh` CLI.

gh addresses GH_HOST=github.localhost over plain http://api.github.localhost/,
and Go proxies that host through HTTP_PROXY, so this server receives
absolute-URI proxy requests. It answers from a scenario JSON file that is
re-read on every request, and logs every request to a JSONL file.
Usage: github_emulator.py <port> <scenario.json> <requests.jsonl>
"""
import json, sys, urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT, SCENARIO, LOG = int(sys.argv[1]), sys.argv[2], sys.argv[3]
STATE = {"merged": False}

def scenario():
    with open(SCENARIO) as f:
        s = json.load(f)
    if s.get("case") != STATE.get("case"):
        STATE["case"] = s.get("case")
        STATE["merged"] = False
    return s

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def send(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def record(self, entry):
        with open(LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")

    def route(self, method):
        url = urllib.parse.urlsplit(self.path)
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n).decode() if n else ""
        s = scenario()
        path, qs = url.path, urllib.parse.parse_qs(url.query)
        entry = {"method": method, "host": url.netloc, "path": path, "query": url.query}
        if path in ("/graphql", "/api/graphql"):
            q = json.loads(raw) if raw else {}
            query = q.get("query", "")
            entry["graphql"] = " ".join(query.split())[:300]
            entry["variables"] = q.get("variables")
            if "__type(" in query:
                import re
                FIELDS = {
                    "PullRequest": ["isInMergeQueue", "isMergeQueueEnabled", "mergeQueueEntry", "autoMergeRequest",
                                    "reviewDecision", "closingIssuesReferences", "headRefOid", "baseRefName"],
                    "StatusCheckRollupContextConnection": ["checkRunCount", "checkRunCountsByState",
                                    "statusContextCount", "statusContextCountsByState"],
                    "WorkflowRun": ["event", "workflow", "runNumber"],
                    "Repository": ["viewerDefaultMergeMethod", "squashMergeAllowed", "mergeCommitAllowed",
                                    "rebaseMergeAllowed", "autoMergeAllowed", "deleteBranchOnMerge"],
                }
                data = {}
                for alias, tname in re.findall(r'(\w+)\s*:\s*__type\(name:\s*"(\w+)"\)', query):
                    data[alias] = {"fields": [{"name": n} for n in FIELDS.get(tname, [])]}
                self.record(entry)
                return self.send(200, {"data": data})
            if "mergePullRequest" in query:
                inp = (q.get("variables") or {}).get("input", {})
                entry["merge_input"] = inp
                if inp.get("expectedHeadOid") not in (None, s["head"]):
                    self.record(entry)
                    return self.send(200, {"errors": [{"message": "Head branch was modified"}]})
                STATE["merged"] = True
                self.record(entry)
                return self.send(200, {"data": {"mergePullRequest": {"clientMutationId": None}}})
            self.record(entry)
            return self.send(200, {"data": {"repository": repo_obj(s)}})
        self.record(entry)
        parts = path.strip("/").split("/")
        # repos/<o>/<r>/...
        if len(parts) >= 4 and parts[0] == "repos":
            rest = parts[3:]
            if rest[0] == "branches":
                return self.send(200, {"name": rest[1], "protected": False,
                    "protection": {"enabled": False, "required_status_checks":
                        {"enforcement_level": "off", "contexts": [], "checks": []}}})
            if rest[0] == "rules" and rest[1] == "branches":
                if s.get("rules_hidden", True):
                    return self.send(403, {"message": "Upgrade to GitHub Pro or make this repository public to enable this feature.",
                        "documentation_url": "https://docs.github.com/rest/repos/rules#get-rules-for-a-branch", "status": "403"})
                return self.send(200, s.get("rules", []))
            if rest[0] == "commits" and len(rest) >= 3 and rest[2] == "check-runs":
                if rest[1] != s["head"]:
                    return self.send(404, {"message": "No commit found for SHA"})
                runs = [dict(r, head_sha=s["head"]) for r in s.get("check_runs", [])]
                return self.send(200, {"total_count": len(runs), "check_runs": runs})
            if rest[0] == "actions" and rest[1] == "runs":
                sha = (qs.get("head_sha") or [None])[0]
                wr = [dict(r, head_sha=s["head"]) for r in s.get("workflow_runs", [])] if sha == s["head"] else []
                return self.send(200, {"total_count": len(wr), "workflow_runs": wr})
        return self.send(404, {"message": "Not Found (emulator)"})

    def do_GET(self):
        self.route("GET")

    def do_POST(self):
        self.route("POST")

    def do_PUT(self):
        self.route("PUT")

def repo_obj(s):
    head = s["head"]
    merged = STATE["merged"]
    contexts = s.get("rollup", [])
    pr = {
        "id": "PR_1", "number": s.get("number", 7), "title": "Emulated pull request",
        "url": s["url"], "body": "", "state": "MERGED" if merged else "OPEN",
        "merged": merged, "isDraft": False, "mergeable": "MERGEABLE",
        "mergeStateStatus": "CLEAN", "headRefOid": head, "headRefName": "feature",
        "baseRefName": "main", "isCrossRepository": False,
        "isInMergeQueue": False, "isMergeQueueEnabled": False,
        "headRepositoryOwner": {"id": "U_1", "login": s["owner"], "name": s["owner"]},
        "headRepository": {"id": "R_1", "name": s["repo"]},
        "commits": {"totalCount": 1, "nodes": [{"commit": {"oid": head,
            "committedDate": s.get("committed_at", "2026-11-13T09:58:00Z"),
            "checkSuites": {"nodes": [{"createdAt": s.get("suite_created_at", "2026-11-13T09:59:00Z")}] if contexts else []},
            "statusCheckRollup": ({"state": s.get("rollup_state", "SUCCESS"), "contexts": {"nodes": contexts}}
                                  if contexts else None)}}]},
        "reviewDecision": None,
        "reviewThreads": {"totalCount": 0, "nodes": []},
        "reviews": {"totalCount": 0, "nodes": []},
        "comments": {"totalCount": 0, "nodes": [], "pageInfo": {"hasNextPage": False, "endCursor": None}},
        "statusCheckRollup": {"nodes": [{"commit": {"oid": head, "statusCheckRollup": {
            "state": "SUCCESS",
            "contexts": {"nodes": contexts, "pageInfo": {"hasNextPage": False, "endCursor": None}}}}}]},
        "autoMergeRequest": None,
    }
    return {"id": "R_1", "name": s["repo"], "owner": {"login": s["owner"]},
            "nameWithOwner": f'{s["owner"]}/{s["repo"]}', "isPrivate": True,
            "squashMergeAllowed": True, "mergeCommitAllowed": True, "rebaseMergeAllowed": True,
            "viewerDefaultMergeMethod": "SQUASH", "defaultBranchRef": {"name": "main"},
            "pullRequest": pr}

ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
