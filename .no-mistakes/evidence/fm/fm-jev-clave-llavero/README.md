# Live validation: declared credential source for bin/fm-dispatch-resolve.sh (PR 5409 / issue 7879)

Head under test: bcdebef5 (base b936f040). Run on macOS 27.0 with the real `/usr/bin/security`, `/usr/bin/curl`, `jq` and bash.

## Disposable setup (torn down after the run)
- **Throwaway keychain.** `security create-keychain` made `$LAB/fm-lab.keychain-db` (never added to the user's search list). It held three generic-password items with random canaries, not real keys: `fm-lab-typesafe`/`fm-lab`, `fm-lab-openrouter`/`fm-lab`, and `fm-lab-empty`/`fm-lab` (empty password). The user's keychain search list and default keychain were diffed before and after the run and were unchanged. A default lookup of `fm-lab-typesafe` exits 44 both during the run and after teardown.
- **`security` shim** (`lab-harness/security-shim.sh`) logs argv, appends the throwaway keychain path, and `exec`s the real `/usr/bin/security`. The real Keychain services do the read.
- **Stubbed endpoint** (`lab-harness/stub_server.py`) is a local Python HTTP server. It records which canary the `Authorization: Bearer` header carried (transcripts show only the canary name), whether the body carries any key, and whether any key sits in the resolver's temp files while the request is in flight. The curl shim (`lab-harness/curl-shim.sh`) only rewrites the fixed provider hosts to `127.0.0.1:<port>`, then `exec`s the real `/usr/bin/curl`, which still reads the header from fd 3. No real API was called.
- **`quota-axi`** is a fake that serves the resolver test suite's schema-5 snapshot.
- **Homes.** `bin/fm-lab-home.sh create` minted marked lab homes. The base resolver and bootstrap came from `git archive b936f040 bin`.
- **Driver** is `lab-harness/drive.sh`. It runs under bash and clears every inherited key and fleet override before it runs.

## Transcripts
| File | Scenarios |
|---|---|
| s1-real-keychain-end-to-end.txt | A real Keychain item read through the declaration (service+account, service only, explicit provider) gives a `clear` result; the key arrives only as the Bearer header |
| s2-precedence-and-off.txt | Precedence is environment, then .env, then the declared source, and the Keychain is not touched when a key exists; an invalid declaration is ignored when a key exists; an absent or empty declaration with no key is off |
| s3-unconfigured-home-matches-base.txt | Unconfigured homes give the same exit, stdout, stderr, stub request and calls as base b936f040 |
| s4-provider-isolation.txt | A declaration never crosses providers or selects a provider; openrouter reads only its own item; openai ignores declarations |
| s5-invalid-declarations.txt | 13 invalid or unreadable shapes exit 2 with one actionable line, print no declared value, and make no Keychain, network or quota call |
| s6-unavailable-source.txt | A missing item, the wrong account, an empty item, no `security` command, a non-macOS host, or a source that never answers ends in `error … nothing sent` with exit 0 and no network or quota call; the hung read is killed at about 5 s |
| s7-capability-probe.txt | `--supports-credential-source` answers supported (exit 0) or unsupported (exit 1) without reading the declaration or running `security`; the base resolver has no such flag |
| s8-effective-home-isolation.txt | Only the effective config directory's declaration is consulted (`FM_CONFIG_OVERRIDE` and other homes are kept apart) |
| s9-bootstrap-parity.txt, s9b-resolver-parity.txt | Bootstrap and the resolver agree when a declared typesafe source is the only key source; bootstrap never runs `security`; base bootstrap shows the old mismatch |
| tests-fm-dispatch-resolve.log, tests-fm-bootstrap.log | The targeted test files for the changed scripts (both exit 0) |
