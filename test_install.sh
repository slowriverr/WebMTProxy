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
# For functions that exit on error: a subshell still sees them, unlike `bash -c`.
fails() { ! ( "$@" ) >/dev/null 2>&1; }

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
check "prompt takes uppercase hex"  valid_secret_input 0123456789ABCDEF0123456789ABCDEF
check "prompt takes uppercase DD"   valid_secret_input DD0123456789abcdef0123456789abcdef
check "prompt still rejects junk"   no valid_secret_input nothex

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
check "rejects a bad secret"      fails cmd_rotate nothex

# The MTProxy knobs share that env file and are set with MTProxy's own flags;
# 0 is legal for both (single process, no cap) even though upstream refuses it.
cmd_limits -M 0 -C 0 >/dev/null
check "workers set to 0"          grep -qx 'MTPROXY_WORKERS=0' "$MTPROXY_ENV"
check "connection cap removed"    grep -qx 'MTPROXY_MAX_CONNECTIONS=0' "$MTPROXY_ENV"
check "hides an absent cap"       test "$(read_limits)" = "0 worker(s)"
cmd_limits -M 2 -C 8192 >/dev/null
check "reports a real limit"      test "$(read_limits)" = "2 worker(s), max 8192 connections"
cmd_limits -C 4096 >/dev/null
check "-C alone keeps workers"    grep -qx 'MTPROXY_WORKERS=2' "$MTPROXY_ENV"
check "-C alone sets the cap"     grep -qx 'MTPROXY_MAX_CONNECTIONS=4096' "$MTPROXY_ENV"
check "limits keep the secret"    grep -qx 'MTPROXY_SECRET=11111111111111111111111111111111' "$MTPROXY_ENV"
check "rejects 257 workers"       fails cmd_limits -M 257
check "rejects a negative cap"    fails cmd_limits -C -1
check "rejects an unknown flag"   fails cmd_limits -X 1
check "rejects a bare -M"         fails cmd_limits -M

check "reads the hostname" test "$(read_domain)" = proxy.example.com
check "builds the link"    test "$(tg_link)" = "https://t.me/webproxy?server=proxy.example.com&secret=$new"

# The sponsor tag is a systemd drop-in rebuilt from the unit's own ExecStart,
# so it must carry the upstream command line through unchanged and append -P.
MTPROXY_UNIT="$work/mtproxy.service"
TAG_DROPIN="$work/dropin.d/tag.conf"
printf '[Service]\nExecStart=/opt/MTProxy/objs/bin/mtproto-proxy -S ${MTPROXY_SECRET} -M 1\n' > "$MTPROXY_UNIT"

tag=aabbccddeeff00112233445566778899
cmd_sponsor "$tag" >/dev/null
check "drop-in clears ExecStart"  grep -qx 'ExecStart=' "$TAG_DROPIN"
check "drop-in keeps upstream"    grep -qF '/opt/MTProxy/objs/bin/mtproto-proxy -S ${MTPROXY_SECRET} -M 1 -P ${MTPROXY_TAG}' "$TAG_DROPIN"
check "drop-in sets the tag"      grep -qx "Environment=MTPROXY_TAG=$tag" "$TAG_DROPIN"
check "reads the tag back"        test "$(read_tag)" = "$tag"
cmd_sponsor AABBCCDDEEFF00112233445566778899 >/dev/null
check "uppercase tag lowercased"  test "$(read_tag)" = "$tag"
check "rejects a short tag"       fails cmd_sponsor abc123
check "rejects a dd-prefixed tag" fails cmd_sponsor "dd$tag"

cmd_sponsor off >/dev/null
check "off removes the drop-in"   test ! -e "$TAG_DROPIN"
check "no tag reads as absent"    no read_tag

# Publishing a cover site: the live directory is replaced, not the source.
SITE_ROOT="$work/srv-site"
printf '{\n  "public_hostname": "proxy.example.com",\n  "public_dir": "%s"\n}\n' "$SITE_ROOT" > "$CONFIG"
mkdir -p "$work/site-a/assets" "$work/site-b"
printf '<!doctype html><html><head><link rel="stylesheet" href="/s.css"></head><body>A</body></html>\n' > "$work/site-a/index.html"
printf 'body{margin:0}\n' > "$work/site-a/assets/s.css"
printf '<!doctype html><html><body>B</body></html>\n' > "$work/site-b/index.html"

cmd_site "$work/site-a" >/dev/null
check "publishes index.html"      grep -q '>A<' "$SITE_ROOT/index.html"
check "publishes nested assets"   test -f "$SITE_ROOT/assets/s.css"
check "reports the live dir"      test "$(cmd_site)" = "$SITE_ROOT (2 files)"

cmd_site "$work/site-b" >/dev/null
check "replaces the old site"     grep -q '>B<' "$SITE_ROOT/index.html"
check "drops the old assets"      test ! -e "$SITE_ROOT/assets/s.css"
check "keeps a backup"            test -n "$(find "$work" -maxdepth 1 -name 'srv-site.bak.*' -print -quit)"

check "needs an index.html"       fails cmd_site "$work/site-a/assets"
check "rejects a missing dir"     fails cmd_site "$work/nope"
check "rejects publishing itself" fails cmd_site "$SITE_ROOT"

# Carrier mode: the installer writes no carrier_mode key at all, so setting one
# has to insert the field, and setting it again must not duplicate it.
rm -f "$PROFILES"   # cmd_rotate left it 0400, as it is on a real install
printf '{"profiles":[{"name":"default","secret":"%s","backend":"127.0.0.1:2398"}]}\n' \
	"$new" > "$PROFILES"
check "absent key reads default"  test "$(cmd_mode)" = "https (default)"

cmd_mode websocket >/dev/null
check "inserts the mode"          test "$(cmd_mode)" = websocket
check "keeps the secret"          grep -qF "\"secret\":\"$new\"" "$PROFILES"
check "keeps the backend"         grep -qF '"backend":"127.0.0.1:2398"' "$PROFILES"

cmd_mode https-lanes >/dev/null
check "replaces, not duplicates"  test "$(grep -co 'carrier_mode' "$PROFILES")" = 1
check "reads the new mode"        test "$(cmd_mode)" = https-lanes
check "rejects an unknown mode"   fails cmd_mode ws

# Changing the hostname must touch both the relay config and the Caddy drop-in,
# and must refuse a name that does not point here unless forced.
CADDY_DROPIN="$work/caddy-tproxy.conf"
printf 'Environment=TPROXY_HOSTNAME=proxy.example.com\nEnvironment=ACME_EMAIL=you@example.com\n' > "$CADDY_DROPIN"
getent() { return 1; }   # nothing resolves, so the DNS guard is active

check "shows the hostname"        test "$(cmd_domain)" = proxy.example.com
check "refuses unresolved names"  fails cmd_domain new.example.com
check "refuses the same name"     fails cmd_domain proxy.example.com
check "rejects a bare label"      fails cmd_domain localhost --force

cmd_domain NEW.example.com --force >/dev/null
check "rewrites the relay config" grep -qF '"public_hostname": "new.example.com"' "$CONFIG"
check "rewrites the caddy dropin" grep -qx 'Environment=TPROXY_HOSTNAME=new.example.com' "$CADDY_DROPIN"
check "keeps the ACME e-mail"     test "$(read_email)" = you@example.com
check "link follows the domain"   test "$(tg_link)" = "https://t.me/webproxy?server=new.example.com&secret=$new"


# `webmtproxy update` re-runs install.sh, which is why anything the panel
# manages has to survive a re-run instead of falling back to install defaults.
TAG_DROPIN="$work/carry-tag.conf"
MTPROXY_ENV="$work/carry.env"
PROFILES="$work/carry.json"
printf 'Environment=MTPROXY_TAG=%s\n' aabbccddeeff00112233445566778899 > "$TAG_DROPIN"
printf 'MTPROXY_WORKERS=2\nMTPROXY_MAX_CONNECTIONS=8192\n' > "$MTPROXY_ENV"
printf '{"profiles":[{"backend":"127.0.0.1:2398","carrier_mode":"websocket"}]}\n' > "$PROFILES"

tag=; workers=; max_connections=; mode=
carry_forward
check "re-run keeps the tag"      test "$tag" = aabbccddeeff00112233445566778899
check "re-run keeps the workers"  test "$workers" = 2
check "re-run keeps the cap"      test "$max_connections" = 8192
check "re-run keeps the mode"     test "$mode" = websocket

tag=ffffffffffffffffffffffffffffffff; workers=9; max_connections=; mode=
carry_forward
check "a flag beats the carry"    test "$workers" = 9
check "a flag beats the tag"      test "$tag" = ffffffffffffffffffffffffffffffff

# A fresh host has none of those files: the defaults must be 0, not empty.
TAG_DROPIN="$work/none.conf"; MTPROXY_ENV="$work/none.env"; PROFILES="$work/none.json"
tag=; workers=; max_connections=; mode=
carry_forward
check "fresh install defaults"    test "$workers,$max_connections,$tag,$mode" = "0,0,,"

printf '\n  %d checks passed\n\n' "$ok"
