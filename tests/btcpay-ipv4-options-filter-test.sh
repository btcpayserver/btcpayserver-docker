#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin" "$test_dir/no-nft" "$test_dir/apt"
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
        [ -e "$NFT_STATE" ] || exit 1
        [ -e "$NFT_STATE.flushed" ] || echo 'ip hdrlength > 5 counter packets 3 bytes 372 drop comment "CVE-2026-98432"'
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
cat > "$test_dir/apt/apt-get" <<EOF
#!/bin/bash
echo "\$*" >> "$test_dir/apt-get.calls"
[ "\$1" != install ] || $(command -v cp) "$test_dir/bin/nft" "$test_dir/apt/nft"
EOF
chmod +x "$test_dir/bin/nft" "$test_dir/apt/apt-get"
ln -s "$(command -v date)" "$test_dir/no-nft/date"
ln -s "$(command -v date)" "$test_dir/apt/date"
ln -s "$(command -v cat)" "$test_dir/apt/cat"
export PATH="$test_dir/bin:$PATH" BTCPAY_BASE_DIRECTORY="$test_dir" NFT_STATE="$test_dir/ruleset"
cli="$repo_dir/btcpay-ipv4-options-filter"
flag="$test_dir/.ipv4-options-filter"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

helper() {
    (. "$repo_dir/helpers.sh" && "$@")
}

[ "$("$cli" status)" = $'Enabled: no\nLoaded: no' ] || fail "status before enable"

"$cli" enable > /dev/null
grep -q '^enabled ' "$flag" || fail "enable did not record the flag"
grep -q 'ip hdrlength > 5 counter drop' "$NFT_STATE" || fail "enable did not load the drop rule"
grep -q 'hook prerouting priority -300' "$NFT_STATE" || fail "the filter does not run before connection tracking"
[ "$("$cli" status)" = "Enabled: yes, since $(cut -d ' ' -f 2 "$flag")"$'\nLoaded: yes, 3 packets dropped' ] || fail "status after enable"
touch "$NFT_STATE.flushed"
[ "$("$cli" status | tail -1)" = "Loaded: no" ] || fail "status reported a flushed table as loaded"
rm "$NFT_STATE.flushed"

# A reboot empties the kernel ruleset but keeps the flag.
rm "$NFT_STATE"
helper btcpay_ipv4_options_filter_restore
[ -e "$NFT_STATE" ] || fail "restore did not reload an enabled filter"

"$cli" disable > /dev/null
grep -q '^disabled ' "$flag" && [ ! -e "$NFT_STATE" ] || fail "disable did not unload and record the filter"
[[ "$("$cli" status)" == "Enabled: no, disabled since "* ]] || fail "status after disable"
calls="$(wc -l < "$NFT_STATE.calls")"
helper btcpay_ipv4_options_filter_restore
helper btcpay_ipv4_options_filter_default > /dev/null
{ [ "$(wc -l < "$NFT_STATE.calls")" -eq "$calls" ] && grep -q '^disabled ' "$flag"; } || fail "a disabled filter came back"

rm "$flag"
BTCPAY_IPV4_OPTIONS_FILTER=false helper btcpay_ipv4_options_filter_default
[ ! -e "$flag" ] || fail "setup enabled the filter although BTCPAY_IPV4_OPTIONS_FILTER=false"

helper btcpay_ipv4_options_filter_default > /dev/null
{ grep -q '^enabled ' "$flag" && [ -e "$NFT_STATE" ]; } || fail "setup did not enable and load the filter by default"

rm "$flag"
PATH="$test_dir/no-nft" helper btcpay_ipv4_options_filter_default 2> /dev/null
[ ! -e "$flag" ] || fail "setup enabled the filter without nft"

PATH="$test_dir/apt" helper btcpay_ipv4_options_filter_default > /dev/null
{ grep -q 'install -y -qq nftables' "$test_dir/apt-get.calls" && grep -q '^enabled ' "$flag"; } || fail "setup did not install nftables before enabling the filter"

! PATH="$test_dir/no-nft" "$cli" disable > /dev/null 2>&1 || fail "disable succeeded without nft"
grep -q '^enabled ' "$flag" || fail "disable without nft changed the flag"

rm "$flag"
touch "$NFT_STATE.fail"
! "$cli" enable > /dev/null 2>&1 || fail "enable succeeded although nft failed"
[ ! -e "$flag" ] || fail "enable recorded the flag although nft failed"
helper btcpay_ipv4_options_filter_default 2> /dev/null
[ ! -e "$flag" ] || fail "setup recorded the flag although nft failed"

printf 'IPv4 options filter tests passed\n'
