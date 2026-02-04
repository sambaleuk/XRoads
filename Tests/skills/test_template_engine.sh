#!/bin/bash
# test_template_engine.sh - Unit tests for skill-converter.sh and skill-loader.sh
# Part of XRoads Multi-CLI Loop System

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Paths
SKILL_CONVERTER="$HOME/.xroads/lib/skill-converter.sh"
SKILL_LOADER="$HOME/.xroads/lib/skill-loader.sh"
SKILLS_DIR="$HOME/.xroads/skills"

# Test helper functions
test_start() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -n "  Test $TESTS_TOTAL: $1 ... "
}

test_pass() {
    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}FAIL${NC}"
    echo "    Reason: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# ============================================
# skill-converter.sh Tests
# ============================================

echo ""
echo "=========================================="
echo "Testing skill-converter.sh"
echo "=========================================="
echo ""

# Test 1: Converter script exists and is executable
test_start "skill-converter.sh exists and is executable"
if [[ -x "$SKILL_CONVERTER" ]]; then
    test_pass
else
    test_fail "File not found or not executable: $SKILL_CONVERTER"
fi

# Test 2: Converter shows help
test_start "skill-converter.sh --help shows usage"
if "$SKILL_CONVERTER" --help 2>&1 | grep -q "Usage:"; then
    test_pass
else
    test_fail "--help doesn't show usage information"
fi

# Test 3: Converter returns Claude template for commit skill
test_start "skill-converter.sh --skill commit --cli claude returns Claude template"
output=$("$SKILL_CONVERTER" --skill commit --cli claude 2>/dev/null) || true
if echo "$output" | grep -q "/commit Skill"; then
    test_pass
else
    test_fail "Claude template not found in output"
fi

# Test 4: Converter returns Gemini template for commit skill
test_start "skill-converter.sh --skill commit --cli gemini returns Gemini template"
output=$("$SKILL_CONVERTER" --skill commit --cli gemini 2>/dev/null) || true
if echo "$output" | grep -q "@commit Extension"; then
    test_pass
else
    test_fail "Gemini template not found in output"
fi

# Test 5: Converter returns Codex template for commit skill
test_start "skill-converter.sh --skill commit --cli codex returns Codex template"
output=$("$SKILL_CONVERTER" --skill commit --cli codex 2>/dev/null) || true
if echo "$output" | grep -q "Commit Ritual"; then
    test_pass
else
    test_fail "Codex template not found in output"
fi

# Test 6: Converter replaces {{context}} placeholder
test_start "skill-converter.sh replaces {{context}} placeholder"
output=$("$SKILL_CONVERTER" --skill commit --cli claude --context "Test Context Here" 2>/dev/null) || true
if echo "$output" | grep -q "Test Context Here"; then
    test_pass
else
    test_fail "{{context}} placeholder not replaced"
fi

# Test 7: Converter replaces {{branch}} placeholder
test_start "skill-converter.sh replaces {{branch}} placeholder"
output=$("$SKILL_CONVERTER" --skill commit --cli claude --branch "feat/test-branch" 2>/dev/null) || true
if echo "$output" | grep -q "feat/test-branch"; then
    test_pass
else
    test_fail "{{branch}} placeholder not replaced"
fi

# Test 8: Converter --raw preserves placeholders
test_start "skill-converter.sh --raw preserves placeholders"
output=$("$SKILL_CONVERTER" --skill commit --cli claude --raw 2>/dev/null) || true
if echo "$output" | grep -q "{{context}}"; then
    test_pass
else
    test_fail "--raw mode should preserve {{context}} placeholder"
fi

# Test 9: Converter fails for invalid skill
test_start "skill-converter.sh fails for invalid skill"
# Disable pipefail temporarily - we expect the command to fail
set +o pipefail
error_output=$("$SKILL_CONVERTER" --skill nonexistent-skill --cli claude 2>&1) || true
set -o pipefail
if echo "$error_output" | grep -qi "error"; then
    test_pass
else
    test_fail "Should fail for nonexistent skill"
fi

# Test 10: Converter fails for invalid CLI
test_start "skill-converter.sh fails for invalid CLI"
# Disable pipefail temporarily - we expect the command to fail
set +o pipefail
error_output=$("$SKILL_CONVERTER" --skill commit --cli invalid-cli 2>&1) || true
set -o pipefail
if echo "$error_output" | grep -qi "error"; then
    test_pass
else
    test_fail "Should fail for invalid CLI"
fi

# Test 11: Converter returns review-pr Claude template
test_start "skill-converter.sh --skill review-pr --cli claude returns template"
output=$("$SKILL_CONVERTER" --skill review-pr --cli claude 2>/dev/null) || true
if echo "$output" | grep -qi "review"; then
    test_pass
else
    test_fail "review-pr Claude template not found"
fi

# Test 12: Converter returns prd Gemini template
test_start "skill-converter.sh --skill prd --cli gemini returns template"
output=$("$SKILL_CONVERTER" --skill prd --cli gemini 2>/dev/null) || true
if echo "$output" | grep -qi "prd\|implementation"; then
    test_pass
else
    test_fail "prd Gemini template not found"
fi

# Test 13: Converter returns test-writer Codex template
test_start "skill-converter.sh --skill test-writer --cli codex returns template"
output=$("$SKILL_CONVERTER" --skill test-writer --cli codex 2>/dev/null) || true
if echo "$output" | grep -qi "test"; then
    test_pass
else
    test_fail "test-writer Codex template not found"
fi

# ============================================
# skill-loader.sh Tests
# ============================================

echo ""
echo "=========================================="
echo "Testing skill-loader.sh"
echo "=========================================="
echo ""

# Test 14: Loader script exists and is executable
test_start "skill-loader.sh exists and is executable"
if [[ -x "$SKILL_LOADER" ]]; then
    test_pass
else
    test_fail "File not found or not executable: $SKILL_LOADER"
fi

# Test 15: Loader shows help
test_start "skill-loader.sh --help shows usage"
if "$SKILL_LOADER" --help 2>&1 | grep -q "Usage:"; then
    test_pass
else
    test_fail "--help doesn't show usage information"
fi

# Test 16: Loader --list-available shows skills
test_start "skill-loader.sh --list-available shows skills"
output=$("$SKILL_LOADER" --list-available 2>/dev/null) || true
if echo "$output" | grep -q "commit"; then
    test_pass
else
    test_fail "--list-available doesn't show commit skill"
fi

# Test 17: Loader loads single skill for Claude
test_start "skill-loader.sh --cli claude --skills commit loads commit skill"
output=$("$SKILL_LOADER" --cli claude --skills commit 2>/dev/null) || true
if echo "$output" | grep -q "/commit Skill"; then
    test_pass
else
    test_fail "commit skill not loaded for Claude"
fi

# Test 18: Loader loads multiple skills
test_start "skill-loader.sh --cli claude --skills commit,prd loads multiple skills"
output=$("$SKILL_LOADER" --cli claude --skills commit,prd 2>/dev/null) || true
if echo "$output" | grep -q "/commit Skill" && echo "$output" | grep -qi "prd\|implementation"; then
    test_pass
else
    test_fail "Multiple skills not loaded correctly"
fi

# Test 19: Loader uses core skills by default
test_start "skill-loader.sh --cli gemini uses core skills by default"
output=$("$SKILL_LOADER" --cli gemini 2>&1) || true
# Should mention loading core skills or include core skill content
if echo "$output" | grep -qi "core\|commit\|skill"; then
    test_pass
else
    test_fail "Core skills not loaded by default"
fi

# Test 20: Loader --format sections adds headers
test_start "skill-loader.sh --format sections adds skill headers"
output=$("$SKILL_LOADER" --cli claude --skills commit --format sections 2>/dev/null) || true
if echo "$output" | grep -q "SKILL: commit"; then
    test_pass
else
    test_fail "sections format doesn't add skill headers"
fi

# Test 21: Loader --format json outputs valid JSON structure
test_start "skill-loader.sh --format json outputs JSON"
output=$("$SKILL_LOADER" --cli claude --skills commit --format json 2>/dev/null) || true
if echo "$output" | grep -q '"commit"'; then
    test_pass
else
    test_fail "JSON format doesn't output valid structure"
fi

# Test 22: Loader replaces placeholders
test_start "skill-loader.sh replaces {{context}} placeholder"
output=$("$SKILL_LOADER" --cli claude --skills commit --context "Loader Test Context" 2>/dev/null) || true
if echo "$output" | grep -q "Loader Test Context"; then
    test_pass
else
    test_fail "{{context}} placeholder not replaced in loader"
fi

# Test 23: Loader replaces {{branch}} placeholder
test_start "skill-loader.sh replaces {{branch}} placeholder"
output=$("$SKILL_LOADER" --cli gemini --skills commit --branch "test/loader-branch" 2>/dev/null) || true
if echo "$output" | grep -q "test/loader-branch"; then
    test_pass
else
    test_fail "{{branch}} placeholder not replaced in loader"
fi

# Test 24: Loader fails for invalid CLI
test_start "skill-loader.sh fails for invalid CLI"
# Disable pipefail temporarily - we expect the command to fail
set +o pipefail
error_output=$("$SKILL_LOADER" --cli invalid-cli --skills commit 2>&1) || true
set -o pipefail
if echo "$error_output" | grep -qi "error"; then
    test_pass
else
    test_fail "Should fail for invalid CLI"
fi

# Test 25: Loader handles nonexistent skill gracefully
test_start "skill-loader.sh handles nonexistent skill with warning"
output=$("$SKILL_LOADER" --cli claude --skills nonexistent-skill 2>&1) || true
# Should either warn or error about the nonexistent skill
if echo "$output" | grep -qi "warning\|error\|fail"; then
    test_pass
else
    test_fail "Should warn or error for nonexistent skill"
fi

# Test 26: Loader writes to output file
test_start "skill-loader.sh --output writes to file"
temp_file=$(mktemp)
"$SKILL_LOADER" --cli claude --skills commit --output "$temp_file" 2>/dev/null || true
if [[ -s "$temp_file" ]] && grep -q "/commit Skill" "$temp_file"; then
    test_pass
else
    test_fail "Output file not created or empty"
fi
rm -f "$temp_file"

# Test 27: All core skills load for each CLI
test_start "All core skills load for Claude"
output=$("$SKILL_LOADER" --cli claude 2>/dev/null) || true
# Check that multiple skills are present
skill_count=$(echo "$output" | grep -c "Skill\|Extension\|Ritual" || true)
if [[ $skill_count -ge 3 ]]; then
    test_pass
else
    test_fail "Expected at least 3 skill sections, got $skill_count"
fi

# Test 28: All core skills load for Gemini
test_start "All core skills load for Gemini"
output=$("$SKILL_LOADER" --cli gemini 2>/dev/null) || true
skill_count=$(echo "$output" | grep -c "@.*Extension\|Extension" || true)
if [[ $skill_count -ge 2 ]]; then
    test_pass
else
    test_fail "Expected at least 2 Gemini skill sections, got $skill_count"
fi

# Test 29: All core skills load for Codex
test_start "All core skills load for Codex"
output=$("$SKILL_LOADER" --cli codex 2>/dev/null) || true
skill_count=$(echo "$output" | grep -c "Ritual\|##" || true)
if [[ $skill_count -ge 2 ]]; then
    test_pass
else
    test_fail "Expected at least 2 Codex skill sections, got $skill_count"
fi

# Test 30: Combined output contains separators
test_start "Combined format contains separators between skills"
output=$("$SKILL_LOADER" --cli claude --skills commit,prd 2>/dev/null) || true
if echo "$output" | grep -q "^---$"; then
    test_pass
else
    test_fail "Combined format should have --- separators"
fi

# ============================================
# Summary
# ============================================

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Total tests:  $TESTS_TOTAL"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
