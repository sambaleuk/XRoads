#!/usr/bin/env bash
#
# test_repository_structure.sh
# Unit tests for US-V4-001: Skills Repository Structure
#
# Verifies that the XRoads skills repository is correctly set up with
# all required directories and documentation.
#

set -euo pipefail

# Configuration
SKILLS_ROOT="${HOME}/.xroads/skills"
PASS_COUNT=0
FAIL_COUNT=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test helper functions
pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# Test: Skills root directory exists
test_skills_root_exists() {
    if [[ -d "${SKILLS_ROOT}" ]]; then
        pass "~/.xroads/skills/ exists"
    else
        fail "~/.xroads/skills/ does not exist"
    fi
}

# Test: Core directory exists
test_core_dir_exists() {
    if [[ -d "${SKILLS_ROOT}/core" ]]; then
        pass "~/.xroads/skills/core/ exists"
    else
        fail "~/.xroads/skills/core/ does not exist"
    fi
}

# Test: Automation directory exists
test_automation_dir_exists() {
    if [[ -d "${SKILLS_ROOT}/automation" ]]; then
        pass "~/.xroads/skills/automation/ exists"
    else
        fail "~/.xroads/skills/automation/ does not exist"
    fi
}

# Test: Project directory exists
test_project_dir_exists() {
    if [[ -d "${SKILLS_ROOT}/project" ]]; then
        pass "~/.xroads/skills/project/ exists"
    else
        fail "~/.xroads/skills/project/ does not exist"
    fi
}

# Test: SCHEMA.md exists
test_schema_exists() {
    if [[ -f "${SKILLS_ROOT}/SCHEMA.md" ]]; then
        pass "~/.xroads/skills/SCHEMA.md exists"
    else
        fail "~/.xroads/skills/SCHEMA.md does not exist"
    fi
}

# Test: SCHEMA.md has content
test_schema_has_content() {
    if [[ -f "${SKILLS_ROOT}/SCHEMA.md" ]]; then
        local lines=$(wc -l < "${SKILLS_ROOT}/SCHEMA.md")
        if [[ ${lines} -gt 10 ]]; then
            pass "SCHEMA.md has meaningful content (${lines} lines)"
        else
            fail "SCHEMA.md is too short (${lines} lines)"
        fi
    else
        fail "SCHEMA.md does not exist - cannot check content"
    fi
}

# Test: SCHEMA.md documents required fields
test_schema_documents_fields() {
    if [[ -f "${SKILLS_ROOT}/SCHEMA.md" ]]; then
        local has_id=$(grep -c "^### \`id\`" "${SKILLS_ROOT}/SCHEMA.md" || echo "0")
        local has_templates=$(grep -c "templates" "${SKILLS_ROOT}/SCHEMA.md" || echo "0")
        local has_required_tools=$(grep -c "required_tools" "${SKILLS_ROOT}/SCHEMA.md" || echo "0")

        if [[ ${has_id} -gt 0 && ${has_templates} -gt 0 && ${has_required_tools} -gt 0 ]]; then
            pass "SCHEMA.md documents required fields (id, templates, required_tools)"
        else
            fail "SCHEMA.md missing documentation for some required fields"
        fi
    else
        fail "SCHEMA.md does not exist"
    fi
}

# Test: xroads-skills-init script exists
test_init_script_exists() {
    if [[ -f "${HOME}/bin/xroads-skills-init" ]]; then
        pass "~/bin/xroads-skills-init exists"
    else
        fail "~/bin/xroads-skills-init does not exist"
    fi
}

# Test: xroads-skills-init is executable
test_init_script_executable() {
    if [[ -x "${HOME}/bin/xroads-skills-init" ]]; then
        pass "xroads-skills-init is executable"
    else
        fail "xroads-skills-init is not executable"
    fi
}

# Test: xroads-skills-init --help works
test_init_script_help() {
    local script_path="${HOME}/bin/xroads-skills-init"
    local output
    output=$(bash "${script_path}" --help 2>&1 || true)
    if echo "${output}" | grep -q "Usage"; then
        pass "xroads-skills-init --help shows usage"
    else
        fail "xroads-skills-init --help doesn't show usage"
    fi
}

# Test: xroads-skills-init --list works
test_init_script_list() {
    local script_path="${HOME}/bin/xroads-skills-init"
    local output
    output=$(bash "${script_path}" --list 2>&1 || true)
    if echo "${output}" | grep -q "CORE"; then
        pass "xroads-skills-init --list shows categories"
    else
        fail "xroads-skills-init --list doesn't work correctly"
    fi
}

# Test: .gitkeep files exist in subdirectories
test_gitkeep_files() {
    local all_exist=true
    for dir in core automation project; do
        if [[ ! -f "${SKILLS_ROOT}/${dir}/.gitkeep" ]]; then
            all_exist=false
        fi
    done

    if [[ "${all_exist}" == "true" ]]; then
        pass ".gitkeep files exist in all subdirectories"
    else
        fail "Some .gitkeep files are missing"
    fi
}

# Run all tests
main() {
    echo "========================================"
    echo "US-V4-001: Skills Repository Structure"
    echo "========================================"
    echo ""

    # Run tests
    test_skills_root_exists
    test_core_dir_exists
    test_automation_dir_exists
    test_project_dir_exists
    test_schema_exists
    test_schema_has_content
    test_schema_documents_fields
    test_init_script_exists
    test_init_script_executable
    test_init_script_help
    test_init_script_list
    test_gitkeep_files

    # Summary
    echo ""
    echo "========================================"
    echo "Test Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
    echo "========================================"

    if [[ ${FAIL_COUNT} -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

main "$@"
