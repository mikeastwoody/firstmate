#!/usr/bin/env bash
# Serves the resolver test suite's schema-5 quota fixture; logs each call.
LAB=${FM_LAB:?}; echo "quota-axi $*" >> "$LAB/logs/quota.log"; cat "$LAB/fixtures/quota.json"
