#!/usr/bin/env bash
# test_mcp_loader.sh - Unit tests for mcp-loader.sh
# Tests MCP configuration loading and dynamic injection
#
# Usage: ./tests/mcp/test_mcp_loader.sh

set -euo pipefail

# Test configuration
MCP_LOADER="${HOME}/.xroads/lib/mcp-loader.sh"
MCP_DIR="${HOME}/.xroads/mcp"
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
# Script Existence Tests
# ============================================================================

test_mcp_loader_exists() {
    if [[ -f "$MCP_LOADER" ]]; then
        pass "mcp-loader.sh exists"
    else
        fail "mcp-loader.sh exists" "File not found: $MCP_LOADER"
    fi
}

test_mcp_loader_executable() {
    if [[ -x "$MCP_LOADER" ]]; then
        pass "mcp-loader.sh is executable"
    else
        fail "mcp-loader.sh is executable" "File is not executable"
    fi
}

test_mcp_loader_help() {
    local output
    output=$("$MCP_LOADER" --help 2>&1) || true
    if echo "$output" | grep -q "USAGE"; then
        pass "mcp-loader.sh --help shows usage"
    else
        fail "mcp-loader.sh --help shows usage" "No USAGE found in output"
    fi
}

# ============================================================================
# MCP Config File Tests
# ============================================================================

test_mcp_dir_exists() {
    if [[ -d "$MCP_DIR" ]]; then
        pass "MCP config directory exists"
    else
        fail "MCP config directory exists" "Directory not found: $MCP_DIR"
    fi
}

test_xroads_config_exists() {
    if [[ -f "$MCP_DIR/xroads.json" ]]; then
        pass "xroads.json config exists"
    else
        fail "xroads.json config exists" "File not found"
    fi
}

test_agent_browser_config_exists() {
    if [[ -f "$MCP_DIR/agent-browser.json" ]]; then
        pass "agent-browser.json config exists"
    else
        fail "agent-browser.json config exists" "File not found"
    fi
}

test_supabase_template_exists() {
    if [[ -f "$MCP_DIR/supabase.template.json" ]]; then
        pass "supabase.template.json config exists"
    else
        fail "supabase.template.json config exists" "File not found"
    fi
}

# ============================================================================
# JSON Validity Tests
# ============================================================================

test_xroads_config_valid_json() {
    if ruby -rjson -e 'JSON.parse(File.read(ARGV[0]))' "$MCP_DIR/xroads.json" 2>/dev/null; then
        pass "xroads.json is valid JSON"
    else
        fail "xroads.json is valid JSON" "JSON parse error"
    fi
}

test_agent_browser_config_valid_json() {
    if ruby -rjson -e 'JSON.parse(File.read(ARGV[0]))' "$MCP_DIR/agent-browser.json" 2>/dev/null; then
        pass "agent-browser.json is valid JSON"
    else
        fail "agent-browser.json is valid JSON" "JSON parse error"
    fi
}

test_supabase_template_valid_json() {
    if ruby -rjson -e 'JSON.parse(File.read(ARGV[0]))' "$MCP_DIR/supabase.template.json" 2>/dev/null; then
        pass "supabase.template.json is valid JSON"
    else
        fail "supabase.template.json is valid JSON" "JSON parse error"
    fi
}

# ============================================================================
# MCP Loader Functionality Tests
# ============================================================================

test_mcp_list() {
    local output
    output=$("$MCP_LOADER" --list 2>&1) || true
    if echo "$output" | grep -q "xroads"; then
        pass "mcp-loader.sh --list shows xroads"
    else
        fail "mcp-loader.sh --list shows xroads" "xroads not found in list"
    fi
}

test_mcp_list_json() {
    local output
    output=$("$MCP_LOADER" --list --json 2>/dev/null) || true
    if ruby -rjson -e 'JSON.parse(STDIN.read)' <<< "$output" 2>/dev/null; then
        pass "mcp-loader.sh --list --json returns valid JSON"
    else
        fail "mcp-loader.sh --list --json returns valid JSON" "Invalid JSON output"
    fi
}

test_mcp_get_xroads() {
    local output
    output=$("$MCP_LOADER" --mcp xroads 2>/dev/null) || true
    if echo "$output" | grep -q '"id": "xroads"'; then
        pass "mcp-loader.sh --mcp xroads returns xroads config"
    else
        fail "mcp-loader.sh --mcp xroads returns xroads config" "xroads id not found"
    fi
}

test_mcp_get_xroads_inject() {
    local output
    output=$("$MCP_LOADER" --mcp xroads --inject 2>/dev/null) || true
    # After injection, XROADS_MCP_PATH placeholder should be resolved
    if echo "$output" | grep -q "index.js"; then
        pass "mcp-loader.sh --mcp xroads --inject resolves path"
    else
        fail "mcp-loader.sh --mcp xroads --inject resolves path" "Path not resolved"
    fi
}

test_mcp_get_supabase_inject_url() {
    local output
    output=$("$MCP_LOADER" --mcp supabase --inject --project-url "https://test.supabase.co" 2>/dev/null) || true
    if echo "$output" | grep -q "https://test.supabase.co"; then
        pass "mcp-loader.sh --mcp supabase --project-url injects URL"
    else
        fail "mcp-loader.sh --mcp supabase --project-url injects URL" "URL not injected"
    fi
}

test_mcp_invalid_returns_error() {
    local output
    local exit_code=0
    output=$("$MCP_LOADER" --mcp nonexistent 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -q "not found"; then
        pass "mcp-loader.sh --mcp nonexistent returns error"
    else
        fail "mcp-loader.sh --mcp nonexistent returns error" "No error for invalid MCP"
    fi
}

# ============================================================================
# Detection Tests
# ============================================================================

test_mcp_detect_always_xroads() {
    local output
    output=$("$MCP_LOADER" --detect --project-dir "$TEST_DIR" 2>&1) || true
    if echo "$output" | grep -q "xroads"; then
        pass "mcp-loader.sh --detect always includes xroads"
    else
        fail "mcp-loader.sh --detect always includes xroads" "xroads not detected"
    fi
}

test_mcp_detect_supabase_dir() {
    # Create .supabase directory
    mkdir -p "$TEST_DIR/.supabase"
    local output
    output=$("$MCP_LOADER" --detect --project-dir "$TEST_DIR" 2>&1) || true
    if echo "$output" | grep -q "supabase"; then
        pass "mcp-loader.sh detects .supabase/ and suggests supabase MCP"
    else
        fail "mcp-loader.sh detects .supabase/ and suggests supabase MCP" "supabase not detected"
    fi
}

test_mcp_detect_e2e_dir() {
    # Create e2e directory
    mkdir -p "$TEST_DIR/e2e"
    local output
    output=$("$MCP_LOADER" --detect --project-dir "$TEST_DIR" 2>&1) || true
    if echo "$output" | grep -q "agent-browser"; then
        pass "mcp-loader.sh detects e2e/ and suggests agent-browser MCP"
    else
        fail "mcp-loader.sh detects e2e/ and suggests agent-browser MCP" "agent-browser not detected"
    fi
}

test_mcp_detect_json_output() {
    mkdir -p "$TEST_DIR/.supabase"
    local output
    output=$("$MCP_LOADER" --detect --project-dir "$TEST_DIR" --json 2>/dev/null) || true
    if ruby -rjson -e 'j=JSON.parse(STDIN.read); exit(j["detected"].any?{|d| d["mcp"]=="supabase"} ? 0 : 1)' <<< "$output" 2>/dev/null; then
        pass "mcp-loader.sh --detect --json returns structured output"
    else
        fail "mcp-loader.sh --detect --json returns structured output" "Invalid JSON or missing supabase"
    fi
}

# ============================================================================
# Config Content Tests
# ============================================================================

test_xroads_config_has_required_fields() {
    local has_all=true
    for field in "id" "name" "command" "args" "capabilities"; do
        if ! ruby -rjson -e "j=JSON.parse(File.read(ARGV[0])); exit(j.key?('$field') ? 0 : 1)" "$MCP_DIR/xroads.json" 2>/dev/null; then
            has_all=false
            break
        fi
    done
    if [[ "$has_all" == "true" ]]; then
        pass "xroads.json has required fields (id, name, command, args, capabilities)"
    else
        fail "xroads.json has required fields" "Missing required field"
    fi
}

test_xroads_config_always_loaded() {
    if ruby -rjson -e 'j=JSON.parse(File.read(ARGV[0])); exit(j["always_loaded"]==true ? 0 : 1)' "$MCP_DIR/xroads.json" 2>/dev/null; then
        pass "xroads.json has always_loaded=true"
    else
        fail "xroads.json has always_loaded=true" "always_loaded is not true"
    fi
}

test_supabase_config_has_env_vars() {
    if ruby -rjson -e 'j=JSON.parse(File.read(ARGV[0])); exit(j["required_env_vars"].include?("SUPABASE_PROJECT_URL") ? 0 : 1)' "$MCP_DIR/supabase.template.json" 2>/dev/null; then
        pass "supabase.template.json requires SUPABASE_PROJECT_URL"
    else
        fail "supabase.template.json requires SUPABASE_PROJECT_URL" "Missing required env var"
    fi
}

test_agent_browser_config_has_capabilities() {
    if ruby -rjson -e 'j=JSON.parse(File.read(ARGV[0])); exit(j["capabilities"].include?("browser_control") ? 0 : 1)' "$MCP_DIR/agent-browser.json" 2>/dev/null; then
        pass "agent-browser.json has browser_control capability"
    else
        fail "agent-browser.json has browser_control capability" "Missing capability"
    fi
}

# ============================================================================
# Environment Injection Tests
# ============================================================================

test_env_injection_from_file() {
    # Create .env file in test dir
    echo "SUPABASE_PROJECT_URL=https://myproject.supabase.co" > "$TEST_DIR/.env"
    echo "SUPABASE_SERVICE_KEY=my-service-key" >> "$TEST_DIR/.env"

    local output
    output=$("$MCP_LOADER" --mcp supabase --inject --project-dir "$TEST_DIR" 2>/dev/null) || true
    if echo "$output" | grep -q "https://myproject.supabase.co"; then
        pass "mcp-loader.sh reads .env file for injection"
    else
        fail "mcp-loader.sh reads .env file for injection" "Env var not injected from .env"
    fi
}

test_env_injection_override() {
    # Create .env file
    echo "SUPABASE_PROJECT_URL=https://default.supabase.co" > "$TEST_DIR/.env"

    local output
    # Command line should override .env
    output=$("$MCP_LOADER" --mcp supabase --inject --project-dir "$TEST_DIR" --project-url "https://override.supabase.co" 2>/dev/null) || true
    if echo "$output" | grep -q "https://override.supabase.co"; then
        pass "mcp-loader.sh command line overrides .env"
    else
        fail "mcp-loader.sh command line overrides .env" "Override not applied"
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

main() {
    echo "========================================"
    echo "MCP Loader Unit Tests"
    echo "========================================"
    echo ""

    setup

    # Run all tests
    echo "--- Script Existence Tests ---"
    test_mcp_loader_exists
    test_mcp_loader_executable
    test_mcp_loader_help

    echo ""
    echo "--- MCP Config File Tests ---"
    test_mcp_dir_exists
    test_xroads_config_exists
    test_agent_browser_config_exists
    test_supabase_template_exists

    echo ""
    echo "--- JSON Validity Tests ---"
    test_xroads_config_valid_json
    test_agent_browser_config_valid_json
    test_supabase_template_valid_json

    echo ""
    echo "--- MCP Loader Functionality Tests ---"
    test_mcp_list
    test_mcp_list_json
    test_mcp_get_xroads
    test_mcp_get_xroads_inject
    test_mcp_get_supabase_inject_url
    test_mcp_invalid_returns_error

    echo ""
    echo "--- Detection Tests ---"
    test_mcp_detect_always_xroads
    test_mcp_detect_supabase_dir
    test_mcp_detect_e2e_dir
    test_mcp_detect_json_output

    echo ""
    echo "--- Config Content Tests ---"
    test_xroads_config_has_required_fields
    test_xroads_config_always_loaded
    test_supabase_config_has_env_vars
    test_agent_browser_config_has_capabilities

    echo ""
    echo "--- Environment Injection Tests ---"
    test_env_injection_from_file
    test_env_injection_override

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
