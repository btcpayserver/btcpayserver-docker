#!/bin/bash

set -e

# Determine repo root from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

FRAGMENTS_DIR="$REPO_ROOT/docker-compose-generator/docker-fragments"

# Show current fragments from environment
echo "🔍 Current active fragments:"
if [[ -z "$BTCPAYGEN_ADDITIONAL_FRAGMENTS" ]]; then
  echo "(none)"
else
  IFS=";" read -ra ACTIVE <<< "$BTCPAYGEN_ADDITIONAL_FRAGMENTS"
  for frag in "${ACTIVE[@]}"; do
    echo "  - $frag"
  done
fi
echo ""

# List available fragments
AVAILABLE=($(ls -1 "$FRAGMENTS_DIR" | sed 's/\.yml$//'))

# Prompt
echo "What would you like to do?"
echo "1. Enable one or more fragments without the current ones"
echo "2. Enable one or more fragments (add to current)"
echo "3. Disable one or more fragments (remove from current)"
echo "4. Cancel"
read -p "Enter your choice [1-4]: " choice

NEW_FRAGMENTS=""
case "$choice" in
  1)
    echo "Available fragments:"
    for i in "${!AVAILABLE[@]}"; do echo "$((i+1)). ${AVAILABLE[i]}"; done
    read -p "Enter the numbers to ENABLE (comma-separated): " input
    IFS=',' read -ra IDX <<< "$input"
    for idx in "${IDX[@]}"; do NEW+=("${AVAILABLE[$((idx-1))]}"); done
    ;;
  2)
    echo "Available fragments:"
    for i in "${!AVAILABLE[@]}"; do echo "$((i+1)). ${AVAILABLE[i]}"; done
    read -p "Enter the numbers to ADD (comma-separated): " input
    IFS=',' read -ra IDX <<< "$input"
    IFS=";" read -ra ACTIVE <<< "$BTCPAYGEN_ADDITIONAL_FRAGMENTS"
    NEW=("${ACTIVE[@]}")
    for idx in "${IDX[@]}"; do NEW+=("${AVAILABLE[$((idx-1))]}"); done
    ;;
  3)
    IFS=";" read -ra ACTIVE <<< "$BTCPAYGEN_ADDITIONAL_FRAGMENTS"
    echo "Current fragments:"
    for i in "${!ACTIVE[@]}"; do echo "$((i+1)). ${ACTIVE[i]}"; done
    read -p "Enter the numbers to REMOVE (comma-separated): " input
    IFS=',' read -ra IDX <<< "$input"
    REMOVE=()
    for idx in "${IDX[@]}"; do REMOVE+=("${ACTIVE[$((idx-1))]}"); done
    for frag in "${ACTIVE[@]}"; do
      skip=false
      for r in "${REMOVE[@]}"; do [[ "$frag" == "$r" ]] && skip=true && break; done
      $skip || NEW+=("$frag")
    done
    ;;
  4)
    echo "❌ Cancelled."
    exit 0
    ;;
  *)
    echo "❌ Invalid choice."
    exit 1
    ;;
esac

# Format and display new fragment list
NEW_FRAGMENTS=$(IFS=';'; echo "${NEW[*]}")
echo ""
echo "⚙️ New BTCPAYGEN_ADDITIONAL_FRAGMENTS value:"
echo "$NEW_FRAGMENTS"
read -p "Proceed with this change and run btcpay-setup.sh? (y/N): " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
  export BTCPAYGEN_ADDITIONAL_FRAGMENTS="$NEW_FRAGMENTS"
  echo "✅ Running btcpay-setup.sh..."
  ./btcpay-setup.sh
else
  echo "❌ Aborted."
  exit 0
fi
