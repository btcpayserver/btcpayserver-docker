#!/bin/bash

cd "$(dirname "$0")/.."

FRAGMENTS_DIR="docker-compose-generator/docker-fragments"
AVAILABLE=($(ls "$FRAGMENTS_DIR" | sort))
AVAILABLE=($(cd "$FRAGMENTS_DIR" && ls *.yml | sed 's/\.yml$//' | sort))
ACTIVE=()
IFS=";" read -ra ACTIVE <<< "$BTCPAYGEN_ADDITIONAL_FRAGMENTS"

# Show current active fragments
echo "🔍 Current active fragments:"
if [[ -z "$BTCPAYGEN_ADDITIONAL_FRAGMENTS" ]]; then
  echo "(none)"
else
  for frag in "${ACTIVE[@]}"; do
    echo "  - $frag"
  done
fi
echo ""

# Show options
echo "What would you like to do?"
echo "1. Enable one or more fragments without the current ones"
echo "2. Enable one or more fragments (add to current)"
echo "3. Disable one or more fragments (remove from current)"
echo "4. Cancel"
read -p "Enter your choice [1-4]: " choice

if [[ "$choice" == "4" ]]; then
  echo "❌ Cancelled."
  exit 0
fi

# Show available fragments with numbers
echo ""
echo "📦 Available fragments:"
for i in "${!AVAILABLE[@]}"; do
  printf "%2d. %s\n" $((i+1)) "${AVAILABLE[$i]}"
done

read -p $'\nEnter the numbers (comma-separated): ' input
IFS=',' read -ra SELECTED <<< "$input"

NEW_FRAGMENTS=()

# Choice handling
case "$choice" in
  1)  # Add new fragments without the current ones
    for i in "${SELECTED[@]}"; do
      idx=$((i-1))
      NEW_FRAGMENTS+=("${AVAILABLE[$idx]}")
    done
    ;;
  2)  # Add selected fragments to the current ones
    NEW_FRAGMENTS=("${ACTIVE[@]}")
    for i in "${SELECTED[@]}"; do
      idx=$((i-1))
      frag="${AVAILABLE[$idx]}"
      [[ ! " ${NEW_FRAGMENTS[*]} " =~ " $frag " ]] && NEW_FRAGMENTS+=("$frag")
    done
    ;;
  3)  # Remove selected fragments
    REMOVE=()
    for i in "${SELECTED[@]}"; do
      idx=$((i-1))
      REMOVE+=("${AVAILABLE[$idx]}")
    done
    for frag in "${ACTIVE[@]}"; do
      [[ ! " ${REMOVE[*]} " =~ " $frag " ]] && NEW_FRAGMENTS+=("$frag")
    done
    ;;
  *)
    echo "❌ Invalid choice."
    exit 1
    ;;
esac

# Generate the final string value for BTCPAYGEN_ADDITIONAL_FRAGMENTS
FINAL_VALUE=$(IFS=";"; echo "${NEW_FRAGMENTS[*]}")
echo -e "\n⚙️ New BTCPAYGEN_ADDITIONAL_FRAGMENTS value:\n$FINAL_VALUE"

read -p $'\nProceed with this change and run btcpay-setup.sh? (y/N): ' confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  echo "✅ Running btcpay-setup.sh with updated fragments..."

  # Persist the changes to /etc/profile.d/btcpay-env.sh
  echo "export BTCPAYGEN_ADDITIONAL_FRAGMENTS=\"$FINAL_VALUE\"" > /etc/profile.d/btcpay-env.sh

  # Create a temporary script to run btcpay-setup.sh with the updated fragments
  TEMP_SCRIPT=$(mktemp)
  cat > "$TEMP_SCRIPT" <<EOF
#!/bin/bash
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="$FINAL_VALUE"
cd "$(pwd)"
. ./btcpay-setup.sh -i
EOF

  chmod +x "$TEMP_SCRIPT"
  bash --login "$TEMP_SCRIPT"
  rm -f "$TEMP_SCRIPT"
else
  echo "❌ Aborted."
  exit 0
fi
