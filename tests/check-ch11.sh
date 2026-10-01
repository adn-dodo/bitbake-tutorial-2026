#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../ch11/build"
config=$(mktemp --suffix=.conf)
trap 'rm -f "$config"' EXIT
bitbake -g task-order
grep -q '"task-order.do_middle" -> "task-source.do_prepare"' task-depends.dot
bitbake -C begin task-order
test "$(cat tmp/work/task-order-1.0-r0/order.txt)" = "$(printf 'begin\nmiddle\nfinish')"
test "$(cat tmp/work/task-source-1.0-r0/ready.txt)" = source-ready
printf 'DIRECT_DEPENDS = ""\n' > "$config"
bitbake -R "$config" -g task-order
if grep -q '"task-order.do_middle" -> "task-source.do_prepare"' task-depends.dot; then
    echo 'Unexpected task edge from DEPENDS alone' >&2
    exit 1
fi
bitbake -g task-order
echo 'Chapter 11 checks passed'
