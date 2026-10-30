#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin"
ln -s "$repo_dir" "$test_dir/btcpayserver-docker"
cat > "$test_dir/bin/nft" <<'EOF'
#!/bin/bash
case "$*" in
    "-f -")
        [ ! -e "$NFT_STATE.fail" ] || exit 1
        cat > "$NFT_STATE"
        echo apply >> "$NFT_STATE.calls"
        ;;
    "list table ip btcpay_ipv4_options")
        [ -e "$NFT_STATE" ]
        ;;
    "list chain ip btcpay_ipv4_options prerouting")
        [ -e "$NFT_STATE" ] && echo 'ip hdrlength > 5 counter packets 3 bytes 372 drop comment "CVE-2026-98432"'
        ;;
    "delete table ip btcpay_ipv4_options")
        rm "$NFT_STATE"
        ;;
    *)
        echo "unexpected nft $*" >&2
        exit 2
        ;;
esac
EOF
chmod +x "$test_dir/bin/nft"
export PATH="$test_dir/bin:$PATH" BTCPAY_BASE_DIRECTORY="$test_dir" NFT_STATE="$test_dir/ruleset"
cli="$repo_dir/btcpay-ipv4-options-filter"
flag="$test_dir/.ipv4-options-filter-enabled"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

restore() {
    (. "$repo_dir/helpers.sh" && btcpay_ipv4_options_filter_restore)
}

[ "$("$cli" status)" = $'Enabled: no\nLoaded: no' ] || fail "status before enable"

"$cli" enable > /dev/null
[ -s "$flag" ] || fail "enable did not record the flag"
grep -q 'ip hdrlength > 5 counter drop' "$NFT_STATE" || fail "enable did not load the drop rule"
grep -q 'hook prerouting priority -300' "$NFT_STATE" || fail "the filter does not run before connection tracking"
[ "$("$cli" status)" = "Enabled: yes, since $(cat "$flag")"$'\nLoaded: yes, 3 packets dropped' ] || fail "status after enable"

# A reboot empties the kernel ruleset but keeps the flag.
rm "$NFT_STATE"
restore
[ -e "$NFT_STATE" ] || fail "restore did not reload an enabled filter"

"$cli" disable > /dev/null
[ ! -e "$flag" ] && [ ! -e "$NFT_STATE" ] || fail "disable left the flag or the table"
calls="$(wc -l < "$NFT_STATE.calls")"
restore
[ "$(wc -l < "$NFT_STATE.calls")" -eq "$calls" ] || fail "restore loaded a disabled filter"

touch "$NFT_STATE.fail"
! "$cli" enable > /dev/null 2>&1 || fail "enable succeeded although nft failed"
[ ! -e "$flag" ] || fail "enable recorded the flag although nft failed"

printf 'IPv4 options filter tests passed\n'
