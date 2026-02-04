#!/usr/bin/env bash
# test_xroads_mcp_integration.sh - Unit tests for xroads-mcp integration in loops
# Tests that all loops properly load xroads-mcp for unified logging
#
# Usage: ./tests/mcp/test_xroads_mcp_integration.sh

set -euo pipefail

# Test configuration
NEXUS_LOOP="${HOME}/bin/nexus-loop"
CODEX_LOOP="${HOME}/bin/codex-loop"
GEMINI_LOOP="${HOME}/bin/gemini-loop"
MCP_LOADER="${HOME}/.xroads/lib/mcp-loader.sh"
MCP_DIR="${HOME}/.xroads/mcp"
SKILLS_DIR="${HOME}/.xroads/skills/core"
TEST_DIR=""
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# ============================================================================
# Test Helpers
# ============================================================================

setup() {
    # Create temp test directory
    TEST_DIR=$(mktemp -d)
}

teardown() {
    # Cleanup temp directory
    [[ -n "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

pass() {
    local test_name="$1"
    echo -e "${GREEN}PASS${NC} $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    local test_name="$1"
    local reason="${2:-}"
    echo -e "${RED}FAIL${NC} $test_name"
    [[ -n "$reason" ]] && echo "      Reason: $reason"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# ============================================================================
# xroads-mcp Configuration Tests
# ============================================================================

test_xroads_mcp_always_loaded_flag() {
    if ruby -rjson -e 'j=JSON.parse(File.read(ARGV[0])); exit(j["always_loaded"]==true ? 0 : 1)' "$MCP_DIR/xroads.json" 2>/dev/null; then
        pass "xroads-mcp is always_loaded by loops"
    else
        fail "xroads-mcp is always_loaded by loops" "always_loaded is not true in xroads.json"
    fi
}

test_xroads_mcp_has_emit_log() {
    if ruby -rjson -e 'j=JSON.parse(File.read(ARGV[0])); exit(j["capabilities"].include?("emit_log") ? 0 : 1)' "$MCP_DIR/xroads.json" 2>/dev/null; then
        pass "xroads-mcp has emit_log capability"
    else
        fail "xroads-mcp has emit_log capability" "emit_log not in capabilities"
    fi
}

test_xroads_mcp_has_update_status() {
    if ruby -rjson -e 'j=JSON.parse(File.read(ARGV[0])); exit(j["capabilities"].include?("update_status") ? 0 : 1)' "$MCP_DIR/xroads.json" 2>/dev/null; then
        pass "xroads-mcp has update_status capability"
    else
        fail "xroads-mcp has update_status capability" "update_status not in capabilities"
    fi
}

# ============================================================================
# xroads-log Skill Tests
# ============================================================================

test_xroads_log_skill_exists() {
    if [[ -f "$SKILLS_DIR/xroads-log.skill.yaml" ]]; then
        pass "xroads-log.skill.yaml exists"
    else
        fail "xroads-log.skill.yaml exists" "File not found"
    fi
}

test_xroads_log_skill_valid_yaml() {
    if ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$SKILLS_DIR/xroads-log.skill.yaml" 2>/dev/null; then
        pass "xroads-log.skill.yaml is valid YAML"
    else
        fail "xroads-log.skill.yaml is valid YAML" "YAML parse error"
    fi
}

test_xroads_log_skill_has_claude_template() {
    if ruby -ryaml -e 'y=YAML.load_file(ARGV[0]); exit(y["templates"]["claude"].to_s.length > 0 ? 0 : 1)' "$SKILLS_DIR/xroads-log.skill.yaml" 2>/dev/null; then
        pass "xroads-log.skill.yaml has Claude template"
    else
        fail "xroads-log.skill.yaml has Claude template" "Missing Claude template"
    fi
}

test_xroads_log_skill_has_gemini_template() {
    if ruby -ryaml -e 'y=YAML.load_file(ARGV[0]); exit(y["templates"]["gemini"].to_s.length > 0 ? 0 : 1)' "$SKILLS_DIR/xroads-log.skill.yaml" 2>/dev/null; then
        pass "xroads-log.skill.yaml has Gemini template"
    else
        fail "xroads-log.skill.yaml has Gemini template" "Missing Gemini template"
    fi
}

test_xroads_log_skill_has_codex_template() {
    if ruby -ryaml -e 'y=YAML.load_file(ARGV[0]); exit(y["templates"]["codex"].to_s.length > 0 ? 0 : 1)' "$SKILLS_DIR/xroads-log.skill.yaml" 2>/dev/null; then
        pass "xroads-log.skill.yaml has Codex template"
    else
        fail "xroads-log.skill.yaml has Codex template" "Missing Codex template"
    fi
}

test_xroads_log_skill_mcp_dependency() {
    if ruby -ryaml -e 'y=YAML.load_file(ARGV[0]); exit(y["mcp_dependencies"].include?("xroads") ? 0 : 1)' "$SKILLS_DIR/xroads-log.skill.yaml" 2>/dev/null; then
        pass "xroads-log.skill.yaml depends on xroads MCP"
    else
        fail "xroads-log.skill.yaml depends on xroads MCP" "Missing xroads dependency"
    fi
}

# ============================================================================
# Loop Integration Tests
# ============================================================================

test_nexus_loop_has_mcp_loader() {
    if grep -q 'MCP_LOADER=' "$NEXUS_LOOP" 2>/dev/null; then
        pass "nexus-loop has MCP_LOADER variable"
    else
        fail "nexus-loop has MCP_LOADER variable" "MCP_LOADER not found in script"
    fi
}

test_nexus_loop_loads_xroads_mcp() {
    if grep -q 'load_xroads_mcp' "$NEXUS_LOOP" 2>/dev/null; then
        pass "nexus-loop calls load_xroads_mcp"
    else
        fail "nexus-loop calls load_xroads_mcp" "load_xroads_mcp function not called"
    fi
}

test_nexus_loop_emits_logs() {
    if grep -q 'emit_xroads_log' "$NEXUS_LOOP" 2>/dev/null; then
        pass "nexus-loop emits logs via emit_xroads_log"
    else
        fail "nexus-loop emits logs via emit_xroads_log" "emit_xroads_log not called"
    fi
}

test_codex_loop_has_mcp_loader() {
    if grep -q 'MCP_LOADER=' "$CODEX_LOOP" 2>/dev/null; then
        pass "codex-loop has MCP_LOADER variable"
    else
        fail "codex-loop has MCP_LOADER variable" "MCP_LOADER not found in script"
    fi
}

test_codex_loop_loads_xroads_mcp() {
    if grep -q 'load_xroads_mcp' "$CODEX_LOOP" 2>/dev/null; then
        pass "codex-loop calls load_xroads_mcp"
    else
        fail "codex-loop calls load_xroads_mcp" "load_xroads_mcp function not called"
    fi
}

test_codex_loop_emits_logs() {
    if grep -q 'emit_xroads_log' "$CODEX_LOOP" 2>/dev/null; then
        pass "codex-loop emits logs via emit_xroads_log"
    else
        fail "codex-loop emits logs via emit_xroads_log" "emit_xroads_log not called"
    fi
}

test_gemini_loop_has_mcp_loader() {
    if grep -q 'MCP_LOADER=' "$GEMINI_LOOP" 2>/dev/null; then
        pass "gemini-loop has MCP_LOADER variable"
    else
        fail "gemini-loop has MCP_LOADER variable" "MCP_LOADER not found in script"
    fi
}

test_gemini_loop_loads_xroads_mcp() {
    if grep -q 'load_xroads_mcp' "$GEMINI_LOOP" 2>/dev/null; then
        pass "gemini-loop calls load_xroads_mcp"
    else
        fail "gemini-loop calls load_xroads_mcp" "load_xroads_mcp function not called"
    fi
}

test_gemini_loop_emits_logs() {
    if grep -q 'emit_xroads_log' "$GEMINI_LOOP" 2>/dev/null; then
        pass "gemini-loop emits logs via emit_xroads_log"
    else
        fail "gemini-loop emits logs via emit_xroads_log" "emit_xroads_log not called"
    fi
}

# ============================================================================
# Loop Help Shows XRoads Integration
# ============================================================================

test_nexus_loop_help_mentions_skills() {
    local output
    output=$("$NEXUS_LOOP" --help 2>&1) || true
    if echo "$output" | grep -q "skills"; then
        pass "nexus-loop --help mentions skills"
    else
        fail "nexus-loop --help mentions skills" "No skills mention in help"
    fi
}

test_codex_loop_help_mentions_skills() {
    local output
    output=$("$CODEX_LOOP" --help 2>&1) || true
    if echo "$output" | grep -q "skills"; then
        pass "codex-loop --help mentions skills"
    else
        fail "codex-loop --help mentions skills" "No skills mention in help"
    fi
}

test_gemini_loop_help_mentions_skills() {
    local output
    output=$("$GEMINI_LOOP" --help 2>&1) || true
    if echo "$output" | grep -q "skills"; then
        pass "gemini-loop --help mentions skills"
    else
        fail "gemini-loop --help mentions skills" "No skills mention in help"
    fi
}

# ============================================================================
# MCP Loader Loads xroads Always
# ============================================================================

test_mcp_loader_detect_includes_xroads() {
    local output
    output=$("$MCP_LOADER" --detect --project-dir "$TEST_DIR" 2>&1) || true
    if echo "$output" | grep -q "xroads"; then
        pass "mcp-loader --detect always includes xroads"
    else
        fail "mcp-loader --detect always includes xroads" "xroads not in detection output"
    fi
}

test_mcp_loader_xroads_is_first_in_detect() {
    local output
    output=$("$MCP_LOADER" --detect --project-dir "$TEST_DIR" --json 2>/dev/null) || true
    if ruby -rjson -e 'j=JSON.parse(STDIN.read); exit(j["detected"][0]["mcp"]=="xroads" ? 0 : 1)' <<< "$output" 2>/dev/null; then
        pass "xroads is first in detection order"
    else
        fail "xroads is first in detection order" "xroads not first in JSON output"
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

main() {
    echo "========================================"
    echo "XRoads MCP Integration Tests"
    echo "========================================"
    echo ""

    setup

    # xroads-mcp Configuration Tests
    echo "--- xroads-mcp Configuration Tests ---"
    test_xroads_mcp_always_loaded_flag
    test_xroads_mcp_has_emit_log
    test_xroads_mcp_has_update_status

    echo ""
    echo "--- xroads-log Skill Tests ---"
    test_xroads_log_skill_exists
    test_xroads_log_skill_valid_yaml
    test_xroads_log_skill_has_claude_template
    test_xroads_log_skill_has_gemini_template
    test_xroads_log_skill_has_codex_template
    test_xroads_log_skill_mcp_dependency

    echo ""
    echo "--- nexus-loop Integration Tests ---"
    test_nexus_loop_has_mcp_loader
    test_nexus_loop_loads_xroads_mcp
    test_nexus_loop_emits_logs
    test_nexus_loop_help_mentions_skills

    echo ""
    echo "--- codex-loop Integration Tests ---"
    test_codex_loop_has_mcp_loader
    test_codex_loop_loads_xroads_mcp
    test_codex_loop_emits_logs
    test_codex_loop_help_mentions_skills

    echo ""
    echo "--- gemini-loop Integration Tests ---"
    test_gemini_loop_has_mcp_loader
    test_gemini_loop_loads_xroads_mcp
    test_gemini_loop_emits_logs
    test_gemini_loop_help_mentions_skills

    echo ""
    echo "--- MCP Loader Detection Tests ---"
    test_mcp_loader_detect_includes_xroads
    test_mcp_loader_xroads_is_first_in_detect

    teardown

    echo ""
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}TESTS FAILED${NC}"
        exit 1
    else
        echo -e "${GREEN}ALL TESTS PASSED${NC}"
        exit 0
    fi
}

main "$@"
