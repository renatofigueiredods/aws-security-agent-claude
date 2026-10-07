#!/usr/bin/env bash
# Exercises the Stop hook of both plugins in a throwaway git repository.
# Usage: tests/hook-test.sh
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
fail=0

check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok    $1"; else echo "FAIL  $1 (expected '$2', got '$3')"; fail=1; fi
}

for plugin in aws-security-agent aws-security-agent-pt-br; do
  hook="$root/plugins/$plugin/hooks/diff-scan-suggester.sh"
  lang=$([ "$plugin" = "aws-security-agent-pt-br" ] && echo pt-br || echo en)
  repo=$(mktemp -d)
  git -C "$repo" init -q
  git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init

  run() { # stop_hook_active
    echo "{\"cwd\":\"$repo\",\"stop_hook_active\":${1:-false}}" |
      CLAUDE_PROJECT_DIR="$repo" bash "$hook" "$lang" | jq -r '.decision // empty'
  }

  echo "== $plugin"
  echo x >"$repo/app.py"
  check "no marker stays quiet" "" "$(run)"

  mkdir -p "$repo/.security-agent"
  printf '*\n' >"$repo/.security-agent/.gitignore"
  : >"$repo/.security-agent/diff-hook"
  check "new code blocks" "block" "$(run)"
  check "same diff stays quiet" "" "$(run)"

  echo y >>"$repo/app.py"
  check "stop_hook_active stays quiet" "" "$(run true)"
  check "changed code blocks" "block" "$(run)"

  git -C "$repo" add -A
  git -C "$repo" -c user.email=t@t -c user.name=t commit -qm c
  echo doc >"$repo/README.md"
  check "docs only stays quiet" "" "$(run)"

  rm -rf "$repo"
done

cmp -s "$root/plugins/aws-security-agent/hooks/diff-scan-suggester.sh" \
  "$root/plugins/aws-security-agent-pt-br/hooks/diff-scan-suggester.sh" &&
  echo "ok    hook script identical in both plugins" ||
  { echo "FAIL  hook script differs between plugins"; fail=1; }

exit $fail
