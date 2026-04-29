#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SWITCHYARD_ROOT:-}" ]]; then
  echo "SWITCHYARD_ROOT is required" >&2
  exit 2
fi

CLI_DIR="$SWITCHYARD_ROOT/apps/terminal_workbench_cli"

run_cli() {
  local argv_literal="$1"
  (cd "$CLI_DIR" && mix run -e "Switchyard.CLI.main($argv_literal)")
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "expected output to contain: $needle" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

sites_output="$(run_cli '["sites"]')"
assert_contains "$sites_output" "execution_plane"
assert_contains "$sites_output" "jido"

apps_output="$(run_cli '["apps", "execution_plane"]')"
assert_contains "$apps_output" "execution_plane.processes"
assert_contains "$apps_output" "execution_plane.streams"

actions_output="$(run_cli '["actions", "--site", "execution_plane"]')"
assert_contains "$actions_output" "execution_plane.process.start"
assert_contains "$actions_output" "execution_plane.process.stop"

jido_action_output="$(run_cli '["action", "run", "jido.review.refresh", "--site", "jido", "--input-json", "{\"force\":true}"]')"
assert_contains "$jido_action_output" "durable state refreshed"
assert_contains "$jido_action_output" "force"

process_output="$(run_cli '["process", "start", "--id", "example-cli-smoke", "--command", "printf '\''cli smoke\\n'\''"]')"
assert_contains "$process_output" "accepted"
assert_contains "$process_output" "logs/example-cli-smoke"

recovery_output="$(run_cli '["recovery"]')"
assert_contains "$recovery_output" "memory_only"

echo "switchyard CLI smoke passed"
