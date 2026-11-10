#!/usr/bin/env bash
# Run the REAL quota-axi against a disposable cache fixture, isolated from the operator's home.
set -u
LAB=$(cat /tmp/fm-lab-path-01M72Z)
exec env -i PATH="/opt/homebrew/bin:/usr/bin:/bin" HOME="$LAB/qhome" XDG_CONFIG_HOME="$LAB/qhome/.config" \
  XDG_CACHE_HOME="$LAB/qhome/.cache" QUOTA_AXI_SNAPSHOT="$QA_FIXTURE" /opt/homebrew/bin/quota-axi "$@"
