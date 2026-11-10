# Live validation for #7463 (schema-6 quota rows bound by covered accountKeys)

Setup:
- **Product:** the real `bin/fm-dispatch-resolve.sh` and `bin/fm-quota-choose.sh`. Each was run twice, from base 913bb7a7 and from head c7e127ad, using `git archive` copies of `bin/`.
- **Quota evidence:** the real `quota-axi` 0.1.62 binary. It read disposable `QUOTA_AXI_SNAPSHOT` cache-format fixtures (`fixtures/*.cache.json`, made by `mkcache.py`) under an isolated temp HOME. The installed binary itself emits schema 6 with `accountKeys`.
  - Malformed shapes and edge cases are jq edits of captured real output, served by a PATH shim.
- **Dispatch model:** `FM_DISPATCH_PROVIDER=systemone`, pointed at a local 127.0.0.1 endpoint (`systemone.py`) that always picks rule_1. No external network was used.
- **FM_HOME:** a lab home minted with `bin/fm-lab-home.sh create`. The task record `data/fm-lab-7463/dispatch-resolution.json` is shown after every run.

Files:
- D1-dispatch-covered-key-base-vs-head.txt: base escalates (no rankable candidate). Head ranks the Pi `openai-codex` lane from the row whose `accountKeys` covers it and resolves `clear`.
- D2-dispatch-conflicting-rows.txt: when two rows cover `openai-codex`, the lane stays unmeasured with the new reason and does not fall back to the default row. Native Codex keeps its own row, and the uncovered key falls back to default.
- D3-dispatch-malformed-accountKeys.txt: a malformed `accountKeys` value makes the result `status: error` ("invalid snapshot") at head. Base silently accepted it. `[]` is accepted.
- D4-dispatch-schema5-and-default-row-unchanged.txt: for schema 5, schema 5 with stray keys, schema 6 without coverage, and a provider missing from the snapshot, base and head output is byte-identical once latency is normalized.
- D5-dispatch-alias-conflict-and-cross-provider.txt: when two rows alias a key only through `accountKeys`, the key stays unmeasured (base wrongly used the default row). A key listed by another provider's row never binds.
- Q1-Q2-quota-choose-covered-and-conflict.txt: covered key: base prints `none` and head prints `codex default`, regardless of row order. Conflict: head skips Codex and picks `opencode default`.
- Q3-Q4-quota-choose-malformed-and-unchanged.txt: malformed keys exit 2 with "invalid quota-axi provider data". Across 20 schema-5 and no-coverage selections, base and head are identical.
