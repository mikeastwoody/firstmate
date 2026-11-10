# mkcache.py <out> <spec-json>: write a quota-axi cache-format (schema 3) file.
# spec: list of {accountKey|null, keys|null, used, label?}
import json, sys, datetime as dt
out, spec = sys.argv[1], json.loads(sys.argv[2])
now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
iso = lambda t: t.strftime("%Y-%m-%dT%H:%M:%SZ")
H = "a" * 64
rows = []
for i, s in enumerate(spec):
    used = s["used"]
    w = [
      {"id": "five_hour", "label": "session", "kind": "session", "percentUsed": used, "percentRemaining": 100 - used,
       "windowSeconds": 18000, "startsAt": iso(now - dt.timedelta(hours=1)), "resetsAt": iso(now + dt.timedelta(hours=4))},
      {"id": "weekly", "label": "week", "kind": "weekly", "percentUsed": used, "percentRemaining": 100 - used,
       "windowSeconds": 604800, "startsAt": iso(now - dt.timedelta(days=1)), "resetsAt": iso(now + dt.timedelta(days=6))},
    ]
    r = {"provider": s.get("provider", "codex"), "label": "Codex", "source": "oauth", "windows": w,
         "state": {"status": "fresh", "stale": False, "refreshedAt": iso(now), "sourcesTried": ["oauth"]}}
    if s.get("accountKey"): r["accountKey"] = s["accountKey"]
    reuse = {"context": H, "inputs": [], "inputsDigest": H, "readingAt": iso(now), "lanes": len(spec), "lane": i}
    if s.get("keys"): reuse["accountKeys"] = s["keys"]
    r["reuse"] = reuse
    rows.append(r)
json.dump({"schemaVersion": 3, "providers": rows}, open(out, "w"), indent=1)
