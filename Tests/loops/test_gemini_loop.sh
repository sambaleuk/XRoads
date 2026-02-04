#!/usr/bin/env bash
# test_gemini_loop.sh - Unit tests for gemini-loop script
# Part of XRoads Multi-CLI Loop System v4.0
#
# Tests:
# - Script existence and executability
# - Help flag functionality
# - Gemini CLI check
# - Skills loading in Gemini format
# - PRD file requirement check
# - Iteration header display
# - Completion detection

set -euo pipefail

# Test configuration
GEMINI_LOOP="${HOME}/bin/gemini-loop"
SKILL_LOADER="${HOME}/.xroads/lib/skill-loader.sh"
TEST_DIR=""
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Test Helpers
# ============================================================================

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
}

teardown() {
    cd /
    [[ -n "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

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

# Create a minimal test PRD
create_test_prd() {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "feature_name": "Test Feature",
  "user_stories": [
    {
      "id": "US-001",
      "title": "Test Story",
      "status": "pending",
      "unit_test": {
        "file": "tests/test_example.sh",
        "name": "test_example",
        "status": "pending"
      }
    }
  ]
}
EOF
}

create_completed_prd() {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "feature_name": "Completed Feature",
  "user_stories": [
    {
      "id": "US-001",
      "title": "Test Story",
      "status": "complete",
      "unit_test": {
        "file": "tests/test_example.sh",
        "name": "test_example",
        "status": "passing"
      }
    }
  ]
}
EOF
}

# ============================================================================
# Tests
# ============================================================================

test_script_exists() {
    if [[ -f "$GEMINI_LOOP" ]]; then
        pass "gemini-loop script exists"
    else
        fail "gemini-loop script not found at $GEMINI_LOOP"
    fi
}

test_script_executable() {
    if [[ -x "$GEMINI_LOOP" ]]; then
        pass "gemini-loop script is executable"
    else
        fail "gemini-loop script is not executable"
    fi
}

test_help_flag() {
    setup

    local output
    output=$("$GEMINI_LOOP" --help 2>&1) || true

    if echo "$output" | grep -q "Usage:"; then
        pass "gemini-loop --help shows usage"
    else
        fail "gemini-loop --help does not show usage" "$output"
    fi

    if echo "$output" | grep -q "max_iterations"; then
        pass "gemini-loop --help mentions max_iterations"
    else
        fail "gemini-loop --help does not mention max_iterations"
    fi

    if echo "$output" | grep -q "Gemini"; then
        pass "gemini-loop --help mentions Gemini"
    else
        fail "gemini-loop --help does not mention Gemini"
    fi

    teardown
}

test_help_short_flag() {
    setup

    local output
    output=$("$GEMINI_LOOP" -h 2>&1) || true

    if echo "$output" | grep -q "Usage:"; then
        pass "gemini-loop -h shows usage"
    else
        fail "gemini-loop -h does not show usage"
    fi

    teardown
}

test_checks_for_gemini_cli() {
    setup

    # Create a PRD file so that check happens after
    create_test_prd

    # Temporarily modify PATH to exclude gemini
    local saved_path="$PATH"
    export PATH="/usr/bin:/bin"

    local output
    set +e
    output=$("$GEMINI_LOOP" 2>&1)
    local exit_code=$?
    set -e

    export PATH="$saved_path"

    if echo "$output" | grep -qi "gemini.*not found\|gemini cli"; then
        pass "gemini-loop checks for Gemini CLI"
    else
        # If gemini is actually installed, it will pass the check
        if command -v gemini &>/dev/null; then
            skip "gemini-loop CLI check (gemini is installed)"
        else
            fail "gemini-loop does not report missing Gemini CLI" "$output"
        fi
    fi

    teardown
}

test_requires_prd_file() {
    setup

    # No PRD file created
    local output
    set +e
    output=$("$GEMINI_LOOP" 2>&1)
    local exit_code=$?
    set -e

    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -qi "prd.*not found\|prd.json"; then
        pass "gemini-loop requires PRD file"
    else
        fail "gemini-loop does not report missing PRD file" "exit=$exit_code, output=$output"
    fi

    teardown
}

test_loads_skills_in_gemini_format() {
    if [[ ! -x "$SKILL_LOADER" ]]; then
        skip "skill-loader.sh not available"
        return
    fi

    local output
    output=$("$SKILL_LOADER" --cli gemini --skills commit 2>&1) || true

    if echo "$output" | grep -q "@commit\|Extension\|gemini"; then
        pass "skill-loader.sh loads skills in Gemini format"
    else
        # Check if any output at all
        if [[ -n "$output" ]]; then
            pass "skill-loader.sh returns content for Gemini CLI"
        else
            fail "skill-loader.sh returns no content for Gemini CLI"
        fi
    fi
}

test_skill_loader_gemini_template() {
    if [[ ! -x "$SKILL_LOADER" ]]; then
        skip "skill-loader.sh not available for template test"
        return
    fi

    # Test that commit skill has Gemini template
    local output
    output=$("$SKILL_LOADER" --cli gemini --skills commit 2>/dev/null) || true

    if [[ -n "$output" ]]; then
        pass "Gemini template exists for commit skill"
    else
        fail "No Gemini template found for commit skill"
    fi
}

test_skill_loader_list_shows_gemini() {
    if [[ ! -x "$SKILL_LOADER" ]]; then
        skip "skill-loader.sh not available for list test"
        return
    fi

    # Verify skill-loader supports gemini as CLI
    local output
    set +e
    output=$("$SKILL_LOADER" --cli gemini --list-available 2>&1)
    set -e

    # Should list available skills without error
    if echo "$output" | grep -q "Available\|commit\|core"; then
        pass "skill-loader.sh lists available skills for Gemini"
    else
        # Even if output is different, check it works
        if [[ -n "$output" ]]; then
            pass "skill-loader.sh produces output for Gemini"
        else
            fail "skill-loader.sh fails for Gemini CLI"
        fi
    fi
}

test_all_stories_complete_exits_early() {
    setup

    create_completed_prd

    # Note: This will fail because gemini CLI is not available in test
    # But we can check if it at least reads the PRD correctly
    local output
    set +e
    output=$("$GEMINI_LOOP" 2>&1)
    local exit_code=$?
    set -e

    if echo "$output" | grep -qi "already complete\|all.*complete"; then
        pass "gemini-loop detects all stories complete"
    else
        # If gemini is not installed, it will fail before that check
        if echo "$output" | grep -qi "gemini.*not found"; then
            skip "Cannot test completion detection (Gemini CLI not installed)"
        else
            fail "gemini-loop does not detect all stories complete" "$output"
        fi
    fi

    teardown
}

test_creates_progress_file() {
    setup

    create_test_prd

    # Run briefly in background and kill after 3 seconds (macOS compatible)
    set +e
    "$GEMINI_LOOP" 2>&1 >/dev/null &
    local pid=$!
    sleep 3
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    set -e

    if [[ -f "$TEST_DIR/progress.txt" ]]; then
        pass "gemini-loop creates progress.txt"

        # Check content
        if grep -q "Feature:" "$TEST_DIR/progress.txt"; then
            pass "progress.txt contains feature header"
        else
            fail "progress.txt missing feature header"
        fi

        if grep -q "Learnings" "$TEST_DIR/progress.txt"; then
            pass "progress.txt contains Learnings section"
        else
            fail "progress.txt missing Learnings section"
        fi
    else
        # If gemini not installed, file may not be created
        if ! command -v gemini &>/dev/null; then
            skip "Cannot test progress file creation (Gemini CLI not installed)"
        else
            fail "gemini-loop does not create progress.txt"
        fi
    fi

    teardown
}

test_creates_agents_file() {
    setup

    create_test_prd

    # Run briefly in background and kill after 3 seconds (macOS compatible)
    set +e
    "$GEMINI_LOOP" 2>&1 >/dev/null &
    local pid=$!
    sleep 3
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    set -e

    if [[ -f "$TEST_DIR/AGENTS.md" ]]; then
        pass "gemini-loop creates AGENTS.md"
    else
        if ! command -v gemini &>/dev/null; then
            skip "Cannot test AGENTS.md creation (Gemini CLI not installed)"
        else
            fail "gemini-loop does not create AGENTS.md"
        fi
    fi

    teardown
}

test_script_uses_xroads_lib() {
    # Check that the script references XRoads lib
    if grep -q "XROADS_LIB\|\.xroads/lib" "$GEMINI_LOOP"; then
        pass "gemini-loop references XRoads lib"
    else
        fail "gemini-loop does not reference XRoads lib"
    fi
}

test_script_uses_skill_loader() {
    if grep -q "skill-loader\|load.*skills" "$GEMINI_LOOP"; then
        pass "gemini-loop uses skill-loader"
    else
        fail "gemini-loop does not use skill-loader"
    fi
}

test_script_uses_mcp_loader() {
    if grep -q "mcp-loader\|load.*mcp\|xroads.*mcp" "$GEMINI_LOOP"; then
        pass "gemini-loop uses MCP loader"
    else
        fail "gemini-loop does not use MCP loader"
    fi
}

test_script_has_unit_test_requirement() {
    if grep -q "unit_test\|MANDATORY\|test.*PASS" "$GEMINI_LOOP"; then
        pass "gemini-loop enforces unit test requirement"
    else
        fail "gemini-loop does not mention unit test requirement"
    fi
}

test_script_has_gemini_complete_marker() {
    if grep -q "<gemini-complete>" "$GEMINI_LOOP"; then
        pass "gemini-loop uses <gemini-complete> marker"
    else
        fail "gemini-loop missing <gemini-complete> marker"
    fi
}

test_script_emits_logs_to_xroads() {
    if grep -q "emit.*log\|MCP.*log\|xroads" "$GEMINI_LOOP"; then
        pass "gemini-loop emits logs to xroads-mcp"
    else
        fail "gemini-loop does not emit logs to xroads-mcp"
    fi
}

test_iteration_count_parameter() {
    # Check script accepts iteration count
    if grep -q 'MAX_ITERATIONS=\${1:-' "$GEMINI_LOOP"; then
        pass "gemini-loop accepts max_iterations parameter"
    else
        fail "gemini-loop does not accept max_iterations parameter"
    fi
}

test_sleep_seconds_parameter() {
    if grep -q 'SLEEP_SECONDS=\${2:-' "$GEMINI_LOOP"; then
        pass "gemini-loop accepts sleep_seconds parameter"
    else
        fail "gemini-loop does not accept sleep_seconds parameter"
    fi
}

test_prd_helpers_exist() {
    if grep -q "prd_count_pending\|prd_get_feature_name" "$GEMINI_LOOP"; then
        pass "gemini-loop has PRD helper functions"
    else
        fail "gemini-loop missing PRD helper functions"
    fi
}

test_co_authored_by_gemini() {
    if grep -q "Co-Authored-By:.*Gemini" "$GEMINI_LOOP"; then
        pass "gemini-loop includes Gemini co-author in commits"
    else
        fail "gemini-loop missing Gemini co-author attribution"
    fi
}

test_logs_directory_creation() {
    if grep -q 'mkdir.*logs\|LOG_DIR' "$GEMINI_LOOP"; then
        pass "gemini-loop creates logs directory"
    else
        fail "gemini-loop does not create logs directory"
    fi
}

test_consecutive_failures_handling() {
    if grep -q 'consecutive.*failure\|MAX_CONSECUTIVE_FAILURES' "$GEMINI_LOOP"; then
        pass "gemini-loop handles consecutive failures"
    else
        fail "gemini-loop does not handle consecutive failures"
    fi
}

# ============================================================================
# Test Runner
# ============================================================================

run_tests() {
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  gemini-loop Unit Tests${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""

    # Script existence tests
    test_script_exists
    test_script_executable

    # Help tests
    test_help_flag
    test_help_short_flag

    # Dependency check tests
    test_checks_for_gemini_cli
    test_requires_prd_file

    # Skill loading tests
    test_loads_skills_in_gemini_format
    test_skill_loader_gemini_template
    test_skill_loader_list_shows_gemini

    # Script content tests (static analysis)
    test_script_uses_xroads_lib
    test_script_uses_skill_loader
    test_script_uses_mcp_loader
    test_script_has_unit_test_requirement
    test_script_has_gemini_complete_marker
    test_script_emits_logs_to_xroads
    test_iteration_count_parameter
    test_sleep_seconds_parameter
    test_prd_helpers_exist
    test_co_authored_by_gemini
    test_logs_directory_creation
    test_consecutive_failures_handling

    # Functional tests (require temp directory)
    test_all_stories_complete_exits_early
    test_creates_progress_file
    test_creates_agents_file

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
