"""A disposable local GitHub API emulator for the real gh CLI (host github.localhost).

gh sends REST to http://api.github.localhost/<path> and GraphQL to
http://api.github.localhost/graphql; HTTP_PROXY routes them here. Each request
reads the scenario from SCEN/scenario.json, so scenarios switch without restart.
Every request is appended to SCEN/requests.log; a merge mutation also writes
SCEN/merged with the expectedHeadOid it carried.
"""
import http.server, json, os, sys, urllib.parse

SCEN_PTR = sys.argv[2]  # file holding the active scenario dir path

def scen_dir():
    with open(SCEN_PTR) as f:
        return f.read().strip()

def load():
    d = scen_dir()
    with open(os.path.join(d, "scenario.json")) as f:
        return d, json.load(f)

def log(d, line):
    with open(os.path.join(d, "requests.log"), "a") as f:
        f.write(line + "\n")

def pr_object(d, s):
    merged = os.path.exists(os.path.join(d, "merged"))
    head = s["head"]
    return {
        "id": "PR_lab120", "number": 120, "title": "Lab change", "body": "## What Changed\nlab\n",
        "url": "https://github.localhost/example/repo/pull/120",
        "state": "MERGED" if merged else "OPEN", "merged": merged, "closed": merged,
        "isDraft": False, "mergeable": "MERGEABLE", "mergeStateStatus": "CLEAN",
        "headRefOid": head, "headRefName": "feature", "baseRefName": "main",
        "isInMergeQueue": False, "isMergeQueueEnabled": False, "isCrossRepository": False,
        "headRepositoryOwner": {"id": "U_1", "login": "example"},
        "headRepository": {"id": "R_1", "name": "repo"},
        "autoMergeRequest": None, "reviewDecision": "REVIEW_REQUIRED",
        "author": {"login": "lab"},
        "commits": {"totalCount": 1, "nodes": [{"commit": {
            "oid": head, "committedDate": "2026-11-13T09:00:00Z",
            "checkSuites": {"nodes": [{"createdAt": "2026-11-13T09:00:00Z"}]},
            # GitHub reports no rollup at all for a head that has no checks.
            "statusCheckRollup": None if not s.get("rollup") else {"state": s.get("rollup_state", "SUCCESS"), "contexts": {
                "nodes": s.get("rollup", []),
                "pageInfo": {"hasNextPage": False, "endCursor": None}}}}}]},
        # gh pr view --json statusCheckRollup aliases commits(last:1) as statusCheckRollup.
        "statusCheckRollup": {"nodes": [{"commit": {"oid": head, "statusCheckRollup": {"contexts": {
            "nodes": s.get("rollup", []),
            "pageInfo": {"hasNextPage": False, "endCursor": None}}}}}]},
        "reviewThreads": {"totalCount": 0, "nodes": []},
        "reviews": {"totalCount": 0, "nodes": []},
        "comments": {"totalCount": 0, "nodes": [], "pageInfo": {"hasNextPage": False, "endCursor": None}},
    }

class H(http.server.BaseHTTPRequestHandler):
    def reply(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def handle_any(self):
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n) if n else b""
        d, s = load()
        u = urllib.parse.urlsplit(self.path)
        path, qs = u.path, urllib.parse.parse_qs(u.query)
        if path == "/graphql":
            req = json.loads(raw or b"{}")
            q, v = req.get("query", ""), req.get("variables", {})
            if "__type(" in q:
                # gh's feature detection: answer each aliased __type with a field list.
                import re
                fields = {
                    "PullRequest": ["id", "number", "state", "isDraft", "mergeable", "mergeStateStatus",
                                    "headRefOid", "baseRefName", "isInMergeQueue", "isMergeQueueEnabled",
                                    "mergeQueueEntry", "autoMergeRequest", "reviewDecision", "closingIssuesReferences"],
                    "StatusCheckRollupContextConnection": ["checkRunCount", "checkRunCountsByState",
                                                           "statusContextCount", "statusContextCountsByState"],
                    "WorkflowRun": ["event", "workflow", "runNumber"],
                }
                data = {}
                for alias, tname in re.findall(r'(\w+)\s*:\s*__type\(name:\s*"(\w+)"\)', q):
                    data[alias] = {"fields": [{"name": n} for n in fields.get(tname, [])]}
                log(d, "GRAPHQL feature-detection " + ",".join(sorted(data)))
                return self.reply(200, {"data": data})
            if "mergePullRequest" in q:
                inp = v.get("input", {})
                log(d, "GRAPHQL mergePullRequest " + json.dumps(inp, sort_keys=True))
                with open(os.path.join(d, "merged"), "w") as f:
                    f.write(inp.get("expectedHeadOid", "") + "\n")
                return self.reply(200, {"data": {"mergePullRequest": {"clientMutationId": None}}})
            if "pullRequest" in q:
                kind = "park-gate" if "reviewThreads" in q else "pullRequest"
                log(d, f"GRAPHQL {kind} query")
                return self.reply(200, {"data": {"repository": {"pullRequest": pr_object(d, s)}}})
            if "repository" in q:
                log(d, "GRAPHQL repository query")
                return self.reply(200, {"data": {"repository": {
                    "id": "R_1", "name": "repo", "owner": {"login": "example"}, "isPrivate": True,
                    "mergeCommitAllowed": True, "rebaseMergeAllowed": True, "squashMergeAllowed": True,
                    "viewerDefaultMergeMethod": "SQUASH", "defaultBranchRef": {"name": "main"}}}})
            log(d, "GRAPHQL unhandled " + q[:200].replace("\n", " "))
            return self.reply(200, {"data": {"viewer": {"login": "lab"}}})
        log(d, f"REST {self.command} {u.path}{'?' + u.query if u.query else ''}")
        parts = path.strip("/").split("/")
        if parts[:3] == ["repos", "example", "repo"]:
            rest = parts[3:]
            if rest[:2] == ["rules", "branches"]:
                if s.get("rules_hidden", True):
                    return self.reply(403, {"message": "Upgrade to GitHub Pro or make this repository public to enable this feature.",
                                            "documentation_url": "https://docs.github.com/rest/repos/rules#get-rules-for-a-branch", "status": "403"})
                return self.reply(200, [])
            if rest[:1] == ["branches"]:
                return self.reply(200, {"name": "main", "protected": False,
                                        "protection": {"enabled": False, "required_status_checks": {"enforcement_level": "off", "contexts": [], "checks": []}}})
            if rest[:1] == ["commits"] and rest[2:] == ["check-runs"]:
                if rest[1] != s["head"]:
                    return self.reply(422, {"message": "No commit found for SHA"})
                runs = [dict(r, head_sha=s["head"]) for r in s.get("check_runs", [])]
                return self.reply(200, {"total_count": len(runs), "check_runs": runs})
            if rest == ["actions", "runs"]:
                if qs.get("head_sha", [""])[0] != s["head"]:
                    return self.reply(200, {"total_count": 0, "workflow_runs": []})
                wr = [dict(r, head_sha=s["head"]) for r in s.get("workflow_runs", [])]
                return self.reply(200, {"total_count": len(wr), "workflow_runs": wr})
        return self.reply(404, {"message": "Not Found"})

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = handle_any
    def log_message(self, *a):
        pass

http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
