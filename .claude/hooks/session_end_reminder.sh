#!/bin/bash

# session_end_reminder.sh
# This hook reminds the agent to create session documentation

cat << 'EOF'

⚠️  SESSION ENDING - DOCUMENTATION REQUIRED ⚠️

According to .vibe_kanban/rules/agent_instructions.md, you MUST:

1. Create a session document: docs/agent_sessions/YYYY-MM-DD_HHmm_task-name.md
2. Use the template: docs/templates/session_template.md
3. Fill in ALL required sections:
   ✓ Overview (timestamps, status, tags)
   ✓ Prompt (original user request - verbatim)
   ✓ Execution Details (all files changed/created/deleted)
   ✓ Deliverables (what was accomplished)
   ✓ AI Self-Evaluation (6-item checklist, requirements, concerns)

4. Be HONEST in self-evaluation:
   - Mark items unchecked if not verified
   - State reasons for unaddressed items
   - Note any uncertainties or concerns
   - Avoid overestimation

This is MANDATORY. Do not skip this step.

EOF

exit 0
