#!/bin/bash
# Unit test for US-V4-002: Core Skills Definition
# Verifies all core skill YAML files are valid and complete

set -e

SKILLS_DIR="$HOME/.xroads/skills/core"
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

check_field_exists() {
    local file="$1"
    local field="$2"
    local name="$3"

    local value
    value=$(parse_yaml_field "$file" "$field")

    if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "None" ]; then
        pass "$name has $field field"
        return 0
    else
        fail "$name missing $field field"
        return 1
    fi
}

check_templates_complete() {
    local file="$1"
    local name="$2"

    local has_claude has_gemini has_codex
    has_claude=$(parse_yaml_field "$file" "templates.claude")
    has_gemini=$(parse_yaml_field "$file" "templates.gemini")
    has_codex=$(parse_yaml_field "$file" "templates.codex")

    local all_present=true

    if [ -z "$has_claude" ] || [ "$has_claude" = "null" ] || [ "$has_claude" = "None" ]; then
        fail "$name missing templates.claude"
        all_present=false
    fi

    if [ -z "$has_gemini" ] || [ "$has_gemini" = "null" ] || [ "$has_gemini" = "None" ]; then
        fail "$name missing templates.gemini"
        all_present=false
    fi

    if [ -z "$has_codex" ] || [ "$has_codex" = "null" ] || [ "$has_codex" = "None" ]; then
        fail "$name missing templates.codex"
        all_present=false
    fi

    if [ "$all_present" = true ]; then
        pass "$name has all 3 CLI templates (claude, gemini, codex)"
    fi
}

check_required_tools_defined() {
    local file="$1"
    local name="$2"

    local tools
    tools=$(ruby -ryaml -e "
        data = YAML.load_file('$file')
        tools = data['required_tools']
        if tools.nil? || tools.empty?
            puts 'null'
        else
            puts tools.join(',')
        end
    " 2>/dev/null)

    if [ -n "$tools" ] && [ "$tools" != "null" ]; then
        pass "$name has required_tools defined"
        return 0
    else
        fail "$name missing required_tools"
        return 1
    fi
}

check_category_valid() {
    local file="$1"
    local name="$2"

    local category
    category=$(parse_yaml_field "$file" "category")

    case "$category" in
        core|automation|project)
            pass "$name has valid category: $category"
            return 0
            ;;
        *)
            fail "$name has invalid category: $category (expected: core, automation, project)"
            return 1
            ;;
    esac
}

check_version_format() {
    local file="$1"
    local name="$2"

    local version
    version=$(parse_yaml_field "$file" "version")

    if echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        pass "$name has valid semver version: $version"
        return 0
    else
        fail "$name has invalid version format: $version (expected: X.Y.Z)"
        return 1
    fi
}

# ==========================================
# Test: All expected skill files exist
# ==========================================
info "Testing skill file existence..."

EXPECTED_SKILLS=("commit" "review-pr" "prd" "test-writer" "code-reviewer")

for skill in "${EXPECTED_SKILLS[@]}"; do
    skill_file="$SKILLS_DIR/$skill.skill.yaml"
    if [ -f "$skill_file" ]; then
        pass "$skill.skill.yaml exists"
    else
        fail "$skill.skill.yaml does not exist"
    fi
done

# ==========================================
# Test: Each skill file is valid YAML
# ==========================================
info "Testing YAML validity..."

for skill in "${EXPECTED_SKILLS[@]}"; do
    skill_file="$SKILLS_DIR/$skill.skill.yaml"
    if [ -f "$skill_file" ]; then
        check_yaml_valid "$skill_file" "$skill.skill.yaml"
    fi
done

# ==========================================
# Test: Required fields exist
# ==========================================
info "Testing required fields..."

REQUIRED_FIELDS=("id" "name" "version" "description" "category")

for skill in "${EXPECTED_SKILLS[@]}"; do
    skill_file="$SKILLS_DIR/$skill.skill.yaml"
    if [ -f "$skill_file" ]; then
        for field in "${REQUIRED_FIELDS[@]}"; do
            check_field_exists "$skill_file" "$field" "$skill"
        done
    fi
done

# ==========================================
# Test: All skills have 3 CLI templates
# ==========================================
info "Testing CLI templates completeness..."

for skill in "${EXPECTED_SKILLS[@]}"; do
    skill_file="$SKILLS_DIR/$skill.skill.yaml"
    if [ -f "$skill_file" ]; then
        check_templates_complete "$skill_file" "$skill"
    fi
done

# ==========================================
# Test: All skills have required_tools defined
# ==========================================
info "Testing required_tools field..."

for skill in "${EXPECTED_SKILLS[@]}"; do
    skill_file="$SKILLS_DIR/$skill.skill.yaml"
    if [ -f "$skill_file" ]; then
        check_required_tools_defined "$skill_file" "$skill"
    fi
done

# ==========================================
# Test: Category is valid
# ==========================================
info "Testing category validity..."

for skill in "${EXPECTED_SKILLS[@]}"; do
    skill_file="$SKILLS_DIR/$skill.skill.yaml"
    if [ -f "$skill_file" ]; then
        check_category_valid "$skill_file" "$skill"
    fi
done

# ==========================================
# Test: Version follows semver format
# ==========================================
info "Testing version format..."

for skill in "${EXPECTED_SKILLS[@]}"; do
    skill_file="$SKILLS_DIR/$skill.skill.yaml"
    if [ -f "$skill_file" ]; then
        check_version_format "$skill_file" "$skill"
    fi
done

# ==========================================
# Test: ID matches filename
# ==========================================
info "Testing ID matches filename..."

for skill in "${EXPECTED_SKILLS[@]}"; do
    skill_file="$SKILLS_DIR/$skill.skill.yaml"
    if [ -f "$skill_file" ]; then
        skill_id=$(parse_yaml_field "$skill_file" "id")
        if [ "$skill_id" = "$skill" ]; then
            pass "$skill.skill.yaml id matches filename"
        else
            fail "$skill.skill.yaml id ($skill_id) does not match filename ($skill)"
        fi
    fi
done

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
