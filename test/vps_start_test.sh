#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/scripts" "$fixture/config"
cp "$root/scripts/vps.sh" "$fixture/scripts/vps.sh"
cat > "$fixture/bin/docker" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TEST_CALL_LOG"
if [[ "${FAIL_SETUP:-0}" == 1 && "$*" == *scripts/setup_pilot.rb* ]]; then exit 2; fi
if [[ "${FAIL_BUILD:-0}" == 1 && "$*" == 'compose build radar telegram' ]]; then exit 2; fi
SH
cat > "$fixture/bin/sudo" <<'SH'
#!/usr/bin/env bash
exec "$@"
SH
chmod +x "$fixture/bin/docker" "$fixture/bin/sudo"
export PATH="$fixture/bin:$PATH" TEST_CALL_LOG="$fixture/calls"
for failure in FAIL_SETUP FAIL_BUILD; do
  : > "$TEST_CALL_LOG"
  if env "$failure=1" bash "$fixture/scripts/vps.sh" start --provider mistral > /dev/null; then
    echo "Expected preparation failure" >&2; exit 1
  fi
  if grep -q 'compose stop' "$TEST_CALL_LOG"; then
    echo "Workers stopped before preparation succeeded" >&2; exit 1
  fi
done
: > "$TEST_CALL_LOG"
bash "$fixture/scripts/vps.sh" start --provider mistral > /dev/null
awk '/ruby bin\/radar validate/ {validated=1} /compose build radar telegram/ {built=1} /compose stop/ {if (!validated || !built) exit 1; stopped=1} END {if (!stopped) exit 1}' "$TEST_CALL_LOG"
echo "PASS: setup/build failures keep services running; success validates and builds before stop."
