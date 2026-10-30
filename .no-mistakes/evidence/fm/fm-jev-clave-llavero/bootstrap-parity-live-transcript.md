# Live run: bootstrap typed-validation gate follows a declared typesafe source
worktree head: 1fd70fa5   real bin/fm-bootstrap.sh, FM_BOOTSTRAP_DETECT_ONLY=1 FM_BOOTSTRAP_NETWORK=skip, fresh lab home per case, no TYPESAFE_API_KEY anywhere

### B1 gemini profile + declared typesafe Keychain source (typed checks on)
crew-dispatch.json: {"rules":[{"when":"gemini work","use":{"harness":"gemini","model":"gemini-3.8-flash-high","provider":"google"}}]}
dispatch-credential-sources.json: {"typesafe":{"source":"macos-keychain","service":"fm-lab-typesafe-ce2c108f"}}
bootstrap CREW_DISPATCH lines: <none>
security invocations during bootstrap: 0
  PASS (expected: <none>)

### B2 gemini profile, no declaration (today's no-key list)
crew-dispatch.json: {"rules":[{"when":"gemini work","use":{"harness":"gemini","model":"gemini-3.8-flash-high","provider":"google"}}]}
dispatch-credential-sources.json: <absent>
bootstrap CREW_DISPATCH lines: CREW_DISPATCH: invalid config/crew-dispatch.json - unverified harness: gemini
security invocations during bootstrap: 0
  PASS (expected: CREW_DISPATCH: invalid config/crew-dispatch.json - unverified harness: gemini)

### B3 gemini profile + INVALID declaration (keeps today's behavior)
crew-dispatch.json: {"rules":[{"when":"gemini work","use":{"harness":"gemini","model":"gemini-3.8-flash-high","provider":"google"}}]}
dispatch-credential-sources.json: {"typesafe":{"source":"macos-keychain","service":"x","key":"sk-LAB-MUST-NOT-ECHO"}}
bootstrap CREW_DISPATCH lines: CREW_DISPATCH: invalid config/crew-dispatch.json - unverified harness: gemini
security invocations during bootstrap: 0
  PASS (expected: CREW_DISPATCH: invalid config/crew-dispatch.json - unverified harness: gemini)

### B4 gemini profile + only openrouter declared (typesafe not declared)
crew-dispatch.json: {"rules":[{"when":"gemini work","use":{"harness":"gemini","model":"gemini-3.8-flash-high","provider":"google"}}]}
dispatch-credential-sources.json: {"openrouter":{"source":"macos-keychain","service":"fm-lab-openrouter-ce2c108f"}}
bootstrap CREW_DISPATCH lines: CREW_DISPATCH: invalid config/crew-dispatch.json - unverified harness: gemini
security invocations during bootstrap: 0
  PASS (expected: CREW_DISPATCH: invalid config/crew-dispatch.json - unverified harness: gemini)

### B5 approval "Captain" + declared typesafe source (typed rule enforced, as the resolver will)
crew-dispatch.json: {"rules":[{"when":"hard design","approval":"Captain","use":{"harness":"claude"}}]}
dispatch-credential-sources.json: {"typesafe":{"source":"macos-keychain","service":"fm-lab-typesafe-ce2c108f"}}
bootstrap CREW_DISPATCH lines: CREW_DISPATCH: invalid config/crew-dispatch.json - approval must be "captain" when present
security invocations during bootstrap: 0
  PASS (expected: CREW_DISPATCH: invalid config/crew-dispatch.json - approval must be "captain" when present)

### B6 approval "Captain", no declaration (today's no-key behavior)
crew-dispatch.json: {"rules":[{"when":"hard design","approval":"Captain","use":{"harness":"claude"}}]}
dispatch-credential-sources.json: <absent>
bootstrap CREW_DISPATCH lines: <none>
security invocations during bootstrap: 0
  PASS (expected: <none>)

RESULT: 6 cases passed, 0 failed

## Resolver on the same configs (same declaration, real Keychain item, stubbed endpoint)
### resolver, gemini rule + declared typesafe source: exit=0 stub_requests=1
  |   status: error
  |   reason: response is not a rule Choice answer
  ! dispatch-resolve: error (response is not a rule Choice answer)
### resolver, captain rule + declared typesafe source: exit=2 stub_requests=0
  ! error: malformed rules file: <lab>/config/crew-dispatch.json - approval must be "captain" when present
(the gemini run above ended in error only because the stub's fixed answer carries rule_1, rule_2 and default while that file has one rule; re-run with two rules:)
### resolver, gemini rule (2-rule file) + declared typesafe source: exit=0 bearer=["ts"]
  |   status: clear
  |   rule: rule_1 (A simple bug fix with a stated root cause.)   confidence: 0.93
  |   candidate: gemini:gemini-3.8-flash-high  provider=google  -> eligible (quota ranking off: home declares a single shared quota)
  |   profile: --harness 'gemini' --model 'gemini-3.8-flash-high'
### bootstrap on this same home: CREW_DISPATCH lines: <none>
