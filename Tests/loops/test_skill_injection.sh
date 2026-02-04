#!/usr/bin/env bash
# test_skill_injection.sh - Unit tests for loop skill injection
# Part of XRoads Multi-CLI Loop System v4.0
#
# Tests:
# - Skills flag parsing in all loops
# - Skill injection into AGENTS.md
# - Skills are CLI-format specific
# - Default core skills loading
#
# Story: US-V4-007 - Loop Skill Injection

set -euo pipefail

# Test configuration
NEXUS_LOOP="${HOME}/bin/nexus-loop"
CODEX_LOOP="${HOME}/bin/codex-loop"
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
DIM='\033[2m'
NC='\033[0m'

# ============================================================================
# Test Helpers
# ============================================================================

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    # Create a minimal PRD file
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

    # Initialize git repo for branch detection
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
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

# ============================================================================
# Tests: nexus-loop --skills flag
# ============================================================================

test_nexus_loop_has_skills_flag() {
    if grep -q '\-\-skills' "$NEXUS_LOOP" 2>/dev/null; then
        pass "nexus-loop has --skills flag"
    else
        fail "nexus-loop missing --skills flag"
    fi
}

test_nexus_loop_help_shows_skills() {
    local output
    output=$("$NEXUS_LOOP" --help 2>&1) || true

    if echo "$output" | grep -q -- '--skills'; then
        pass "nexus-loop --help shows --skills option"
    else
        fail "nexus-loop --help missing --skills option" "$output"
    fi
}

test_nexus_loop_parses_skills_argument() {
    if grep -q 'SKILLS_ARG=' "$NEXUS_LOOP" 2>/dev/null; then
        pass "nexus-loop parses SKILLS_ARG"
    else
        fail "nexus-loop does not parse SKILLS_ARG"
    fi
}

test_nexus_loop_injects_skills_function() {
    if grep -q 'inject_skills' "$NEXUS_LOOP" 2>/dev/null; then
        pass "nexus-loop has inject_skills function"
    else
        fail "nexus-loop missing inject_skills function"
    fi
}

# ============================================================================
# Tests: codex-loop --skills flag
# ============================================================================

test_codex_loop_has_skills_flag() {
    if grep -q '\-\-skills' "$CODEX_LOOP" 2>/dev/null; then
        pass "codex-loop has --skills flag"
    else
        fail "codex-loop missing --skills flag"
    fi
}

test_codex_loop_help_shows_skills() {
    local output
    output=$("$CODEX_LOOP" --help 2>&1) || true

    if echo "$output" | grep -q -- '--skills'; then
        pass "codex-loop --help shows --skills option"
    else
        fail "codex-loop --help missing --skills option" "$output"
    fi
}

test_codex_loop_parses_skills_argument() {
    if grep -q 'SKILLS_ARG=' "$CODEX_LOOP" 2>/dev/null; then
        pass "codex-loop parses SKILLS_ARG"
    else
        fail "codex-loop does not parse SKILLS_ARG"
    fi
}

test_codex_loop_injects_skills_function() {
    if grep -q 'inject_skills' "$CODEX_LOOP" 2>/dev/null; then
        pass "codex-loop has inject_skills function"
    else
        fail "codex-loop missing inject_skills function"
    fi
}

# ============================================================================
# Tests: gemini-loop --skills flag
# ============================================================================

test_gemini_loop_has_skills_flag() {
    if grep -q '\-\-skills' "$GEMINI_LOOP" 2>/dev/null; then
        pass "gemini-loop has --skills flag"
    else
        fail "gemini-loop missing --skills flag"
    fi
}

test_gemini_loop_help_shows_skills() {
    local output
    output=$("$GEMINI_LOOP" --help 2>&1) || true

    if echo "$output" | grep -q -- '--skills'; then
        pass "gemini-loop --help shows --skills option"
    else
        fail "gemini-loop --help missing --skills option" "$output"
    fi
}

test_gemini_loop_parses_skills_argument() {
    if grep -q 'SKILLS_ARG=' "$GEMINI_LOOP" 2>/dev/null; then
        pass "gemini-loop parses SKILLS_ARG"
    else
        fail "gemini-loop does not parse SKILLS_ARG"
    fi
}

test_gemini_loop_injects_skills_function() {
    if grep -q 'inject_skills' "$GEMINI_LOOP" 2>/dev/null; then
        pass "gemini-loop has inject_skills function"
    else
        fail "gemini-loop missing inject_skills function"
    fi
}

# ============================================================================
# Tests: AGENTS.md skill injection
# ============================================================================

test_nexus_loop_uses_xroads_skill_marker() {
    if grep -q 'XRoads Skills.*Auto-Injected' "$NEXUS_LOOP" 2>/dev/null; then
        pass "nexus-loop uses XRoads Skills marker in AGENTS.md"
    else
        fail "nexus-loop missing XRoads Skills marker"
    fi
}

test_codex_loop_uses_xroads_skill_marker() {
    if grep -q 'XRoads Skills.*Auto-Injected' "$CODEX_LOOP" 2>/dev/null; then
        pass "codex-loop uses XRoads Skills marker in AGENTS.md"
    else
        fail "codex-loop missing XRoads Skills marker"
    fi
}

test_gemini_loop_uses_xroads_skill_marker() {
    if grep -q 'XRoads Skills.*Auto-Injected' "$GEMINI_LOOP" 2>/dev/null; then
        pass "gemini-loop uses XRoads Skills marker in AGENTS.md"
    else
        fail "gemini-loop missing XRoads Skills marker"
    fi
}

# ============================================================================
# Tests: CLI-format specific loading
# ============================================================================

test_nexus_loop_uses_claude_cli() {
    if grep -q 'cli.*claude\|--cli.*claude' "$NEXUS_LOOP" 2>/dev/null; then
        pass "nexus-loop uses Claude CLI format"
    else
        fail "nexus-loop does not specify Claude CLI format"
    fi
}

test_codex_loop_uses_codex_cli() {
    if grep -q 'cli.*codex\|--cli.*codex' "$CODEX_LOOP" 2>/dev/null; then
        pass "codex-loop uses Codex CLI format"
    else
        fail "codex-loop does not specify Codex CLI format"
    fi
}

test_gemini_loop_uses_gemini_cli() {
    if grep -q 'cli.*gemini\|--cli.*gemini' "$GEMINI_LOOP" 2>/dev/null; then
        pass "gemini-loop uses Gemini CLI format"
    else
        fail "gemini-loop does not specify Gemini CLI format"
    fi
}

# ============================================================================
# Tests: skill-loader integration
# ============================================================================

test_skill_loader_exists() {
    if [[ -f "$SKILL_LOADER" ]]; then
        pass "skill-loader.sh exists"
    else
        fail "skill-loader.sh not found at $SKILL_LOADER"
    fi
}

test_skill_loader_executable() {
    if [[ -x "$SKILL_LOADER" ]]; then
        pass "skill-loader.sh is executable"
    else
        fail "skill-loader.sh is not executable"
    fi
}

test_skill_loader_supports_skills_argument() {
    if grep -q '\-\-skills' "$SKILL_LOADER" 2>/dev/null; then
        pass "skill-loader.sh supports --skills argument"
    else
        fail "skill-loader.sh missing --skills argument support"
    fi
}

test_skill_loader_claude_format() {
    if [[ ! -x "$SKILL_LOADER" ]]; then
        skip "skill-loader.sh not available"
        return
    fi

    local output
    output=$("$SKILL_LOADER" --cli claude --skills commit 2>&1) || true

    # Claude format should have slash commands or specific markers
    if [[ -n "$output" ]] && ! echo "$output" | grep -qi "error"; then
        pass "skill-loader.sh returns content for Claude CLI"
    else
        fail "skill-loader.sh fails for Claude CLI" "$output"
    fi
}

test_skill_loader_gemini_format() {
    if [[ ! -x "$SKILL_LOADER" ]]; then
        skip "skill-loader.sh not available"
        return
    fi

    local output
    output=$("$SKILL_LOADER" --cli gemini --skills commit 2>&1) || true

    if [[ -n "$output" ]] && ! echo "$output" | grep -qi "error"; then
        pass "skill-loader.sh returns content for Gemini CLI"
    else
        fail "skill-loader.sh fails for Gemini CLI" "$output"
    fi
}

test_skill_loader_codex_format() {
    if [[ ! -x "$SKILL_LOADER" ]]; then
        skip "skill-loader.sh not available"
        return
    fi

    local output
    output=$("$SKILL_LOADER" --cli codex --skills commit 2>&1) || true

    if [[ -n "$output" ]] && ! echo "$output" | grep -qi "error"; then
        pass "skill-loader.sh returns content for Codex CLI"
    else
        fail "skill-loader.sh fails for Codex CLI" "$output"
    fi
}

# ============================================================================
# Tests: Multiple skills loading
# ============================================================================

test_skill_loader_multiple_skills() {
    if [[ ! -x "$SKILL_LOADER" ]]; then
        skip "skill-loader.sh not available"
        return
    fi

    local output
    output=$("$SKILL_LOADER" --cli claude --skills commit,prd 2>&1) || true

    # Should load multiple skills
    if [[ -n "$output" ]] && ! echo "$output" | grep -qi "error"; then
        pass "skill-loader.sh loads multiple skills (commit,prd)"
    else
        fail "skill-loader.sh fails with multiple skills" "$output"
    fi
}

# ============================================================================
# Tests: Default core skills
# ============================================================================

test_nexus_loop_loads_default_skills() {
    # Check that inject_skills is called even without explicit --skills
    if grep -q 'inject_skills.*SKILLS_ARG' "$NEXUS_LOOP" 2>/dev/null; then
        pass "nexus-loop calls inject_skills with SKILLS_ARG (defaults to core)"
    else
        fail "nexus-loop does not call inject_skills properly"
    fi
}

test_codex_loop_loads_default_skills() {
    if grep -q 'inject_skills.*SKILLS_ARG' "$CODEX_LOOP" 2>/dev/null; then
        pass "codex-loop calls inject_skills with SKILLS_ARG (defaults to core)"
    else
        fail "codex-loop does not call inject_skills properly"
    fi
}

test_gemini_loop_loads_default_skills() {
    if grep -q 'inject_skills.*SKILLS_ARG' "$GEMINI_LOOP" 2>/dev/null; then
        pass "gemini-loop calls inject_skills with SKILLS_ARG (defaults to core)"
    else
        fail "gemini-loop does not call inject_skills properly"
    fi
}

# ============================================================================
# Tests: Skills section management in AGENTS.md
# ============================================================================

test_nexus_loop_removes_old_skills_section() {
    # Check that old skills section is removed before adding new
    if grep -q 'sed.*skills_marker\|skills_end_marker' "$NEXUS_LOOP" 2>/dev/null; then
        pass "nexus-loop removes old skills section before injecting new"
    else
        fail "nexus-loop may not remove old skills section"
    fi
}

test_codex_loop_removes_old_skills_section() {
    if grep -q 'sed.*skills_marker\|skills_end_marker' "$CODEX_LOOP" 2>/dev/null; then
        pass "codex-loop removes old skills section before injecting new"
    else
        fail "codex-loop may not remove old skills section"
    fi
}

test_gemini_loop_removes_old_skills_section() {
    if grep -q 'sed.*skills_marker\|skills_end_marker' "$GEMINI_LOOP" 2>/dev/null; then
        pass "gemini-loop removes old skills section before injecting new"
    else
        fail "gemini-loop may not remove old skills section"
    fi
}

# ============================================================================
# Tests: End marker for skills section
# ============================================================================

test_nexus_loop_has_end_marker() {
    if grep -q 'End XRoads Skills' "$NEXUS_LOOP" 2>/dev/null; then
        pass "nexus-loop has End XRoads Skills marker"
    else
        fail "nexus-loop missing End XRoads Skills marker"
    fi
}

test_codex_loop_has_end_marker() {
    if grep -q 'End XRoads Skills' "$CODEX_LOOP" 2>/dev/null; then
        pass "codex-loop has End XRoads Skills marker"
    else
        fail "codex-loop missing End XRoads Skills marker"
    fi
}

test_gemini_loop_has_end_marker() {
    if grep -q 'End XRoads Skills' "$GEMINI_LOOP" 2>/dev/null; then
        pass "gemini-loop has End XRoads Skills marker"
    else
        fail "gemini-loop missing End XRoads Skills marker"
    fi
}

# ============================================================================
# Test Runner
# ============================================================================

run_tests() {
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  Loop Skill Injection Unit Tests${NC}"
    echo -e "${BLUE}  US-V4-007${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""

    echo -e "${BLUE}--- nexus-loop --skills flag ---${NC}"
    test_nexus_loop_has_skills_flag
    test_nexus_loop_help_shows_skills
    test_nexus_loop_parses_skills_argument
    test_nexus_loop_injects_skills_function
    echo ""

    echo -e "${BLUE}--- codex-loop --skills flag ---${NC}"
    test_codex_loop_has_skills_flag
    test_codex_loop_help_shows_skills
    test_codex_loop_parses_skills_argument
    test_codex_loop_injects_skills_function
    echo ""

    echo -e "${BLUE}--- gemini-loop --skills flag ---${NC}"
    test_gemini_loop_has_skills_flag
    test_gemini_loop_help_shows_skills
    test_gemini_loop_parses_skills_argument
    test_gemini_loop_injects_skills_function
    echo ""

    echo -e "${BLUE}--- AGENTS.md skill injection ---${NC}"
    test_nexus_loop_uses_xroads_skill_marker
    test_codex_loop_uses_xroads_skill_marker
    test_gemini_loop_uses_xroads_skill_marker
    echo ""

    echo -e "${BLUE}--- CLI-format specific loading ---${NC}"
    test_nexus_loop_uses_claude_cli
    test_codex_loop_uses_codex_cli
    test_gemini_loop_uses_gemini_cli
    echo ""

    echo -e "${BLUE}--- skill-loader.sh integration ---${NC}"
    test_skill_loader_exists
    test_skill_loader_executable
    test_skill_loader_supports_skills_argument
    test_skill_loader_claude_format
    test_skill_loader_gemini_format
    test_skill_loader_codex_format
    test_skill_loader_multiple_skills
    echo ""

    echo -e "${BLUE}--- Default core skills loading ---${NC}"
    test_nexus_loop_loads_default_skills
    test_codex_loop_loads_default_skills
    test_gemini_loop_loads_default_skills
    echo ""

    echo -e "${BLUE}--- Skills section management ---${NC}"
    test_nexus_loop_removes_old_skills_section
    test_codex_loop_removes_old_skills_section
    test_gemini_loop_removes_old_skills_section
    test_nexus_loop_has_end_marker
    test_codex_loop_has_end_marker
    test_gemini_loop_has_end_marker
    echo ""

    # Summary
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
