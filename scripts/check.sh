#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

resolve_godot_bin() {
	if [[ -n "${GODOT_BIN:-}" ]]; then
		echo "${GODOT_BIN}"
		return 0
	fi

	if command -v godot4 >/dev/null 2>&1; then
		command -v godot4
		return 0
	fi

	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return 0
	fi

	if command -v Godot >/dev/null 2>&1; then
		command -v Godot
		return 0
	fi

	# Common macOS app bundle path (binary name in newer installs).
	if [[ -x "/Applications/Godot.app/Contents/MacOS/godot" ]]; then
		echo "/Applications/Godot.app/Contents/MacOS/godot"
		return 0
	fi

	# Common macOS app bundle path.
	if [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
		echo "/Applications/Godot.app/Contents/MacOS/Godot"
		return 0
	fi

	# Legacy team Linux path (kept for compatibility with existing dev setups).
	if [[ -x "/ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64" ]]; then
		echo "/ssd2/godot/4.6.1/Godot_v4.6.1-stable_linux.x86_64"
		return 0
	fi

	echo "Godot binary not found. Set GODOT_BIN=/absolute/path/to/godot or add godot4/godot/Godot to PATH." >&2
	return 1
}

GODOT_BIN="$(resolve_godot_bin)"
GODOT_LOG_FILE="${GODOT_LOG_FILE:-${TMPDIR:-/tmp}/octotest-godot.log}"

export HOME=/tmp
export XDG_DATA_HOME=/tmp
export XDG_CONFIG_HOME=/tmp

echo "[check] boot smoke test"
"${GODOT_BIN}" --headless --path "${PROJECT_ROOT}" --log-file "${GODOT_LOG_FILE}" --quit-after 5

echo "[check] movement math unit tests"
"${GODOT_BIN}" --headless --path "${PROJECT_ROOT}" --log-file "${GODOT_LOG_FILE}" --script res://tests/movement_math_test.gd

echo "[check] slope integration test"
"${GODOT_BIN}" --headless --path "${PROJECT_ROOT}" --log-file "${GODOT_LOG_FILE}" --script res://tests/slope_movement_test.gd

echo "[check] octorig startup integration test"
"${GODOT_BIN}" --headless --path "${PROJECT_ROOT}" --log-file "${GODOT_LOG_FILE}" --script res://tests/octorig_startup_test.gd

echo "[check] card reader interaction test"
"${GODOT_BIN}" --headless --path "${PROJECT_ROOT}" --log-file "${GODOT_LOG_FILE}" --script res://tests/card_reader_interaction_test.gd

echo "[check] PASS"
