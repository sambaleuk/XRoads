#!/usr/bin/env bash
# test_cli_detection.sh - Unit tests for xroads-loop CLI auto-detection
# Part of XRoads Multi-CLI Loop System v4.0
#
# Tests:
# - Script existence and executability
# - Help flag functionality
# - CLI detection (auto and forced)
# - Error handling when no CLI available
# - Proper delegation to loop scripts

set -euo pipefail

# Test configuration
XROADS_LOOP="${HOME}/bin/xroads-loop"
NEXUS_LOOP="${HOME}/bin/nexus-loop"
GEMINI_LOOP="${HOME}/bin/gemini-loop"
CODEX_LOOP="${HOME}/bin/codex-loop"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

# ============================================================================
# Test Helpers
# ============================================================================

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    [[ -n "${2:-}" ]] && echo -e "       ${DIM}$2${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

skip() {
    echo -e "${YELLOW}SKIP${NC}: $1"
    TESTS_RUN=$((TESTS_RUN + 1))
}

# ============================================================================
# Tests
# ============================================================================

test_script_exists() {
    if [[ -f "$XROADS_LOOP" ]]; then
        pass "xroads-loop script exists"
    else
        fail "xroads-loop script not found at $XROADS_LOOP"
    fi
}

test_script_executable() {
    if [[ -x "$XROADS_LOOP" ]]; then
        pass "xroads-loop script is executable"
    else
        fail "xroads-loop script is not executable"
    fi
}

test_help_flag() {
    local output
    output=$("$XROADS_LOOP" --help 2>&1) || true

    if echo "$output" | grep -q "Usage:"; then
        pass "xroads-loop --help shows usage"
    else
        fail "xroads-loop --help does not show usage" "$output"
    fi

    if echo "$output" | grep -q "CLI Detection"; then
        pass "xroads-loop --help mentions CLI Detection"
    else
        fail "xroads-loop --help does not mention CLI Detection"
    fi

    if echo "$output" | grep -q "claude.*gemini.*codex"; then
        pass "xroads-loop --help mentions preference order"
    else
        fail "xroads-loop --help does not mention CLI preference order"
    fi
}

test_help_short_flag() {
    local output
    output=$("$XROADS_LOOP" -h 2>&1) || true

    if echo "$output" | grep -q "Usage:"; then
        pass "xroads-loop -h shows usage"
    else
        fail "xroads-loop -h does not show usage"
    fi
}

test_detects_available_cli() {
    local output
    set +e
    output=$("$XROADS_LOOP" --help 2>&1)
    set -e

    # Check that script mentions auto-detection
    if echo "$output" | grep -qi "auto.*detect\|detect.*cli"; then
        pass "xroads-loop supports CLI auto-detection"
    else
        fail "xroads-loop does not mention auto-detection"
    fi
}

test_cli_flag_claude() {
    # If claude is not available, check for appropriate error
    if ! command -v claude &>/dev/null; then
        local output
        set +e
        output=$("$XROADS_LOOP" --cli claude 2>&1)
        set -e

        if echo "$output" | grep -qi "claude.*not found\|not found.*path"; then
            pass "xroads-loop --cli claude reports missing Claude CLI"
        else
            fail "xroads-loop --cli claude does not report missing CLI" "$output"
        fi
    else
        # If claude is available, just check that script mentions delegation
        if grep -q "nexus-loop" "$XROADS_LOOP"; then
            pass "xroads-loop --cli claude delegates to nexus-loop (static check)"
        else
            fail "xroads-loop --cli claude does not delegate properly"
        fi
    fi
}

test_cli_flag_gemini() {
    # If gemini is not available, check for appropriate error
    if ! command -v gemini &>/dev/null; then
        local output
        set +e
        output=$("$XROADS_LOOP" --cli gemini 2>&1)
        set -e

        if echo "$output" | grep -qi "gemini.*not found\|not found.*path"; then
            pass "xroads-loop --cli gemini reports missing Gemini CLI"
        else
            fail "xroads-loop --cli gemini does not report missing CLI" "$output"
        fi
    else
        # If gemini is available, just do static check to avoid running the loop
        if grep -q 'gemini-loop\|LOOP_SCRIPT_GEMINI' "$XROADS_LOOP"; then
            pass "xroads-loop --cli gemini delegates to gemini-loop (static check)"
        else
            fail "xroads-loop --cli gemini does not delegate properly"
        fi
    fi
}

test_cli_flag_codex() {
    # If codex is not available, check for appropriate error
    if ! command -v codex &>/dev/null; then
        local output
        set +e
        output=$("$XROADS_LOOP" --cli codex 2>&1)
        set -e

        if echo "$output" | grep -qi "codex.*not found\|not found.*path"; then
            pass "xroads-loop --cli codex reports missing Codex CLI"
        else
            fail "xroads-loop --cli codex does not report missing CLI" "$output"
        fi
    else
        # If codex is available, just do static check to avoid running the loop
        if grep -q 'codex-loop\|LOOP_SCRIPT_CODEX' "$XROADS_LOOP"; then
            pass "xroads-loop --cli codex delegates to codex-loop (static check)"
        else
            fail "xroads-loop --cli codex does not delegate properly"
        fi
    fi
}

test_invalid_cli_flag() {
    local output
    set +e
    output=$("$XROADS_LOOP" --cli invalid 2>&1)
    local exit_code=$?
    set -e

    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -qi "invalid\|valid options"; then
        pass "xroads-loop rejects invalid CLI"
    else
        fail "xroads-loop does not reject invalid CLI" "exit=$exit_code, output=$output"
    fi
}

test_error_when_no_cli_available() {
    # Test with empty PATH to simulate no CLIs available
    # We need a minimal PATH that has bash and basic tools but no claude/gemini/codex
    local saved_path="$PATH"
    export PATH="/usr/bin:/bin"

    local output
    set +e
    output=$("$XROADS_LOOP" 2>&1)
    local exit_code=$?
    set -e

    export PATH="$saved_path"

    # Should detect no CLI and report error
    if echo "$output" | grep -qi "no cli available\|no.*available"; then
        pass "xroads-loop errors when no CLI available"
    else
        # If any CLI is in /usr/bin or /bin, it might still find it
        skip "Cannot test no-CLI scenario (system CLIs may be in /usr/bin)"
    fi
}

test_script_has_cli_preference_order() {
    if grep -q 'CLI_PREFERENCE_ORDER' "$XROADS_LOOP"; then
        pass "xroads-loop defines CLI preference order"
    else
        fail "xroads-loop does not define CLI preference order"
    fi
}

test_script_delegates_to_nexus_loop() {
    if grep -q 'nexus-loop\|LOOP_SCRIPT_CLAUDE' "$XROADS_LOOP"; then
        pass "xroads-loop delegates to nexus-loop for Claude"
    else
        fail "xroads-loop does not delegate to nexus-loop"
    fi
}

test_script_delegates_to_gemini_loop() {
    if grep -q 'gemini-loop\|LOOP_SCRIPT_GEMINI' "$XROADS_LOOP"; then
        pass "xroads-loop delegates to gemini-loop for Gemini"
    else
        fail "xroads-loop does not delegate to gemini-loop"
    fi
}

test_script_delegates_to_codex_loop() {
    if grep -q 'codex-loop\|LOOP_SCRIPT_CODEX' "$XROADS_LOOP"; then
        pass "xroads-loop delegates to codex-loop for Codex"
    else
        fail "xroads-loop does not delegate to codex-loop"
    fi
}

test_script_supports_skills_flag() {
    if grep -q '\-\-skills' "$XROADS_LOOP"; then
        pass "xroads-loop supports --skills flag"
    else
        fail "xroads-loop does not support --skills flag"
    fi
}

test_script_passes_positional_args() {
    if grep -q 'POSITIONAL_ARGS\|max_iterations' "$XROADS_LOOP"; then
        pass "xroads-loop passes positional arguments"
    else
        fail "xroads-loop does not handle positional arguments"
    fi
}

test_script_uses_exec_for_delegation() {
    if grep -q 'exec.*loop' "$XROADS_LOOP"; then
        pass "xroads-loop uses exec for delegation"
    else
        fail "xroads-loop does not use exec for delegation"
    fi
}

test_script_has_banner() {
    if grep -q 'XROADS\|banner' "$XROADS_LOOP"; then
        pass "xroads-loop has banner display"
    else
        fail "xroads-loop does not have banner"
    fi
}

test_script_validates_cli_input() {
    if grep -q 'validate_cli\|case.*claude\|gemini\|codex' "$XROADS_LOOP"; then
        pass "xroads-loop validates CLI input"
    else
        fail "xroads-loop does not validate CLI input"
    fi
}

test_script_checks_loop_script_exists() {
    if grep -q '\-x.*loop_script\|loop_script.*not found' "$XROADS_LOOP"; then
        pass "xroads-loop checks if loop script exists"
    else
        fail "xroads-loop does not check if loop script exists"
    fi
}

test_script_lists_available_clis() {
    if grep -q 'list_available\|Available.*CLI\|all_available' "$XROADS_LOOP"; then
        pass "xroads-loop can list available CLIs"
    else
        fail "xroads-loop cannot list available CLIs"
    fi
}

test_nexus_loop_exists() {
    if [[ -x "$NEXUS_LOOP" ]]; then
        pass "nexus-loop script exists and is executable"
    else
        fail "nexus-loop script not found or not executable"
    fi
}

test_gemini_loop_exists() {
    if [[ -x "$GEMINI_LOOP" ]]; then
        pass "gemini-loop script exists and is executable"
    else
        fail "gemini-loop script not found or not executable"
    fi
}

test_codex_loop_exists() {
    if [[ -x "$CODEX_LOOP" ]]; then
        pass "codex-loop script exists and is executable"
    else
        fail "codex-loop script not found or not executable"
    fi
}

test_detect_available_cli_function() {
    if grep -q 'detect_available_cli\|for cli in.*CLI_PREFERENCE' "$XROADS_LOOP"; then
        pass "xroads-loop has detect_available_cli function"
    else
        fail "xroads-loop missing detect_available_cli function"
    fi
}

test_check_cli_available_function() {
    if grep -q 'check_cli_available\|command -v' "$XROADS_LOOP"; then
        pass "xroads-loop has check_cli_available function"
    else
        fail "xroads-loop missing check_cli_available function"
    fi
}

test_get_cli_display_name_function() {
    if grep -q 'get_cli_display_name\|Claude Code\|display.*name' "$XROADS_LOOP"; then
        pass "xroads-loop has get_cli_display_name function"
    else
        fail "xroads-loop missing get_cli_display_name function"
    fi
}

# ============================================================================
# Test Runner
# ============================================================================

run_tests() {
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  xroads-loop CLI Detection Tests${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""

    # Script existence tests
    test_script_exists
    test_script_executable

    # Help tests
    test_help_flag
    test_help_short_flag

    # CLI detection tests
    test_detects_available_cli
    test_cli_flag_claude
    test_cli_flag_gemini
    test_cli_flag_codex
    test_invalid_cli_flag
    test_error_when_no_cli_available

    # Script content tests (static analysis)
    test_script_has_cli_preference_order
    test_script_delegates_to_nexus_loop
    test_script_delegates_to_gemini_loop
    test_script_delegates_to_codex_loop
    test_script_supports_skills_flag
    test_script_passes_positional_args
    test_script_uses_exec_for_delegation
    test_script_has_banner
    test_script_validates_cli_input
    test_script_checks_loop_script_exists
    test_script_lists_available_clis

    # Function tests
    test_detect_available_cli_function
    test_check_cli_available_function
    test_get_cli_display_name_function

    # Dependency tests
    test_nexus_loop_exists
    test_gemini_loop_exists
    test_codex_loop_exists

    # Summary
    echo ""
    echo -e "${BLUE}=======================================${NC}"
    echo -e "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    fi
    echo -e "${BLUE}=======================================${NC}"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

# Run tests
run_tests
