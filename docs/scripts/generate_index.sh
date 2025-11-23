#!/bin/bash

# generate_index.sh - Generate index.md for agent sessions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSIONS_DIR="${SCRIPT_DIR}/../agent_sessions"
INDEX_FILE="${SESSIONS_DIR}/index.md"

# Check if sessions directory exists
if [[ ! -d "$SESSIONS_DIR" ]]; then
  echo "Error: Sessions directory not found: $SESSIONS_DIR"
  exit 1
fi

# Get all session files
mapfile -t session_files < <(find "$SESSIONS_DIR" -name "*.md" ! -name "index.md" | sort -r)

# Extract session info
extract_info() {
  local file="$1"
  local filename=$(basename "$file" .md)
  local relpath=$(basename "$file")

  # Extract title (first line starting with #)
  local title=$(grep -m 1 "^# " "$file" | sed 's/^# //')

  # Extract date from filename (YYYY-MM-DD)
  local date=$(echo "$filename" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')

  # Extract status
  local status=$(grep -m 1 "ステータス:\|Status:" "$file" | sed -E 's/.*: //; s/ \/.*//')

  # Extract tags
  local tags=$(grep -m 1 "タグ:\|Tags:" "$file" | sed -E 's/.*: //; s/`//g')

  # Determine status emoji
  local status_emoji=""
  if [[ "$status" == *"成功"* || "$status" == *"success"* ]]; then
    status_emoji="✅"
  elif [[ "$status" == *"部分"* || "$status" == *"partial"* ]]; then
    status_emoji="⚠️"
  elif [[ "$status" == *"失敗"* || "$status" == *"failed"* ]]; then
    status_emoji="❌"
  else
    status_emoji="🔄"
  fi

  echo "$date|$relpath|$title|$status_emoji|$tags"
}

# Generate index
{
  echo "# Agent Session Index"
  echo ""
  echo "This index is automatically generated from session files."
  echo ""
  echo "**Last Updated**: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  echo "---"
  echo ""

  if [[ ${#session_files[@]} -eq 0 ]]; then
    echo "No session files found."
  else
    echo "## All Sessions (${#session_files[@]} total)"
    echo ""
    echo "| Date | Status | Title | Tags |"
    echo "|------|--------|-------|------|"

    for file in "${session_files[@]}"; do
      info=$(extract_info "$file")
      IFS='|' read -r date relpath title status_emoji tags <<< "$info"

      # Format table row
      echo "| $date | $status_emoji | [$title](./$relpath) | $tags |"
    done

    echo ""
    echo "---"
    echo ""

    # Statistics
    echo "## Statistics"
    echo ""

    # Count by status
    local success_count=0
    local partial_count=0
    local failed_count=0
    local other_count=0

    for file in "${session_files[@]}"; do
      local status=$(grep -m 1 "ステータス:\|Status:" "$file" | sed -E 's/.*: //; s/ \/.*//')

      if [[ "$status" == *"成功"* || "$status" == *"success"* ]]; then
        success_count=$((success_count + 1))
      elif [[ "$status" == *"部分"* || "$status" == *"partial"* ]]; then
        partial_count=$((partial_count + 1))
      elif [[ "$status" == *"失敗"* || "$status" == *"failed"* ]]; then
        failed_count=$((failed_count + 1))
      else
        other_count=$((other_count + 1))
      fi
    done

    echo "- ✅ Success: $success_count"
    echo "- ⚠️ Partial: $partial_count"
    echo "- ❌ Failed: $failed_count"
    echo "- 🔄 In Progress: $other_count"

    echo ""
    echo "---"
    echo ""

    # Tag cloud
    echo "## Tags"
    echo ""

    declare -A tag_counts
    for file in "${session_files[@]}"; do
      local tags=$(grep -m 1 "タグ:\|Tags:" "$file" | sed -E 's/.*: //; s/`//g')

      if [[ -n "$tags" ]]; then
        IFS=',' read -ra tag_array <<< "$tags"
        for tag in "${tag_array[@]}"; do
          tag=$(echo "$tag" | xargs)  # trim whitespace
          if [[ -n "$tag" ]]; then
            tag_counts["$tag"]=$((${tag_counts["$tag"]:-0} + 1))
          fi
        done
      fi
    done

    for tag in "${!tag_counts[@]}"; do
      echo "- \`$tag\` (${tag_counts[$tag]})"
    done | sort

    echo ""
    echo "---"
    echo ""

    echo "## Quick Links"
    echo ""
    echo "- [Session Template](../templates/session_template.md)"
    echo "- [Agent Instructions](../../.vibe_kanban/rules/agent_instructions.md)"
    echo "- [View Sessions Script](../scripts/view_sessions.sh)"
  fi
} > "$INDEX_FILE"

echo "Index generated: $INDEX_FILE"
