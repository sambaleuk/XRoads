# Codex Loop Playbook

Use this file to leave short tactical notes for future Codex runs.

## Rituals
- codex plan → sanity check upcoming change list
- codex exec "npm run lint" → enforce quality gates
- codex files pin <file> → lock files that must not change

## Observations
-

## Guardrails
- Never push commits until <codex-complete> is emitted


## Loaded Skills (Auto-Injected)
<!-- Skills loaded by codex-loop at 2026-02-04 12:01:50 -->

# ===== SKILL: prd =====

## PRD Implementation Ritual

**Steps:**
1. Read `prd.json` - find first incomplete story
2. Read `progress.txt` + `AGENTS.md` for context
3. Verify story has `unit_test` field (REQUIRED)
4. Implement acceptance criteria
5. Write test at `unit_test.file`
6. Run: build + typecheck + unit test (ALL must pass)

**On Pass:**
- Update prd.json: status=complete, unit_test.status=passing
- `git commit -m "feat(scope): US-XXX desc"`
- Append to progress.txt

**On Fail:**
- No commit, no status change
- Log to progress.txt

Context: XRoads Multi-CLI Loop System

# ===== SKILL: commit =====

## Commit Ritual

**Steps:**
1. `git status` - check what's staged
2. `git diff --cached` - analyze changes
3. `git log --oneline -5` - match style
4. Determine type: feat|fix|docs|style|refactor|test|chore
5. `git commit -m "type(scope): description\n\nCo-Authored-By: Codex <noreply@openai.com>"`

**Constraints:**
- No `git add .` or `-A`
- No `--no-verify`
- Check for .env/credentials before staging

Context: XRoads Multi-CLI Loop System

# ===== SKILL: review-pr =====

## PR Review Ritual

**Steps:**
1. `gh pr view` - get context
2. `gh pr diff` - see changes
3. `gh pr checks` - CI status

**Checklist:**
- Correctness: logic errors
- Security: OWASP Top 10
- Performance: queries, memory
- Maintainability: naming, DRY
- Testing: coverage
- Documentation: API docs

**Output:** `review.md`
- Issues: severity|file:line|description|fix
- Verdict: approve|request-changes|comment

Context: XRoads Multi-CLI Loop System

# ===== SKILL: xroads-log =====

## XRoads Logging Ritual

The xroads-mcp server streams logs to XRoads UI.

**Log Levels:**
- info: Normal progress updates
- debug: Detailed diagnostics
- warn: Recoverable issues
- error: Failures

**Status Values:**
- running: Active work
- planning: Analysis phase
- complete: Task done
- error: Blocked

**Workflow:**
1. Iteration start: emit_log(info, "Starting iteration N for US-XXX")
2. Work begins: update_status(running, task="Implementing feature")
3. Success: emit_log(info, "Completed") + update_status(complete)
4. Failure: emit_log(error, "Reason") + update_status(error)

Context: XRoads Multi-CLI Loop System

# ===== SKILL: test-writer =====

## Test Writer Ritual

**Steps:**
1. Read target code - understand APIs
2. Plan tests:
   - Happy path
   - Edge cases (empty, null, bounds)
   - Errors
   - Async
3. Write tests:
   - describe/it structure
   - "should X when Y" naming
   - Arrange-Act-Assert pattern
4. Mock external dependencies
5. Run - all must pass, coverage >80%

**Output:** `tests/*.test.ts` or `*Tests.swift`

**Format:**
```
describe('[X]', () => {
  it('should Y when Z', () => { ... });
});
```

Context: XRoads Multi-CLI Loop System

# ===== SKILL: code-reviewer =====

## Code Review Ritual

**Categories:**
1. Correctness: logic, edge cases, nulls
2. Security: OWASP Top 10 (injection, XSS, auth)
3. Performance: N+1, memory, blocking
4. Maintainability: naming, DRY, complexity
5. Testing: coverage, edge cases

**Steps:**
1. Read files
2. Analyze each category
3. Report: severity|category|file:line|description|fix

**Severity:** critical > major > minor > suggestion

**Output:** `review.md`
- Issues by severity
- Summary assessment

Context: XRoads Multi-CLI Loop System

## End Loaded Skills
