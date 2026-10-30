# Live run: declared credential source for bin/fm-dispatch-resolve.sh
worktree head: 1fd70fa5   date: 2026-10-30T09:03:35Z   host: Darwin 27.0.0
Lab: HOME=<W> holds a throwaway keychain file as its only Keychain search-list entry (the operator's login keychain and search list are untouched)
and a .curlrc that routes api.typesafe.ai/openrouter.ai:443 to a local HTTPS stub (real curl, real TLS against a throwaway CA). No real API call.
Throwaway items: service fm-lab-typesafe-<run> (acct lab), fm-lab-multi-<run> (acct-a, acct-b), fm-lab-openrouter-<run>, fm-lab-empty-<run> (empty).
Secrets are never printed; the stub records sha256 prefixes and which throwaway secret the bearer token equals.
  sha256[:16] of throwaway secret 'ts': b542e5cc73e1cccd
  sha256[:16] of throwaway secret 'multi_a': fa1379469061a705
  sha256[:16] of throwaway secret 'multi_b': f19b961d7f348b29
  sha256[:16] of throwaway secret 'or': 41fe067e76d6dc2f
  sha256[:16] of throwaway secret 'env': e199b7a8e3953e7b
  sha256[:16] of throwaway secret 'dotenv': 192fff6882c6d461

## S1 Keychain item declared for typesafe is read and sent end to end

### S1 service-only declaration, no env/.env key
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=1  security_calls=1  elapsed_s=0
stdout:
  | dispatch-resolve:
  |   status: clear
  |   model: jev-1.13.0   latency_ms: 56   tokens: 400/30
  |   rule: rule_1 (A simple bug fix with a stated root cause.)   confidence: 0.93
  |   probabilities: rule_1=0.93 rule_2=0.03 default=0.04
  |   note: rule matched
  |   candidate: claude:sonnet  provider=claude  -> eligible (quota ranking off: home declares a single shared quota)
  |   profile: --harness 'claude' --model 'sonnet' --effort 'high'
  security argv: security find-generic-password -s fm-lab-typesafe-<run> -w
  PASS: exit 0
  PASS: status clear with rule_1 profile
  PASS: profile line carries the rule's harness
  PASS: exactly one stub request
  PASS: request went to api.typesafe.ai/v1/systemone
  PASS: bearer token equals the Keychain item (ts)
  PASS: security ran once with only -s <service> -w
  PASS: no process argv/env held the key while curl was in flight
  PASS: stub saw the in-flight curl process
  PASS: curl argv/env carry no key
  PASS: request body carries no key
  curl argv seen by stub: "curl -sS --max-time 5 -o /var/folders/t1/hn73dcyn0mg70rx5np1f41_80000gn/T/tmp.qiX3WxEE3u -w %{http_code} -X POST https://api.typesafe.ai/v1/systemone -H Content-Type: application/json -H @/dev/fd/3 --data-binary @-"

## S2 Declared account selects which item of a shared service is read

### S2a account acct-b
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=1  security_calls=1  elapsed_s=0
stdout:
  | dispatch-resolve:
  |   status: clear
  |   model: jev-1.13.0   latency_ms: 56   tokens: 400/30
  |   rule: rule_1 (A simple bug fix with a stated root cause.)   confidence: 0.93
  |   probabilities: rule_1=0.93 rule_2=0.03 default=0.04
  |   note: rule matched
  |   candidate: claude:sonnet  provider=claude  -> eligible (quota ranking off: home declares a single shared quota)
  |   profile: --harness 'claude' --model 'sonnet' --effort 'high'
  security argv: security find-generic-password -s fm-lab-multi-<run> -a acct-b -w
  PASS: clear
  PASS: bearer equals acct-b item
  PASS: security argv is -s <service> -a acct-b -w

### S2b account acct-a
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=1  security_calls=1  elapsed_s=0
stdout:
  | dispatch-resolve:
  |   status: clear
  |   model: jev-1.13.0   latency_ms: 57   tokens: 400/30
  |   rule: rule_1 (A simple bug fix with a stated root cause.)   confidence: 0.93
  |   probabilities: rule_1=0.93 rule_2=0.03 default=0.04
  |   note: rule matched
  |   candidate: claude:sonnet  provider=claude  -> eligible (quota ranking off: home declares a single shared quota)
  |   profile: --harness 'claude' --model 'sonnet' --effort 'high'
  security argv: security find-generic-password -s fm-lab-multi-<run> -a acct-a -w
  PASS: bearer equals acct-a item

## S3 Precedence: environment, then .env, then the declared source

### S3a env + .env + declaration
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: TYPESAFE_API_KEY=<secret> (values redacted)]
exit=0  stub_requests=1  security_calls=0  elapsed_s=0
stdout:
  | dispatch-resolve:
  |   status: clear
  |   model: jev-1.13.0   latency_ms: 55   tokens: 400/30
  |   rule: rule_1 (A simple bug fix with a stated root cause.)   confidence: 0.93
  |   probabilities: rule_1=0.93 rule_2=0.03 default=0.04
  |   note: rule matched
  |   candidate: claude:sonnet  provider=claude  -> eligible (quota ranking off: home declares a single shared quota)
  |   profile: --harness 'claude' --model 'sonnet' --effort 'high'
  PASS: bearer equals the environment key
  PASS: Keychain not consulted
  PASS: curl argv/env carry no env key

### S3b .env + declaration
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=1  security_calls=0  elapsed_s=1
stdout:
  | dispatch-resolve:
  |   status: clear
  |   model: jev-1.13.0   latency_ms: 56   tokens: 400/30
  |   rule: rule_1 (A simple bug fix with a stated root cause.)   confidence: 0.93
  |   probabilities: rule_1=0.93 rule_2=0.03 default=0.04
  |   note: rule matched
  |   candidate: claude:sonnet  provider=claude  -> eligible (quota ranking off: home declares a single shared quota)
  |   profile: --harness 'claude' --model 'sonnet' --effort 'high'
  PASS: bearer equals the .env key
  PASS: Keychain not consulted

### S3c .env key + INVALID declaration (declaration never read)
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=1  security_calls=0  elapsed_s=0
stdout:
  | dispatch-resolve:
  |   status: clear
  |   model: jev-1.13.0   latency_ms: 57   tokens: 400/30
  |   rule: rule_1 (A simple bug fix with a stated root cause.)   confidence: 0.93
  |   probabilities: rule_1=0.93 rule_2=0.03 default=0.04
  |   note: rule matched
  |   candidate: claude:sonnet  provider=claude  -> eligible (quota ranking off: home declares a single shared quota)
  |   profile: --harness 'claude' --model 'sonnet' --effort 'high'
  PASS: still clear on the .env key
  PASS: bearer equals .env key

## S4 No declaration and no key keeps today's off behavior

### S4 absent declaration, absent key
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=0  security_calls=0  elapsed_s=0
stderr:
  ! dispatch-resolve: off (TYPESAFE_API_KEY absent from the environment and <lab>/.env)
  PASS: exit 0
  PASS: stdout empty
  PASS: stderr is the original off line
  PASS: no network call
  PASS: no Keychain call

## S5 Invalid declaration is an actionable configuration error (exit 2), never echoing a value

### S5 credential value smuggled in
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=2  stub_requests=0  security_calls=0  elapsed_s=0
stderr:
  ! error: malformed credential source declaration: <lab>/config/dispatch-credential-sources.json - typesafe has unknown field key (allowed: source, service, account); credential values do not belong in this file
  PASS: exit 2
  PASS: stderr names: typesafe has unknown field key
  PASS: no network call
  PASS: no Keychain call
  PASS: declared value not echoed

### S5 unknown source
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=2  stub_requests=0  security_calls=0  elapsed_s=0
stderr:
  ! error: malformed credential source declaration: <lab>/config/dispatch-credential-sources.json - typesafe source must be one of macos-keychain
  PASS: exit 2
  PASS: stderr names: typesafe source must be one of macos-keychain
  PASS: no network call
  PASS: no Keychain call

### S5 unknown provider
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=2  stub_requests=0  security_calls=0  elapsed_s=0
stderr:
  ! error: malformed credential source declaration: <lab>/config/dispatch-credential-sources.json - unknown provider openai (expected typesafe or openrouter)
  PASS: exit 2
  PASS: stderr names: unknown provider openai
  PASS: no network call
  PASS: no Keychain call

### S5 missing service
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=2  stub_requests=0  security_calls=0  elapsed_s=0
stderr:
  ! error: malformed credential source declaration: <lab>/config/dispatch-credential-sources.json - typesafe service must be a non-empty string without control characters
  PASS: exit 2
  PASS: stderr names: typesafe service must be a non-empty string
  PASS: no network call
  PASS: no Keychain call

### S5 not JSON
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=2  stub_requests=0  security_calls=0  elapsed_s=0
stderr:
  ! error: malformed credential source declaration: <lab>/config/dispatch-credential-sources.json - not JSON
  PASS: exit 2
  PASS: stderr names: not JSON
  PASS: no network call
  PASS: no Keychain call

### S5 unreadable declaration
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=2  stub_requests=0  security_calls=0  elapsed_s=1
stderr:
  ! error: credential source declaration not readable: <lab>/config/dispatch-credential-sources.json
  PASS: exit 2
  PASS: stderr says not readable

## S6 Declared but unavailable source is a sanitized error outcome with no network call

### S6 item missing from Keychain
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=0  security_calls=1  elapsed_s=0
stdout:
  | dispatch-resolve:
  |   status: error
  |   reason: credential source macos-keychain declared for typesafe is unavailable; nothing sent
stderr:
  ! dispatch-resolve: error (credential source macos-keychain declared for typesafe is unavailable; nothing sent)
  security argv: security find-generic-password -s fm-lab-missing-<run> -w
  PASS: exit 0 (intake never blocked)
  PASS: stdout status: error
  PASS: reason: credential source macos-keychain declared for typesafe is unavailable; nothing sent
  PASS: no network call

### S6 item present but empty
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=0  security_calls=1  elapsed_s=0
stdout:
  | dispatch-resolve:
  |   status: error
  |   reason: credential source macos-keychain declared for typesafe is unavailable; nothing sent
stderr:
  ! dispatch-resolve: error (credential source macos-keychain declared for typesafe is unavailable; nothing sent)
  security argv: security find-generic-password -s fm-lab-empty-<run> -w
  PASS: exit 0 (intake never blocked)
  PASS: stdout status: error
  PASS: reason: credential source macos-keychain declared for typesafe is unavailable; nothing sent
  PASS: no network call

### S6 account that does not exist
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=0  security_calls=1  elapsed_s=0
stdout:
  | dispatch-resolve:
  |   status: error
  |   reason: credential source macos-keychain declared for typesafe is unavailable; nothing sent
stderr:
  ! dispatch-resolve: error (credential source macos-keychain declared for typesafe is unavailable; nothing sent)
  security argv: security find-generic-password -s fm-lab-typesafe-<run> -a nobody -w
  PASS: exit 0 (intake never blocked)
  PASS: stdout status: error
  PASS: reason: credential source macos-keychain declared for typesafe is unavailable; nothing sent
  PASS: no network call

### S6 Keychain read never answers (hanging security stand-in)
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=0  security_calls=1  elapsed_s=6
stdout:
  | dispatch-resolve:
  |   status: error
  |   reason: credential source macos-keychain declared for typesafe did not answer in time; nothing sent
stderr:
  ! dispatch-resolve: error (credential source macos-keychain declared for typesafe did not answer in time; nothing sent)
  security argv: security find-generic-password -s fm-lab-typesafe-<run> -w
  PASS: exit 0 (intake never blocked)
  PASS: stdout status: error
  PASS: reason: credential source macos-keychain declared for typesafe did not answer in time; nothing sent
  PASS: no network call
  PASS: bounded: returned in <= 8 s
  PASS: the unanswered read was stopped (no leftover process)

### S6 host cannot run the adapter (uname reports Linux)
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=0  security_calls=0  elapsed_s=0
stdout:
  | dispatch-resolve:
  |   status: error
  |   reason: credential source macos-keychain declared for typesafe is not supported on this host; nothing sent
stderr:
  ! dispatch-resolve: error (credential source macos-keychain declared for typesafe is not supported on this host; nothing sent)
  PASS: exit 0 (intake never blocked)
  PASS: stdout status: error
  PASS: reason: credential source macos-keychain declared for typesafe is not supported on this host; nothing sent
  PASS: no network call
  PASS: no Keychain call on unsupported host

## S7 Capability probe answers supported/unsupported without reading a declaration or running security

### S7a macos-keychain on this Mac (with an INVALID declaration present)
$ FM_HOME=<lab> fm-dispatch-resolve.sh --supports-credential-source macos-keychain   [extra env: none (values redacted)]
exit=0  stub_requests=0  security_calls=0  elapsed_s=0
stdout:
  | supported
  PASS: prints supported, exit 0
  PASS: security not run
  PASS: no network call

### S7b unknown source
$ FM_HOME=<lab> fm-dispatch-resolve.sh --supports-credential-source vault   [extra env: none (values redacted)]
exit=1  stub_requests=0  security_calls=0  elapsed_s=0
stdout:
  | unsupported
  PASS: prints unsupported, exit 1

### S7c macos-keychain on a non-macOS host
$ FM_HOME=<lab> fm-dispatch-resolve.sh --supports-credential-source macos-keychain   [extra env: none (values redacted)]
exit=1  stub_requests=0  security_calls=0  elapsed_s=0
stdout:
  | unsupported
  PASS: prints unsupported, exit 1

### S7d probe without a value
$ FM_HOME=<lab> fm-dispatch-resolve.sh --supports-credential-source   [extra env: none (values redacted)]
exit=2  stub_requests=0  security_calls=0  elapsed_s=0
stderr:
  ! error: --supports-credential-source needs a value
  PASS: usage error exit 2

## S8 Provider isolation: each provider reads only its own entry; a declaration never selects a provider

### S8a only openrouter declared, default provider (typesafe)
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=0  security_calls=0  elapsed_s=0
stderr:
  ! dispatch-resolve: off (TYPESAFE_API_KEY absent from the environment and <lab>/.env)
  PASS: off line, exit 0
  PASS: no Keychain call, no network call

### S8b provider openrouter with both declared
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: FM_DISPATCH_PROVIDER=openrouter FM_DISPATCH_MODEL=lab/model (values redacted)]
exit=0  stub_requests=1  security_calls=1  elapsed_s=0
stdout:
  | dispatch-resolve:
  |   status: clear
  |   model: jev-1.13.0   latency_ms: 50   tokens: 400/30
  |   rule: rule_1 (A simple bug fix with a stated root cause.)   confidence: 0.93
  |   probabilities: rule_1=0.93 rule_2=0.03 default=0.04
  |   note: rule matched
  |   candidate: claude:sonnet  provider=claude  -> eligible (quota ranking off: home declares a single shared quota)
  |   profile: --harness 'claude' --model 'sonnet' --effort 'high'
  security argv: security find-generic-password -s fm-lab-openrouter-<run> -w
  PASS: clear
  PASS: request went to openrouter.ai/api/alpha/decisions
  PASS: bearer equals the openrouter item, not typesafe's
  PASS: only the openrouter service was read

### S8c provider openrouter, only typesafe declared
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: FM_DISPATCH_PROVIDER=openrouter FM_DISPATCH_MODEL=lab/model (values redacted)]
exit=0  stub_requests=0  security_calls=0  elapsed_s=0
stderr:
  ! dispatch-resolve: off (OPENROUTER_API_KEY absent from the environment and <lab>/.env)
  PASS: off line for OPENROUTER_API_KEY
  PASS: no Keychain call, no network call

## S9 Effective-home isolation: only the effective config directory's declaration counts

### S9a FM_HOME=B (no declaration) while home A declares one
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: none (values redacted)]
exit=0  stub_requests=0  security_calls=0  elapsed_s=0
stderr:
  ! dispatch-resolve: off (TYPESAFE_API_KEY absent from the environment and <lab>/.env)
  PASS: off for B
  PASS: no Keychain call, no network call

### S9b FM_HOME=A but FM_CONFIG_OVERRIDE=B/config (no declaration)
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: FM_CONFIG_OVERRIDE=/var/folders/t1/hn73dcyn0mg70rx5np1f41_80000gn/T//fm-lab.Bf3t7N/config (values redacted)]
exit=0  stub_requests=0  security_calls=0  elapsed_s=0
stderr:
  ! dispatch-resolve: off (TYPESAFE_API_KEY absent from the environment and <lab>/.env)
  PASS: off: A's own config/ declaration ignored
  PASS: off line

### S9c FM_HOME=B with FM_CONFIG_OVERRIDE=A/config (declares)
$ FM_HOME=<lab> fm-dispatch-resolve.sh <W>/brief.md --project lab-proj   [extra env: FM_CONFIG_OVERRIDE=/var/folders/t1/hn73dcyn0mg70rx5np1f41_80000gn/T//fm-lab.LrlOEO/config (values redacted)]
exit=0  stub_requests=1  security_calls=1  elapsed_s=0
stdout:
  | dispatch-resolve:
  |   status: clear
  |   model: jev-1.13.0   latency_ms: 50   tokens: 400/30
  |   rule: rule_1 (A simple bug fix with a stated root cause.)   confidence: 0.93
  |   probabilities: rule_1=0.93 rule_2=0.03 default=0.04
  |   note: rule matched
  |   candidate: claude:sonnet  provider=claude  -> eligible (quota ranking off: home declares a single shared quota)
  |   profile: --harness 'claude' --model 'sonnet' --effort 'high'
  security argv: security find-generic-password -s fm-lab-typesafe-<run> -w
  PASS: clear via the override's declaration
  PASS: bearer equals ts item

## S10 Secret containment across every run
  PASS: no Keychain/.env secret in any resolver stdout/stderr or lab-home file
  PASS: no run left a key on curl argv/env (all stub snapshots)
  PASS: every stub request saw its curl in flight

RESULT: 96 checks passed, 0 failed
