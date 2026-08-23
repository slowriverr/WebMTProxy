#!/usr/bin/env bash
# Self-check for the pieces of install.sh that can go wrong silently:
# input validation and the umask patch. Run it anywhere: ./test_install.sh
set -euo pipefail

WEBMTPROXY_LIB=1 source "$(dirname "${BASH_SOURCE[0]}")/install.sh"

ok=0
check() { # check "what" <boolean command>
	local what=$1; shift
	if "$@"; then printf '  ok   %s\n' "$what"; ok=$((ok + 1))
	else printf '  FAIL %s\n' "$what"; exit 1; fi
}
no() { ! "$@"; }

check "accepts a hostname"          valid_domain proxy.example.com
check "rejects a bare label"        no valid_domain localhost
check "rejects uppercase"           no valid_domain Proxy.Example.com
check "rejects a leading dash"      no valid_domain -bad.example.com
check "accepts an e-mail"           valid_email you+tag@example.co.uk
check "rejects a domainless e-mail" no valid_email "you@example"
check "accepts a 32-hex secret"     valid_secret 0123456789abcdef0123456789abcdef
check "accepts a dd-prefixed one"   valid_secret dd0123456789abcdef0123456789abcdef
check "rejects a short secret"      no valid_secret 0123456789abcdef
check "rejects uppercase hex"       no valid_secret 0123456789ABCDEF0123456789ABCDEF
check "generates a valid secret"    valid_secret "$(gen_secret)"

# patch_umask against a stand-in for the real upstream deploy/install.sh.
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
cat > "$work/install.sh" <<'UPSTREAM'
#!/usr/bin/env bash
set -euo pipefail
umask 077
repository=/opt/tproxy-server
go_binary=/usr/local/go/bin/go
"$repository/deploy/install-mtproxy.sh"
(cd "$repository" && "$go_binary" test ./...)
(cd "$repository" && "$go_binary" build -o /usr/local/bin/tproxy-server ./cmd/tproxy-server)
UPSTREAM
chmod 0755 "$work/install.sh"

patch_umask "$work/install.sh" >/dev/null
check "wraps the mtproxy build" grep -qF '(umask 022; "$repository/deploy/install-mtproxy.sh")' "$work/install.sh"
check "wraps the go test run"   grep -qF '(umask 022; cd "$repository" && "$go_binary" test ./...)' "$work/install.sh"
check "leaves the build line"   grep -qF '(cd "$repository" && "$go_binary" build' "$work/install.sh"
check "keeps it executable"     test -x "$work/install.sh"
check "keeps it valid bash"     bash -n "$work/install.sh"

# Upstream moved the lines: fall back to relaxing the umask globally.
printf '#!/usr/bin/env bash\nset -eu\numask 077\nmake_it_all\n' > "$work/moved.sh"
patch_umask "$work/moved.sh" 2>/dev/null
check "falls back to umask 022" grep -qx 'umask 022' "$work/moved.sh"

# Nothing to patch at all: fail loudly rather than install a broken proxy.
printf '#!/usr/bin/env bash\necho nothing to patch\n' > "$work/none.sh"
check "fails when unpatchable" no patch_umask "$work/none.sh" 2>/dev/null

# ── webmtproxy ───────────────────────────────────────────────────────────────

WEBMTPROXY_LIB=1 source "$(dirname "${BASH_SOURCE[0]}")/webmtproxy"

check "formats seconds" test "$(human_dur 45)" = "45s"
check "formats minutes" test "$(human_dur 3540)" = "59m"
check "formats hours"   test "$(human_dur 7500)" = "2h 5m"
check "formats days"    test "$(human_dur 273600)" = "3d 4h"

# Secret rotation touches both the relay profile and the MTProxy env, and the
# dd prefix must be stripped for the second. Stub out root-only side effects.
chown()     { :; }
systemctl() { :; }

CONFIG="$work/config.json"
PROFILES="$work/profiles.json"
MTPROXY_ENV="$work/mtproxy.env"
printf '{\n  "public_hostname": "proxy.example.com",\n  "listen": "127.0.0.1:8080"\n}\n' > "$CONFIG"
printf '{"profiles":[{"name":"default","secret":"%s","backend":"127.0.0.1:2398"}]}\n' \
	0000000000000000000000000000aaaa > "$PROFILES"
printf 'MTPROXY_SECRET=%s\nMTPROXY_WORKERS=1\nMTPROXY_MAX_CONNECTIONS=4096\n' \
	0000000000000000000000000000aaaa > "$MTPROXY_ENV"

new=dd11111111111111111111111111111111
cmd_rotate "$new" >/dev/null
check "relay keeps the dd prefix" grep -qF "\"secret\":\"$new\"" "$PROFILES"
check "relay keeps the backend"   grep -qF '"backend":"127.0.0.1:2398"' "$PROFILES"
check "MTProxy gets bare hex"     grep -qx 'MTPROXY_SECRET=11111111111111111111111111111111' "$MTPROXY_ENV"
check "MTProxy keeps its workers" grep -qx 'MTPROXY_WORKERS=1' "$MTPROXY_ENV"
check "rejects a bad secret"      no bash -c 'cmd_rotate nothex' 2>/dev/null

check "reads the hostname" test "$(read_domain)" = proxy.example.com
check "builds the link"    test "$(tg_link)" = "https://t.me/webproxy?server=proxy.example.com&secret=$new"

printf '\n  %d checks passed\n\n' "$ok"
