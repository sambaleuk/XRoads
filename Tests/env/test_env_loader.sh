#!/usr/bin/env bash
# test_env_loader.sh - Unit tests for env-loader.sh
#
# Tests secure environment variable loading, validation, and credential masking

set -euo pipefail

# ============================================================================
# Test Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_LOADER="${HOME}/.xroads/lib/env-loader.sh"
ENV_TEMPLATE="${HOME}/.xroads/.env.template"
XROADS_ENV="${HOME}/.xroads/.env"

# Test directories (will be cleaned up)
TEST_DIR=""
TEST_PROJECT_DIR=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Test Helpers
# ============================================================================

setup() {
    # Create temp test directories
    TEST_DIR=$(mktemp -d)
    TEST_PROJECT_DIR="$TEST_DIR/test-project"
    mkdir -p "$TEST_PROJECT_DIR"
    mkdir -p "$TEST_PROJECT_DIR/.xroads"

    # Backup existing ~/.xroads/.env if it exists
    if [[ -f "$XROADS_ENV" ]]; then
        cp "$XROADS_ENV" "${XROADS_ENV}.bak"
    fi
}

teardown() {
    # Remove test directories
    if [[ -n "$TEST_DIR" ]] && [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi

    # Restore original ~/.xroads/.env
    if [[ -f "${XROADS_ENV}.bak" ]]; then
        mv "${XROADS_ENV}.bak" "$XROADS_ENV"
    else
        # Remove test .env if we created one
        rm -f "$XROADS_ENV"
    fi
}

trap teardown EXIT

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String not found}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Looking for: '$needle'"
        echo "  In: '$haystack'"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not be found}"

    if [[ "$haystack" != *"$needle"* ]]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Should NOT contain: '$needle'"
        echo "  But found in: '$haystack'"
        return 1
    fi
}

assert_success() {
    local exit_code="$1"
    local message="${2:-Command should succeed}"

    if [[ "$exit_code" -eq 0 ]]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message (exit code: $exit_code)"
        return 1
    fi
}

assert_failure() {
    local exit_code="$1"
    local message="${2:-Command should fail}"

    if [[ "$exit_code" -ne 0 ]]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message (expected non-zero exit code)"
        return 1
    fi
}

run_test() {
    local test_name="$1"
    local test_func="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  Testing: $test_name ... "

    # Run setup for each test
    setup

    # Run the test
    set +e
    local output
    output=$($test_func 2>&1)
    local result=$?
    set -e

    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}"
        echo "$output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Run teardown for each test
    teardown
}

# ============================================================================
# Test Cases: Script Existence and Basic Functionality
# ============================================================================

test_script_exists() {
    [[ -f "$ENV_LOADER" ]] || { echo "Script not found: $ENV_LOADER"; return 1; }
}

test_script_executable() {
    [[ -x "$ENV_LOADER" ]] || { echo "Script not executable: $ENV_LOADER"; return 1; }
}

test_template_exists() {
    [[ -f "$ENV_TEMPLATE" ]] || { echo "Template not found: $ENV_TEMPLATE"; return 1; }
}

test_help_shows_usage() {
    local output
    output=$("$ENV_LOADER" --help 2>&1)
    assert_contains "$output" "USAGE:" "Help should show usage"
    assert_contains "$output" "--get" "Help should mention --get"
    assert_contains "$output" "--validate" "Help should mention --validate"
    assert_contains "$output" "--export" "Help should mention --export"
}

# ============================================================================
# Test Cases: Loading Priority
# ============================================================================

test_loads_project_env_first() {
    # Create project .env
    echo "TEST_VAR=project_value" > "$TEST_PROJECT_DIR/.env"

    local output
    output=$("$ENV_LOADER" --get TEST_VAR --project-dir "$TEST_PROJECT_DIR" 2>&1)
    assert_equals "project_value" "$output" "Should load from project .env"
}

test_fallback_to_xroads_env() {
    # Create only ~/.xroads/.env
    echo "GLOBAL_VAR=global_value" > "$XROADS_ENV"

    local output
    output=$("$ENV_LOADER" --get GLOBAL_VAR --project-dir "$TEST_PROJECT_DIR" 2>&1)
    assert_equals "global_value" "$output" "Should fallback to ~/.xroads/.env"
}

test_project_env_overrides_global() {
    # Create both
    echo "OVERRIDE_VAR=global_value" > "$XROADS_ENV"
    echo "OVERRIDE_VAR=project_value" > "$TEST_PROJECT_DIR/.env"

    local output
    output=$("$ENV_LOADER" --get OVERRIDE_VAR --project-dir "$TEST_PROJECT_DIR" 2>&1)
    assert_equals "project_value" "$output" "Project .env should override global"
}

test_env_local_overrides_project() {
    # Create both .env and .env.local
    echo "LOCAL_VAR=base_value" > "$TEST_PROJECT_DIR/.env"
    echo "LOCAL_VAR=local_value" > "$TEST_PROJECT_DIR/.env.local"

    local output
    output=$("$ENV_LOADER" --get LOCAL_VAR --project-dir "$TEST_PROJECT_DIR" 2>&1)
    assert_equals "local_value" "$output" ".env.local should override .env"
}

test_project_json_overrides_all() {
    # Create .env and project.json
    echo "SUPABASE_PROJECT_URL=env_value" > "$TEST_PROJECT_DIR/.env"
    cat > "$TEST_PROJECT_DIR/.xroads/project.json" << 'EOF'
{
    "supabase": {
        "project_url": "json_value"
    }
}
EOF

    local output
    output=$("$ENV_LOADER" --get SUPABASE_PROJECT_URL --project-dir "$TEST_PROJECT_DIR" 2>&1)
    assert_equals "json_value" "$output" "project.json should override .env"
}

# ============================================================================
# Test Cases: Validation
# ============================================================================

test_validate_existing_vars() {
    echo "VAR_A=value_a" > "$TEST_PROJECT_DIR/.env"
    echo "VAR_B=value_b" >> "$TEST_PROJECT_DIR/.env"

    set +e
    "$ENV_LOADER" --validate "VAR_A,VAR_B" --project-dir "$TEST_PROJECT_DIR" --quiet >/dev/null 2>&1
    local result=$?
    set -e

    assert_success "$result" "Should validate existing vars"
}

test_validate_missing_vars_fails() {
    echo "VAR_A=value_a" > "$TEST_PROJECT_DIR/.env"

    set +e
    "$ENV_LOADER" --validate "VAR_A,VAR_MISSING" --project-dir "$TEST_PROJECT_DIR" --quiet >/dev/null 2>&1
    local result=$?
    set -e

    assert_failure "$result" "Should fail when required vars missing"
}

test_validate_empty_vars_fails() {
    echo "VAR_EMPTY=" > "$TEST_PROJECT_DIR/.env"

    set +e
    "$ENV_LOADER" --validate "VAR_EMPTY" --project-dir "$TEST_PROJECT_DIR" --quiet >/dev/null 2>&1
    local result=$?
    set -e

    assert_failure "$result" "Should fail when required vars empty"
}

test_validate_shows_error_message() {
    echo "VAR_A=value_a" > "$TEST_PROJECT_DIR/.env"

    set +e
    local output
    output=$("$ENV_LOADER" --validate "VAR_A,MISSING_VAR" --project-dir "$TEST_PROJECT_DIR" 2>&1)
    set -e

    assert_contains "$output" "MISSING_VAR" "Should show missing var name"
    assert_contains "$output" "Missing" "Should indicate missing"
}

# ============================================================================
# Test Cases: Security (Credential Masking)
# ============================================================================

test_masks_api_key() {
    echo "OPENAI_API_KEY=sk-1234567890abcdef" > "$TEST_PROJECT_DIR/.env"

    local output
    output=$("$ENV_LOADER" --list --project-dir "$TEST_PROJECT_DIR" 2>&1)

    # Should NOT contain the full key
    assert_not_contains "$output" "sk-1234567890abcdef" "Should not show full API key"
    # Should contain masked version or (sensitive) marker
    assert_contains "$output" "sensitive" "Should mark as sensitive"
}

test_masks_secret_key() {
    echo "SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.secret" > "$TEST_PROJECT_DIR/.env"

    local output
    output=$("$ENV_LOADER" --list --project-dir "$TEST_PROJECT_DIR" 2>&1)

    # Should NOT contain the full secret
    assert_not_contains "$output" "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.secret" "Should not show full secret"
}

test_masks_token() {
    echo "GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > "$TEST_PROJECT_DIR/.env"

    local output
    output=$("$ENV_LOADER" --list --project-dir "$TEST_PROJECT_DIR" 2>&1)

    # Should NOT contain the full token
    assert_not_contains "$output" "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" "Should not show full token"
}

test_does_not_mask_non_sensitive() {
    echo "XROADS_LOG_LEVEL=debug" > "$TEST_PROJECT_DIR/.env"

    local output
    output=$("$ENV_LOADER" --list --project-dir "$TEST_PROJECT_DIR" 2>&1)

    # Should contain the full value (not masked)
    assert_contains "$output" "debug" "Should show non-sensitive value"
}

# ============================================================================
# Test Cases: Export
# ============================================================================

test_export_format() {
    echo "VAR_A=value_a" > "$TEST_PROJECT_DIR/.env"
    echo "VAR_B=value with spaces" >> "$TEST_PROJECT_DIR/.env"

    local output
    output=$("$ENV_LOADER" --export --project-dir "$TEST_PROJECT_DIR" 2>&1)

    assert_contains "$output" "export VAR_A=" "Should have export command"
    assert_contains "$output" "export VAR_B=" "Should export VAR_B"
}

test_export_escapes_special_chars() {
    echo 'VAR_SPECIAL=value$with"special'\''chars' > "$TEST_PROJECT_DIR/.env"

    local output
    output=$("$ENV_LOADER" --export --project-dir "$TEST_PROJECT_DIR" 2>&1)

    # Should produce valid shell export
    assert_contains "$output" "export VAR_SPECIAL=" "Should have export command"
}

# ============================================================================
# Test Cases: Get Single Variable
# ============================================================================

test_get_existing_var() {
    echo "MY_VAR=my_value" > "$TEST_PROJECT_DIR/.env"

    local output
    output=$("$ENV_LOADER" --get MY_VAR --project-dir "$TEST_PROJECT_DIR" 2>&1)
    assert_equals "my_value" "$output" "Should get exact value"
}

test_get_nonexistent_var_empty() {
    echo "OTHER_VAR=value" > "$TEST_PROJECT_DIR/.env"

    local output
    output=$("$ENV_LOADER" --get NONEXISTENT --project-dir "$TEST_PROJECT_DIR" 2>&1)
    assert_equals "" "$output" "Should return empty for nonexistent var"
}

test_get_var_with_equals_in_value() {
    echo "URL_VAR=https://example.com?foo=bar&baz=qux" > "$TEST_PROJECT_DIR/.env"

    local output
    output=$("$ENV_LOADER" --get URL_VAR --project-dir "$TEST_PROJECT_DIR" 2>&1)
    assert_equals "https://example.com?foo=bar&baz=qux" "$output" "Should handle = in value"
}

# ============================================================================
# Test Cases: .env File Parsing
# ============================================================================

test_skips_comments() {
    cat > "$TEST_PROJECT_DIR/.env" << 'EOF'
# This is a comment
VAR_A=value_a
# Another comment
VAR_B=value_b
EOF

    local output_a output_b
    output_a=$("$ENV_LOADER" --get VAR_A --project-dir "$TEST_PROJECT_DIR" 2>&1)
    output_b=$("$ENV_LOADER" --get VAR_B --project-dir "$TEST_PROJECT_DIR" 2>&1)

    assert_equals "value_a" "$output_a" "Should parse VAR_A"
    assert_equals "value_b" "$output_b" "Should parse VAR_B"
}

test_skips_empty_lines() {
    cat > "$TEST_PROJECT_DIR/.env" << 'EOF'
VAR_A=value_a

VAR_B=value_b

EOF

    local output_b
    output_b=$("$ENV_LOADER" --get VAR_B --project-dir "$TEST_PROJECT_DIR" 2>&1)
    assert_equals "value_b" "$output_b" "Should handle empty lines"
}

test_removes_quotes() {
    cat > "$TEST_PROJECT_DIR/.env" << 'EOF'
DOUBLE_QUOTED="value with spaces"
SINGLE_QUOTED='another value'
EOF

    local output_double output_single
    output_double=$("$ENV_LOADER" --get DOUBLE_QUOTED --project-dir "$TEST_PROJECT_DIR" 2>&1)
    output_single=$("$ENV_LOADER" --get SINGLE_QUOTED --project-dir "$TEST_PROJECT_DIR" 2>&1)

    assert_equals "value with spaces" "$output_double" "Should remove double quotes"
    assert_equals "another value" "$output_single" "Should remove single quotes"
}

# ============================================================================
# Test Cases: Sources Display
# ============================================================================

test_sources_shows_loaded_files() {
    echo "VAR_A=a" > "$XROADS_ENV"
    echo "VAR_B=b" > "$TEST_PROJECT_DIR/.env"
    echo "VAR_C=c" > "$TEST_PROJECT_DIR/.env.local"

    local output
    output=$("$ENV_LOADER" --sources --project-dir "$TEST_PROJECT_DIR" 2>&1)

    assert_contains "$output" ".xroads/.env" "Should show global env source"
    assert_contains "$output" ".env" "Should show project env source"
    assert_contains "$output" ".env.local" "Should show local env source"
}

# ============================================================================
# Test Cases: Template Content
# ============================================================================

test_template_has_supabase_vars() {
    local content
    content=$(cat "$ENV_TEMPLATE")

    assert_contains "$content" "SUPABASE_PROJECT_URL" "Template should have Supabase URL"
    assert_contains "$content" "SUPABASE_SERVICE_KEY" "Template should have Supabase key"
    assert_contains "$content" "SUPABASE_ANON_KEY" "Template should have Supabase anon key"
}

test_template_has_security_notes() {
    local content
    content=$(cat "$ENV_TEMPLATE")

    assert_contains "$content" "NEVER commit" "Template should warn about commits"
    assert_contains "$content" "NEVER logged" "Template should mention never logged"
}

test_template_documents_priority() {
    local content
    content=$(cat "$ENV_TEMPLATE")

    assert_contains "$content" "LOADING PRIORITY" "Template should document loading priority"
    assert_contains "$content" ".env.local" "Template should mention .env.local"
}

# ============================================================================
# Main Test Runner
# ============================================================================

echo "======================================"
echo "env-loader.sh Unit Tests"
echo "======================================"
echo ""

# Script and Template Tests
echo "Script & Template Tests:"
run_test "script exists" test_script_exists
run_test "script is executable" test_script_executable
run_test "template exists" test_template_exists
run_test "help shows usage" test_help_shows_usage

echo ""
echo "Loading Priority Tests:"
run_test "loads project .env first" test_loads_project_env_first
run_test "falls back to ~/.xroads/.env" test_fallback_to_xroads_env
run_test "project .env overrides global" test_project_env_overrides_global
run_test ".env.local overrides .env" test_env_local_overrides_project
run_test "project.json overrides all env files" test_project_json_overrides_all

echo ""
echo "Validation Tests:"
run_test "validates existing vars" test_validate_existing_vars
run_test "fails when required vars missing" test_validate_missing_vars_fails
run_test "fails when required vars empty" test_validate_empty_vars_fails
run_test "shows missing var name in error" test_validate_shows_error_message

echo ""
echo "Security (Masking) Tests:"
run_test "masks API key in list output" test_masks_api_key
run_test "masks secret key in list output" test_masks_secret_key
run_test "masks token in list output" test_masks_token
run_test "does not mask non-sensitive values" test_does_not_mask_non_sensitive

echo ""
echo "Export Tests:"
run_test "export format is correct" test_export_format
run_test "export escapes special chars" test_export_escapes_special_chars

echo ""
echo "Get Variable Tests:"
run_test "gets existing variable" test_get_existing_var
run_test "returns empty for nonexistent var" test_get_nonexistent_var_empty
run_test "handles = in value" test_get_var_with_equals_in_value

echo ""
echo ".env Parsing Tests:"
run_test "skips comments" test_skips_comments
run_test "skips empty lines" test_skips_empty_lines
run_test "removes quotes from values" test_removes_quotes

echo ""
echo "Sources Display Tests:"
run_test "shows loaded files" test_sources_shows_loaded_files

echo ""
echo "Template Content Tests:"
run_test "template has Supabase vars" test_template_has_supabase_vars
run_test "template has security notes" test_template_has_security_notes
run_test "template documents loading priority" test_template_documents_priority

echo ""
echo "======================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}$TESTS_FAILED tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
