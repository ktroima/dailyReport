#!/bin/bash

# view_sessions.sh - Display agent session summaries with filtering options

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSIONS_DIR="${SCRIPT_DIR}/../agent_sessions"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Display agent session summaries with filtering options.

OPTIONS:
  --recent N        Show N most recent sessions (default: 10)
  --tag TAG         Filter by tag (feature, bugfix, refactor, docs, test)
  --status STATUS   Filter by status (success, partial, failed)
  --search TERM     Search in task names
  --all             Show all sessions
  -h, --help        Show this help message

EXAMPLES:
  $0 --recent 5
  $0 --tag bugfix
  $0 --status failed
  $0 --search validation

EOF
  exit 0
}

# Parse arguments
RECENT=10
TAG=""
STATUS=""
SEARCH=""
SHOW_ALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --recent)
      RECENT="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --status)
      STATUS="$2"
      shift 2
      ;;
    --search)
      SEARCH="$2"
      shift 2
      ;;
    --all)
      SHOW_ALL=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Check if sessions directory exists
if [[ ! -d "$SESSIONS_DIR" ]]; then
  echo "Error: Sessions directory not found: $SESSIONS_DIR"
  exit 1
fi

# Get all session files
mapfile -t session_files < <(find "$SESSIONS_DIR" -name "*.md" ! -name "index.md" | sort -r)

if [[ ${#session_files[@]} -eq 0 ]]; then
  echo "No session files found."
  exit 0
fi

# Extract session info
extract_info() {
  local file="$1"
  local filename=$(basename "$file" .md)

  # Extract title (first line starting with #)
  local title=$(grep -m 1 "^# " "$file" | sed 's/^# //')

  # Extract status
  local status=$(grep -m 1 "ステータス:\|Status:" "$file" | sed -E 's/.*: //; s/ \/.*//')

  # Extract tags
  local tags=$(grep -m 1 "タグ:\|Tags:" "$file" | sed -E 's/.*: //; s/`//g')

  # Determine status emoji
  local status_emoji=""
  if [[ "$status" == *"成功"* || "$status" == *"成功"* ]]; then
    status_emoji="${GREEN}✅${NC}"
  elif [[ "$status" == *"部分"* || "$status" == *"部分"* ]]; then
    status_emoji="${YELLOW}⚠️${NC}"
  elif [[ "$status" == *"失敗"* || "$status" == *"失敗"* ]]; then
    status_emoji="${RED}❌${NC}"
  else
    status_emoji="${BLUE}🔄${NC}"
  fi

  echo "$filename|$title|$status|$tags|$status_emoji"
}

# Filter and display
count=0
echo ""
echo "=========================================="
echo "        Agent Session Summary"
echo "=========================================="
echo ""

for file in "${session_files[@]}"; do
  info=$(extract_info "$file")

  IFS='|' read -r filename title status tags status_emoji <<< "$info"

  # Apply filters
  if [[ -n "$TAG" && "$tags" != *"$TAG"* ]]; then
    continue
  fi

  if [[ -n "$STATUS" ]]; then
    case "$STATUS" in
      success)
        if [[ "$status" != *"成功"* && "$status" != *"成功"* ]]; then
          continue
        fi
        ;;
      partial)
        if [[ "$status" != *"部分"* && "$status" != *"部分"* ]]; then
          continue
        fi
        ;;
      failed)
        if [[ "$status" != *"失敗"* && "$status" != *"失敗"* ]]; then
          continue
        fi
        ;;
    esac
  fi

  if [[ -n "$SEARCH" && "$title" != *"$SEARCH"* ]]; then
    continue
  fi

  # Display session
  echo -e "${status_emoji} ${BLUE}${filename}${NC}"
  echo "   ${title}"
  if [[ -n "$tags" ]]; then
    echo "   Tags: ${tags}"
  fi
  echo ""

  count=$((count + 1))

  # Limit display if not showing all
  if [[ "$SHOW_ALL" == false && $count -ge $RECENT ]]; then
    break
  fi
done

if [[ $count -eq 0 ]]; then
  echo "No sessions found matching the criteria."
else
  echo "=========================================="
  echo "Displayed: $count session(s)"
  echo "=========================================="
fi

echo ""
