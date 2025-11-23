# Agent Instructions for dailyReport Project

This document defines the rules and procedures that AI agents should follow when working on the dailyReport project.

---

## Project Overview

dailyReport is a daily report management tool for macOS.

### Tech Stack
- **Language**: Bash
- **Dependencies**: jq, launchd, osascript
- **Target OS**: macOS only

### Project Structure
```
dailyReport/
├── *.sh                    # Main scripts
├── config.sh              # Configuration file
├── 2025/                  # Daily report JSON data (by year)
├── docs/                  # Documentation
│   ├── agent_sessions/   # Agent work history
│   ├── templates/        # Templates
│   └── scripts/          # Helper scripts
└── .vibe_kanban/         # Project management
    └── rules/            # Agent rules
```

---

## Session Recording Obligation

**MUST execute the following for ALL work sessions:**

### 1. At Session Start
Understand the task and prepare for recording before starting work.

### 2. During Work
- Record changed files and reasons
- Record executed commands
- Record errors and issues

### 3. At Session End (MANDATORY)

#### 3.1. Create Session Document

Create a file in `docs/agent_sessions/` with this naming convention:
```
YYYY-MM-DD_HHmm_task-name.md
```

Example: `2025-11-24_1430_add-validation.md`

#### 3.2. Use Template

Based on `docs/templates/session_template.md`, fill in ALL sections:

##### Required Sections
1. **Overview** - Work time, status, tags
2. **Prompt** - Original user request (verbatim)
3. **Execution Details** - Changed/new/deleted files, commands
4. **Deliverables** - Implemented features, fixed bugs
5. **Evaluation > AI Self-Evaluation** - Including:
   - Completion checklist (6 items)
   - Requirement achievement (evaluate each requirement)
   - Unaddressed items / Constraints
   - Concerns / Insights

##### Optional Sections
- **Related Information** - Related sessions, references, Git info

#### 3.3. Self-Evaluation Guidelines

**Record objectively and honestly. Pay attention to:**

1. **Completion Checklist**
   - Record actual verification results
   - For unverified items, leave unchecked and state reason
   - Example: "Not tested due to lack of test environment"

2. **Requirement Achievement**
   - ✅ Complete: Fully satisfied requirement
   - ⚠️ Partial: Only part addressed or has constraints
   - ❌ Not addressed: Could not address
   - Describe details for each requirement

3. **Unaddressed Items / Constraints**
   - State reasons why couldn't address
   - Technical constraints, lack of info, time constraints, etc.
   - MUST clearly state "not verified in operation"

4. **Concerns / Insights**
   - Potential issues noticed during implementation
   - Points that may become problems in the future
   - Ideas for better implementation
   - **Avoid overestimation**: Record uncertainties honestly

#### 3.4. Recording Timing

- Create session document **immediately after work completion**
- Record before forgetting work details
- Honestly record unknowns and unverified items

---

## Coding Conventions

### Bash Script Style
- Indentation: 2 spaces
- Function names: `snake_case`
- Variable names: `UPPER_CASE` (global), `lower_case` (local)
- Error handling: Required
- Comments: Japanese OK

### Example
```bash
#!/bin/bash

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

# Function definition
validate_input() {
  local input="$1"

  if [[ -z "$input" ]]; then
    echo "Error: Input is empty" >&2
    return 1
  fi

  return 0
}
```

---

## Technical Constraints and Precautions

### macOS-specific Features
- `launchd`: Reminder scheduling
- `osascript`: Notification dialog display
- Implementation for other OSes not needed unless requested

### Dependencies
- `jq`: Required for JSON operations
- `bash`: version 3.2+ (macOS standard)

### File Operations
- Daily report data: `YYYY/MM/DD.json` format
- JSON schema: refer to existing files
- Timezone: Asia/Tokyo fixed

### Test Environment
- Currently no automated test environment
- Manual testing assumed
- If tests cannot be run, note in self-evaluation

---

## Documentation Management

### README.md
- MUST update when adding features
- Also update when changing settings
- Include examples

### Session Documents
- Saved as work history
- Humans will add evaluation later
- Also used as learning data for AI self-evaluation accuracy

---

## Pre-Work Checklist

Before starting work, verify:

1. **Understand Existing Code**
   - Read related scripts
   - Follow existing implementation patterns

2. **Understand Impact Scope**
   - Will changes affect other scripts?
   - config.sh changes should also reflect in README

3. **Verify Backup**
   - Verify under Git management
   - Recommended to commit before major changes

---

## Work Priority

1. **Feature Accuracy** - Works as expected
2. **Protect Existing Features** - Don't break existing functionality
3. **Code Consistency** - Follow existing style
4. **Documentation** - Update README etc.
5. **Record Completeness** - Create session document

---

## Definition of Work Completion

Work is considered complete when ALL of the following are met:

- [ ] Requested features are implemented
- [ ] Existing features are not broken (verified)
- [ ] Documentation is updated
- [ ] Session document is created
- [ ] Self-evaluation is recorded honestly and objectively

---

## Collaboration with Humans

### Communication
- Ask when uncertain
- Explicitly state assumptions
- Present options when multiple implementation approaches exist

### Evaluation Transparency
- Record self-evaluation honestly
- Clearly state unverified points
- Learn from human evaluations

### Continuous Improvement
- Learn from past sessions
- Don't repeat same mistakes
- Suggest better implementation methods

---

## References

- Main documentation: [README.md](../../README.md)
- Session template: [docs/templates/session_template.md](../../docs/templates/session_template.md)
- Past sessions: [docs/agent_sessions/](../../docs/agent_sessions/)

---

**Last Updated**: 2025-11-24
