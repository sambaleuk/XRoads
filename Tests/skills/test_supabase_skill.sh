#!/bin/bash
# Unit test for US-V4-009: Supabase Skill
# Verifies the supabase-query.skill.yaml is valid and complete

set -e

SKILL_FILE="$HOME/.xroads/skills/automation/supabase-query.skill.yaml"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_TESTS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    printf "${GREEN}[PASS]${NC} %s\n" "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    printf "${RED}[FAIL]${NC} %s\n" "$1"
}

info() {
    printf "${YELLOW}[INFO]${NC} %s\n" "$1"
}

# Use Ruby for YAML parsing (available on macOS by default)
parse_yaml_field() {
    local file="$1"
    local field="$2"

    ruby -ryaml -e "
        data = YAML.load_file('$file')
        keys = '$field'.split('.')
        value = data
        keys.each do |key|
            break if value.nil?
            value = value[key]
        end
        puts value.nil? ? 'null' : value.to_s
    " 2>/dev/null
}

parse_yaml_array() {
    local file="$1"
    local field="$2"

    ruby -ryaml -e "
        data = YAML.load_file('$file')
        arr = data['$field']
        if arr.nil? || arr.empty?
            puts 'null'
        else
            puts arr.join(',')
        end
    " 2>/dev/null
}

check_yaml_valid() {
    local file="$1"
    local name="$2"

    if ruby -ryaml -e "YAML.load_file('$file')" 2>/dev/null; then
        pass "$name is valid YAML"
        return 0
    else
        fail "$name is NOT valid YAML"
        return 1
    fi
}

# ==========================================
# Test: Skill file exists
# ==========================================
info "Testing skill file existence..."

if [ -f "$SKILL_FILE" ]; then
    pass "supabase-query.skill.yaml exists"
else
    fail "supabase-query.skill.yaml does not exist at $SKILL_FILE"
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total tests: 1"
    printf "${RED}Failed: 1${NC}\n"
    exit 1
fi

# ==========================================
# Test: YAML is valid
# ==========================================
info "Testing YAML validity..."

check_yaml_valid "$SKILL_FILE" "supabase-query.skill.yaml"

# ==========================================
# Test: Required fields exist
# ==========================================
info "Testing required fields..."

REQUIRED_FIELDS=("id" "name" "version" "description" "category")

for field in "${REQUIRED_FIELDS[@]}"; do
    value=$(parse_yaml_field "$SKILL_FILE" "$field")
    if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "None" ]; then
        pass "supabase-query has $field field: $value"
    else
        fail "supabase-query missing $field field"
    fi
done

# ==========================================
# Test: ID matches expected value
# ==========================================
info "Testing skill ID..."

skill_id=$(parse_yaml_field "$SKILL_FILE" "id")
if [ "$skill_id" = "supabase-query" ]; then
    pass "skill id is 'supabase-query'"
else
    fail "skill id is '$skill_id' (expected: supabase-query)"
fi

# ==========================================
# Test: Category is 'automation'
# ==========================================
info "Testing category..."

category=$(parse_yaml_field "$SKILL_FILE" "category")
if [ "$category" = "automation" ]; then
    pass "category is 'automation'"
else
    fail "category is '$category' (expected: automation)"
fi

# ==========================================
# Test: All CLI templates present
# ==========================================
info "Testing CLI templates presence..."

has_claude=$(parse_yaml_field "$SKILL_FILE" "templates.claude")
has_gemini=$(parse_yaml_field "$SKILL_FILE" "templates.gemini")
has_codex=$(parse_yaml_field "$SKILL_FILE" "templates.codex")

if [ -n "$has_claude" ] && [ "$has_claude" != "null" ] && [ "$has_claude" != "None" ]; then
    pass "templates.claude is present"
else
    fail "templates.claude is missing"
fi

if [ -n "$has_gemini" ] && [ "$has_gemini" != "null" ] && [ "$has_gemini" != "None" ]; then
    pass "templates.gemini is present"
else
    fail "templates.gemini is missing"
fi

if [ -n "$has_codex" ] && [ "$has_codex" != "null" ] && [ "$has_codex" != "None" ]; then
    pass "templates.codex is present"
else
    fail "templates.codex is missing"
fi

# ==========================================
# Test: mcp_dependencies includes supabase
# ==========================================
info "Testing mcp_dependencies..."

mcp_deps=$(parse_yaml_array "$SKILL_FILE" "mcp_dependencies")
if echo "$mcp_deps" | grep -q "supabase"; then
    pass "mcp_dependencies includes 'supabase'"
else
    fail "mcp_dependencies does not include 'supabase' (found: $mcp_deps)"
fi

# ==========================================
# Test: env_vars includes SUPABASE_PROJECT_URL
# ==========================================
info "Testing env_vars..."

env_vars=$(parse_yaml_array "$SKILL_FILE" "env_vars")
if echo "$env_vars" | grep -q "SUPABASE_PROJECT_URL"; then
    pass "env_vars includes 'SUPABASE_PROJECT_URL'"
else
    fail "env_vars does not include 'SUPABASE_PROJECT_URL' (found: $env_vars)"
fi

if echo "$env_vars" | grep -q "SUPABASE_SERVICE_KEY"; then
    pass "env_vars includes 'SUPABASE_SERVICE_KEY'"
else
    fail "env_vars does not include 'SUPABASE_SERVICE_KEY' (found: $env_vars)"
fi

# ==========================================
# Test: required_tools is defined
# ==========================================
info "Testing required_tools..."

required_tools=$(parse_yaml_array "$SKILL_FILE" "required_tools")
if [ -n "$required_tools" ] && [ "$required_tools" != "null" ]; then
    pass "required_tools is defined: $required_tools"
else
    fail "required_tools is not defined"
fi

# Check for supabase_query tool
if echo "$required_tools" | grep -q "supabase_query"; then
    pass "required_tools includes 'supabase_query'"
else
    fail "required_tools does not include 'supabase_query'"
fi

# ==========================================
# Test: Version follows semver format
# ==========================================
info "Testing version format..."

version=$(parse_yaml_field "$SKILL_FILE" "version")
if echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    pass "version follows semver format: $version"
else
    fail "version does not follow semver format: $version (expected: X.Y.Z)"
fi

# ==========================================
# Test: Templates contain supabase-related keywords
# ==========================================
info "Testing templates content..."

# Check Claude template contains supabase keywords
claude_template=$(ruby -ryaml -e "puts YAML.load_file('$SKILL_FILE')['templates']['claude']" 2>/dev/null)
if echo "$claude_template" | grep -qi "supabase"; then
    pass "Claude template contains supabase-related content"
else
    fail "Claude template missing supabase-related content"
fi

# Check for database/query references
if echo "$claude_template" | grep -qi "database\|query\|sql"; then
    pass "Claude template references database operations"
else
    fail "Claude template missing database operation references"
fi

# Check for auto-detection reference
if echo "$claude_template" | grep -qi "\.supabase\|auto-detect"; then
    pass "Claude template mentions auto-detection"
else
    fail "Claude template missing auto-detection reference"
fi

# Check Gemini template
gemini_template=$(ruby -ryaml -e "puts YAML.load_file('$SKILL_FILE')['templates']['gemini']" 2>/dev/null)
if echo "$gemini_template" | grep -qi "supabase"; then
    pass "Gemini template contains supabase-related content"
else
    fail "Gemini template missing supabase-related content"
fi

# Check Codex template
codex_template=$(ruby -ryaml -e "puts YAML.load_file('$SKILL_FILE')['templates']['codex']" 2>/dev/null)
if echo "$codex_template" | grep -qi "supabase"; then
    pass "Codex template contains supabase-related content"
else
    fail "Codex template missing supabase-related content"
fi

# ==========================================
# Summary
# ==========================================
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total tests: $TOTAL_TESTS"
printf "${GREEN}Passed: $PASS_COUNT${NC}\n"
if [ $FAIL_COUNT -gt 0 ]; then
    printf "${RED}Failed: $FAIL_COUNT${NC}\n"
    exit 1
else
    printf "${GREEN}All tests passed!${NC}\n"
    exit 0
fi
