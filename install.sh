#!/usr/bin/env bash
# WebMTProxy — one-command installer for Telegram's WEB proxy.
#
# Wraps telegramdesktop/tproxy-server, whose deploy script already fetches,
# builds and wires up TelegramMessenger/MTProxy as the backend. This adds
# preflight checks, an interactive CLI, and the umask fix the upstream script
# needs (it runs the MTProxy build under `umask 077`, which leaves
# objs/bin/mtproto-proxy mode 0700 and the mtproxy service unable to exec it).
set -euo pipefail

UPSTREAM=https://github.com/telegramdesktop/tproxy-server
CHECKOUT=/opt/tproxy-server
HOME_DIR=/opt/webmtproxy
DEFAULT_SITE=/opt/webmtproxy-site
LOG=/var/log/webmtproxy-install.log

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)" || SELF_DIR=/nonexistent
# Where `webmtproxy update` and the piped one-liner pull from. Point this at
# your own fork, or export WEBMTPROXY_REPO.
REPO="${WEBMTPROXY_REPO:-$(git -C "$SELF_DIR" remote get-url origin 2>/dev/null ||
	echo https://github.com/slowriverr/WebMTProxy)}"

domain=; email=; secret=; tag=; site_dir=; site_upstream=
workers=0; max_connections=0; assume_yes=0; verbose=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
	B=$'\e[1m'; D=$'\e[2m'; R=$'\e[0m'
	RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; CYN=$'\e[36m'; TTY=1
else
	B=; D=; R=; RED=; GRN=; YLW=; CYN=; TTY=0
fi

info() { printf '  %s•%s %s\n' "$CYN" "$R" "$*"; }
warn() { printf '  %s!%s %s\n' "$YLW" "$R" "$*"; }
die()  { printf '\n  %s✗%s %s\n\n' "$RED" "$R" "$*" >&2; exit 1; }

banner() {
	printf '\n'
	printf '  %s╭────────────────────────────────────────────────╮%s\n' "$CYN" "$R"
	printf '  %s│%s  %sWebMTProxy%s  ·  Telegram WEB proxy installer   %s│%s\n' "$CYN" "$R" "$B" "$R" "$CYN" "$R"
	printf '  %s│%s  %stproxy-server + MTProxy, one command%s          %s│%s\n' "$CYN" "$R" "$D" "$R" "$CYN" "$R"
	printf '  %s╰────────────────────────────────────────────────╯%s\n\n' "$CYN" "$R"
}

usage() {
	cat <<-EOF

	  ${B}usage${R}  sudo ./install.sh [options]

	    -d, --domain HOST          public hostname, e.g. proxy.example.com
	    -e, --email ADDR           contact e-mail for Let's Encrypt
	    -s, --secret HEX           32 hex chars, optionally dd-prefixed (default: asked)
	    -t, --tag HEX              sponsor channel tag from @MTProxybot (default: none)
	        --site-dir DIR         serve this directory as the cover website
	        --site-upstream URL    proxy the cover website to http://127.0.0.1:PORT
	        --workers N            MTProxy workers, 0 = single process (default 0)
	        --max-connections N    MTProxy connection cap, 0 = none (default 0)
	    -y, --yes                  no prompts, no confirmation
	    -v, --verbose              stream the build output instead of a spinner
	    -h, --help                 this text

	  Anything not given on the command line is asked for interactively.

	EOF
}

# ── helpers ──────────────────────────────────────────────────────────────────

valid_domain() { [[ "$1" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ && "$1" == *.* ]]; }
valid_email()  { [[ "$1" =~ ^[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; }
valid_secret() { [[ "$1" =~ ^([0-9a-f]{32}|dd[0-9a-f]{32})$ ]]; }
# Same rule, but tolerant of a pasted uppercase secret; it is lowercased after.
valid_secret_input() { valid_secret "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; }
gen_secret()   { openssl rand -hex 16 2>/dev/null || od -An -tx1 -N16 /dev/urandom | tr -d ' \n'; }

# prompt VAR "label" "hint" validator
prompt() {
	local var=$1 label=$2 hint=$3 check=$4 value
	[[ $assume_yes -eq 1 ]] && die "missing --${var//_/-} (running with --yes)"
	[[ -t 0 ]] || die "missing --${var//_/-} and stdin is not a terminal"
	while :; do
		printf '  %s?%s %s %s%s%s ' "$CYN" "$R" "$label" "$D" "$hint" "$R"
		read -r value </dev/tty || die "aborted"
		value="${value//[[:space:]]/}"
		"$check" "$value" && break
		warn "invalid value, try again"
	done
	printf -v "$var" '%s' "$value"
}

prepare_site() {
	[[ -z "$site_dir$site_upstream" ]] || return 0
	[[ ! -f /srv/tproxy-site/index.html ]] || return 0
	install -d -m 0755 "$DEFAULT_SITE"
	cat > "$DEFAULT_SITE/index.html" <<-'HTML'
		<!doctype html>
		<html lang="en">
		<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
		<title>Notes</title><link rel="stylesheet" href="/styles.css"></head>
		<body><h1>Notes</h1><p>Personal notes and projects.</p></body>
		</html>
	HTML
	cat > "$DEFAULT_SITE/styles.css" <<-'CSS'
		body{font-family:system-ui,sans-serif;max-width:40rem;margin:4rem auto;padding:0 1rem;line-height:1.6}
	CSS
	chmod 0644 "$DEFAULT_SITE/index.html" "$DEFAULT_SITE/styles.css"
}

fetch_upstream() {
	rm -rf "$CHECKOUT"
	git clone -q "$UPSTREAM" "$CHECKOUT"
}

# Upstream sets `umask 077` at the top of deploy/install.sh. That mode leaks
# into the MTProxy make and the `go test` run, so the resulting binaries and
# caches come out 0700 and the mtproxy service cannot execute them. Re-open
# just those two subshells; if upstream moved the lines, relax the umask
# globally instead — every secret it writes gets an explicit chmod anyway.
patch_umask() {
	local f="${1:-$CHECKOUT/deploy/install.sh}" tmp
	tmp="$(mktemp "$f.XXXXXX")"
	sed \
		-e 's|^"\$repository/deploy/install-mtproxy.sh"$|(umask 022; "$repository/deploy/install-mtproxy.sh")|' \
		-e 's|^(cd "\$repository" \&\& "\$go_binary" test \./\.\.\.)$|(umask 022; cd "$repository" \&\& "$go_binary" test ./...)|' \
		"$f" > "$tmp"
	if [[ "$(grep -c 'umask 022' "$tmp")" -ne 2 ]]; then
		echo "line patch did not apply; falling back to a global umask 022" >&2
		sed 's|^umask 077$|umask 022|' "$f" > "$tmp"
		grep -q '^umask 022$' "$tmp" || { rm -f "$tmp"; echo "could not relax the umask in $f" >&2; return 1; }
	fi
	bash -n "$tmp" || { rm -f "$tmp"; echo "patched $f is not valid bash" >&2; return 1; }
	chmod --reference="$f" "$tmp" 2>/dev/null || chmod 0755 "$tmp"
	mv -f "$tmp" "$f"
}

run_upstream() {
	# Upstream's deploy script rejects 0 for either knob, so it gets its own
	# defaults here and `webmtproxy -M N -C N` writes the real values after.
	local args=(--hostname "$domain" --email "$email" --secret "$secret"
		--mtproxy-workers "$((workers > 0 ? workers : 1))"
		--mtproxy-max-connections "$((max_connections > 0 ? max_connections : 4096))")
	if   [[ -n "$site_upstream" ]]; then args+=(--site-upstream "$site_upstream")
	elif [[ -n "$site_dir"      ]]; then args+=(--site-dir "$site_dir")
	elif [[ ! -f /srv/tproxy-site/index.html ]]; then args+=(--site-dir "$DEFAULT_SITE")
	fi
	"$CHECKOUT/deploy/install.sh" "${args[@]}"
}

# Keep a checkout at $HOME_DIR so `webmtproxy update` has something to pull.
install_panel() {
	if [[ "$SELF_DIR" != "$HOME_DIR" ]]; then
		rm -rf "$HOME_DIR"
		install -d -m 0755 "$HOME_DIR"
		cp -a "$SELF_DIR/." "$HOME_DIR/"
	fi
	chmod 0755 "$HOME_DIR/install.sh" "$HOME_DIR/webmtproxy"
	install -m 0755 "$HOME_DIR/webmtproxy" /usr/local/bin/webmtproxy
}

verify() {
	local unit
	for unit in mtproxy tproxy-server caddy; do
		systemctl is-active --quiet "$unit" ||
			{ systemctl --no-pager --full status "$unit" || true; return 1; }
	done
	curl --fail --silent --output /dev/null --max-time 10 http://127.0.0.1:8081/readyz
}

fail() {
	printf '\r  %s✗%s %s\n' "$RED" "$R" "$1"
	if [[ -s "$LOG" ]]; then
		printf '\n%s  last lines of %s:%s\n' "$D" "$LOG" "$R"
		tail -n 25 "$LOG" | while IFS= read -r line; do printf '    %s%s%s\n' "$D" "$line" "$R"; done
	fi
	printf '\n'
	exit 1
}

STEP=0; TOTAL=9
step() {
	local msg=$1; shift
	STEP=$((STEP + 1))
	local label
	printf -v label '%s[%d/%d]%s %s' "$D" "$STEP" "$TOTAL" "$R" "$msg"

	if [[ $verbose -eq 1 || $TTY -eq 0 ]]; then
		printf '  %s\n' "$label"
		"$@" >>"$LOG" 2>&1 < /dev/null || fail "$msg"
		printf '  %s✓%s %s\n' "$GRN" "$R" "$label"
		return
	fi

	local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) i=0 start=$SECONDS pid rc=0
	"$@" >>"$LOG" 2>&1 < /dev/null &
	pid=$!
	printf '\e[?25l'
	while kill -0 "$pid" 2>/dev/null; do
		printf '\r  %s%s%s %s %s(%dm%02ds)%s\e[K' \
			"$CYN" "${frames[i++ % 10]}" "$R" "$label" \
			"$D" $(( (SECONDS - start) / 60 )) $(( (SECONDS - start) % 60 )) "$R"
		sleep 0.1
	done
	wait "$pid" || rc=$?
	printf '\e[?25h\r\e[K'
	[[ $rc -eq 0 ]] || fail "$msg"
	printf '  %s✓%s %s %s(%dm%02ds)%s\n' "$GRN" "$R" "$label" \
		"$D" $(( (SECONDS - start) / 60 )) $(( (SECONDS - start) % 60 )) "$R"
}

# Sourced by test_install.sh, which wants the helpers without the install.
[[ "${WEBMTPROXY_LIB:-}" == 1 ]] && return 0

# ── arguments ────────────────────────────────────────────────────────────────

ARGS=("$@")   # kept intact for the curl-bootstrap re-exec below

while [[ $# -gt 0 ]]; do
	case "$1" in
		-d|--domain)          domain="${2:-}"; shift 2 ;;
		-e|--email)           email="${2:-}"; shift 2 ;;
		-s|--secret)          secret="${2:-}"; shift 2 ;;
		-t|--tag)             tag="${2:-}"; shift 2 ;;
		--site-dir)           site_dir="${2:-}"; shift 2 ;;
		--site-upstream)      site_upstream="${2:-}"; shift 2 ;;
		--workers)            workers="${2:-}"; shift 2 ;;
		--max-connections)    max_connections="${2:-}"; shift 2 ;;
		-y|--yes)             assume_yes=1; shift ;;
		-v|--verbose)         verbose=1; shift ;;
		-h|--help)            usage; exit 0 ;;
		*) usage; die "unknown option: $1" ;;
	esac
done

# ── preflight ────────────────────────────────────────────────────────────────

banner

[[ ${EUID} -eq 0 ]]           || die "run as root: sudo ./install.sh"
[[ "$(uname -s)" == Linux ]]  || die "this installer targets Linux (Debian/Ubuntu)"
[[ "$(uname -m)" == x86_64 ]] || die "the stock official MTProxy build requires an x86_64 server"
command -v apt-get >/dev/null   || die "no apt-get; this installer targets Debian/Ubuntu"
command -v systemctl >/dev/null || die "no systemd; the upstream units need it"
[[ -n "$site_dir" && -n "$site_upstream" ]] && die "--site-dir and --site-upstream are mutually exclusive"

# Piped straight from curl: there is no checkout to install the panel from, so
# fetch one and hand over to it.
if [[ ! -f "$SELF_DIR/webmtproxy" ]]; then
	info "bootstrapping from $REPO"
	command -v git >/dev/null ||
		{ apt-get update -qq && apt-get install -y -qq --no-install-recommends git; } ||
		die "could not install git"
	rm -rf "$HOME_DIR"
	git clone -q "$REPO" "$HOME_DIR" ||
		die "could not clone $REPO — set WEBMTPROXY_REPO to your fork"
	exec bash "$HOME_DIR/install.sh" ${ARGS[@]+"${ARGS[@]}"}
fi

# ── input ────────────────────────────────────────────────────────────────────

[[ -n "$domain" ]] || prompt domain "Domain      " "(proxy.example.com)" valid_domain
[[ -n "$email"  ]] || prompt email  "ACME e-mail " "(you@example.com)"    valid_email
if [[ -z "$secret" ]]; then
	if [[ $assume_yes -eq 1 ]] || [[ ! -t 0 ]]; then
		secret="$(gen_secret)"
	else
		printf '  %s?%s Secret       %s[Y] generate a random one · [n] I have my own%s ' \
			"$CYN" "$R" "$D" "$R"
		read -r reply </dev/tty || true
		if [[ "$reply" =~ ^[Nn] ]]; then
			prompt secret "Secret      " "(32 hex, optionally dd-prefixed)" valid_secret_input
		else
			secret="$(gen_secret)"
		fi
	fi
fi
secret="$(printf '%s' "$secret" | tr '[:upper:]' '[:lower:]')"

if [[ -z "$tag" ]] && [[ $assume_yes -eq 0 ]] && [[ -t 0 ]]; then
	printf '  %s?%s Sponsor tag  %s[Enter] none · or the 32 hex tag from @MTProxybot%s ' \
		"$CYN" "$R" "$D" "$R"
	read -r tag </dev/tty || true
	tag="${tag//[[:space:]]/}"
fi
tag="$(printf '%s' "$tag" | tr '[:upper:]' '[:lower:]')"
[[ -z "$tag" || "$tag" =~ ^[0-9a-f]{32}$ ]] || die "--tag must be 32 hex characters"

valid_domain "$domain" || die "hostname must be a lowercase ASCII DNS hostname with a dot"
valid_email  "$email"  || die "a valid ACME contact e-mail is required"
valid_secret "$secret" || die "secret must be 32 lowercase hex chars, optionally dd-prefixed"
[[ "$workers" =~ ^[0-9]+$ && $workers -le 256 ]] ||
	die "--workers must be 0..256 — 0 runs MTProxy in a single process"
[[ "$max_connections" =~ ^[0-9]+$ ]] ||
	die "--max-connections must be a number — 0 removes the limit"
if [[ -n "$site_dir" ]]; then
	[[ -r "$site_dir/index.html" ]] || die "--site-dir must contain a readable index.html"
	site_dir="$(cd "$site_dir" && pwd -P)"
fi
if [[ -n "$site_upstream" ]]; then
	[[ "$site_upstream" =~ ^http://(127\.[0-9]+\.[0-9]+\.[0-9]+|\[::1\]):[1-9][0-9]{0,4}$ ]] ||
		die "--site-upstream must be http:// plus a numeric loopback address and port"
fi

# DNS and port checks are advisory: the ACME challenge is what actually needs
# :80/:443 free and the A record pointing here, and it fails late and cryptically.
if resolved="$(getent ahostsv4 "$domain" 2>/dev/null | awk 'NR==1{print $1}')" && [[ -n "$resolved" ]]; then
	if ! ip -4 -o addr show scope global 2>/dev/null |
		awk '{split($4,a,"/"); print a[1]}' | grep -qx "$resolved"; then
		warn "$domain resolves to $resolved, which is not an address on this host"
		warn "TLS issuance fails unless that is a NAT/anycast address for this server"
	fi
else
	warn "$domain does not resolve yet — point its A record here before continuing"
fi
if command -v ss >/dev/null; then
	busy="$(ss -ltnH 2>/dev/null |
		awk '{n=split($4,a,":"); if (a[n]==80 || a[n]==443) print a[n]}' | sort -u | tr '\n' ' ')"
	[[ -n "${busy// /}" ]] && warn "ports already in use: ${busy}— Caddy needs 80 and 443"
fi

if   [[ -n "$site_dir"      ]]; then site_label="$site_dir"
elif [[ -n "$site_upstream" ]]; then site_label="$site_upstream (upstream)"
elif [[ -f /srv/tproxy-site/index.html ]]; then site_label="/srv/tproxy-site (existing)"
else site_label="$DEFAULT_SITE (generated placeholder)"; fi

printf '\n'
printf '  %sDomain%s      %s\n' "$D" "$R" "$domain"
printf '  %sE-mail%s      %s\n' "$D" "$R" "$email"
printf '  %sSecret%s      %s\n' "$D" "$R" "$secret"
printf '  %sSponsor%s     %s\n' "$D" "$R" "${tag:-none}"
printf '  %sCover site%s  %s\n' "$D" "$R" "$site_label"
if ((max_connections > 0)); then conn_label="max $max_connections connections"
else conn_label="no connection limit"; fi
printf '  %sMTProxy%s     %s worker(s), %s\n' "$D" "$R" "$workers" "$conn_label"
printf '  %sLog%s         %s\n\n' "$D" "$R" "$LOG"

if [[ $assume_yes -eq 0 ]]; then
	[[ -t 0 ]] || die "not a terminal; pass --yes to skip the confirmation"
	printf '  %s?%s Install with these settings? %s[Y/n]%s ' "$CYN" "$R" "$D" "$R"
	read -r reply </dev/tty || true
	[[ -z "$reply" || "$reply" =~ ^[Yy] ]] || die "aborted"
	printf '\n'
fi

# ── install ──────────────────────────────────────────────────────────────────

: > "$LOG"; chmod 0600 "$LOG"
export DEBIAN_FRONTEND=noninteractive
trap 'printf "\e[?25h"' EXIT

step "Installing prerequisites"        bash -c 'apt-get update && apt-get install -y --no-install-recommends git ca-certificates curl qrencode'
step "Preparing the cover website"     prepare_site
step "Fetching tproxy-server"          fetch_upstream
step "Patching the deploy script"      patch_umask
step "Building MTProxy, relay and TLS" run_upstream
step "Installing the webmtproxy panel" install_panel
step "Applying the MTProxy limits"      /usr/local/bin/webmtproxy -M "$workers" -C "$max_connections"
step "Configuring the sponsor channel" /usr/local/bin/webmtproxy sponsor "${tag:-off}"
step "Verifying services"              verify

# ── result ───────────────────────────────────────────────────────────────────

link="https://t.me/webproxy?server=${domain}&secret=${secret}"

printf '\n'
printf '  %s╭────────────────────────────────────────────────╮%s\n' "$GRN" "$R"
printf '  %s│%s  %sWEB proxy is up%s                               %s│%s\n' "$GRN" "$R" "$B" "$R" "$GRN" "$R"
printf '  %s╰────────────────────────────────────────────────╯%s\n\n' "$GRN" "$R"
command -v qrencode >/dev/null && { qrencode -t UTF8 -m 2 "$link"; printf '\n'; }
printf '  %s%s%s\n\n' "$CYN" "$link" "$R"
printf '  %sHostname%s  %s\n' "$D" "$R" "$domain"
printf '  %sSecret%s    %s\n' "$D" "$R" "$secret"
printf '  %sWebsite%s   https://%s/\n' "$D" "$R" "$domain"
printf '  %sPanel%s     %swebmtproxy%s   (link · qr · rotate-secret · logs · update)\n\n' \
	"$D" "$R" "$B" "$R"
