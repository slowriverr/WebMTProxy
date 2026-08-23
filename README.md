<h1 align="center">WebMTProxy</h1>

<p align="center">
  Telegram's new <b>WEB proxy</b>, installed in one command —
  with a CLI panel and <b>sponsor channel</b> support.
</p>

<p align="center">
  <b>English</b> ·
  <a href="README.fa.md">فارسی</a> ·
  <a href="README.ru.md">Русский</a>
</p>

<p align="center">
  <img alt="shell" src="https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white">
  <img alt="platform" src="https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu%20x86__64-A81D33?logo=debian&logoColor=white">
  <img alt="tests" src="https://img.shields.io/badge/tests-57%20passing-brightgreen">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-blue">
</p>

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/slowriverr/WebMTProxy/main/install.sh)
```

That is the whole install. It asks for a domain and an e-mail, builds everything,
gets a TLS certificate, and hands you a `t.me/webproxy` link and a QR code.

---

## What you get

- **One command.** Domain, e-mail, secret, cover site, TLS, firewall, services.
- **Fails early, not late.** Root, architecture, systemd, whether your A record
  actually points here, whether ports 80/443 are free — all checked before
  anything is touched.
- **Works on the first try.** A permissions bug that otherwise leaves the proxy
  dead on arrival is patched during install.
- **Sponsor channel.** Attach an [@MTProxybot](https://t.me/MTProxybot) ad tag —
  the upstream deploy has no flag for it. Off by default, one command to change.
- **A real panel.** Service health, TLS expiry, live connections, secret rotation,
  logs, updates, clean uninstall.
- **No hidden state.** The panel reads everything from the live config files.
  Nothing to drift, nothing to keep in sync.

```text
Telegram app ──WebView / HTTPS──▶ your domain ──▶ backend ──▶ Telegram
                                       └── every other request: your website
```

## Requirements

|  | |
| --- | --- |
| **Server** | Debian or Ubuntu, **x86_64**, systemd, root |
| **DNS** | an A record for your hostname pointing at the server, already propagated |
| **Ports** | 80 and 443 free |

## Install

```bash
git clone https://github.com/slowriverr/WebMTProxy
cd WebMTProxy
sudo ./install.sh
```

Non-interactive:

```bash
sudo ./install.sh --domain proxy.example.com --email you@example.com --yes
```

Expect 5–15 minutes — everything is compiled from source and a certificate is
issued. Progress is on screen, full output in `/var/log/webmtproxy-install.log`.

<details>
<summary><b>All installer flags</b></summary>

| Flag | Meaning |
| --- | --- |
| `-d, --domain HOST` | public hostname, e.g. `proxy.example.com` |
| `-e, --email ADDR` | contact e-mail for Let's Encrypt |
| `-s, --secret HEX` | 32 hex chars, optionally `dd`-prefixed — if omitted you are asked |
| `-t, --tag HEX` | sponsor channel tag from [@MTProxybot](https://t.me/MTProxybot) (default: none) |
| `--site-dir DIR` | serve this directory as the cover website |
| `--site-upstream URL` | proxy the cover website to `http://127.0.0.1:PORT` |
| `--workers N` | worker processes (default 1) |
| `--max-connections N` | max connections (default 4096) |
| `-y, --yes` | no prompts, no confirmation |
| `-v, --verbose` | stream the build output instead of a spinner |

Anything not passed is asked for interactively.

</details>

## The panel

```console
$ sudo webmtproxy

  ╭────────────────────────────────────────────────────╮
  │ WebMTProxy                                         │
  │ proxy.example.com                           online │
  ╰────────────────────────────────────────────────────╯

  SERVICES
    ● caddy              active     up 3d 4h
    ● mtproxy            active     up 3d 4h
    ● tproxy-server      active     up 3d 4h
    ● tproxy-firewall    active     up 3d 4h

  HEALTH
    relay          ready
    website        200
    tls            valid, 67d left
    clients        12 established on :443

  ACCESS
    secret         dd7f3c1e9a2b48d05e6f81c34a9b2d7e
    email          you@example.com
    sponsor        none
    carrier        https (default)

    https://t.me/webproxy?server=proxy.example.com&secret=dd7f3c1e…
```

| Command | What it does |
| --- | --- |
| `webmtproxy` | the panel above |
| `webmtproxy link` | print the `t.me/webproxy` link |
| `webmtproxy qr` | print it as a QR code |
| `webmtproxy rotate-secret [HEX]` | new secret, restart, print the new link |
| `webmtproxy sponsor [TAG]` | show, set, or clear (`off`) the sponsor channel tag |
| `webmtproxy site [DIR]` | show the live cover site, or publish `DIR` as it |
| `webmtproxy mode [MODE]` | carrier transport: `https`, `https-lanes`, `websocket`, `websocket-lanes` |
| `webmtproxy restart` | restart every service |
| `webmtproxy logs` | follow all journals |
| `webmtproxy update` | pull the latest and rebuild |
| `webmtproxy uninstall [--purge]` | remove everything |

`uninstall` keeps `/srv/tproxy-site` and `/var/lib/caddy` unless you pass
`--purge` — re-issuing certificates burns Let's Encrypt rate limits.

## Sponsor channel

Off by default. Register the proxy with [@MTProxybot](https://t.me/MTProxybot),
take the tag it gives you, and:

```bash
sudo webmtproxy sponsor aabbccddeeff00112233445566778899
sudo webmtproxy sponsor off
```

The tag is applied as a systemd drop-in rebuilt from the service's own command
line, so it survives updates. One caveat worth knowing: @MTProxybot registers a
`host:port`, and here clients reach you over HTTPS on your domain rather than
that port — the tag is passed to the backend, but treat sponsored-channel
delivery as best-effort until you have seen it work.

## Carrier transport

The WebView can carry a session four ways. `https` is the default; the others
trade a different traffic shape for the same payload, which matters when one
shape is being throttled.

```bash
sudo webmtproxy mode websocket
sudo webmtproxy mode              # what is set now
```

| Mode | Shape |
| --- | --- |
| `https` | one serialized HTTPS carrier |
| `https-lanes` | independent HTTPS request lanes per logical session |
| `websocket` | one multiplexed WebSocket |
| `websocket-lanes` | an independent WebSocket per logical session |

Clients pick the new mode up on their next session; nothing needs reinstalling.

## The cover website

Your hostname stays an ordinary HTTPS site. Only a request carrying the capability
derived from the hostname and the secret reaches the proxy; everything else gets
the cover site. The installer drops a placeholder there, but a placeholder is a
tell — point `--site-dir` at something plausible.

```bash
sudo ./install.sh -d proxy.example.com -e you@example.com --site-dir /opt/my-site
```

To change it later, publish a directory over the live one:

```bash
sudo webmtproxy site /opt/my-site
sudo webmtproxy site                    # what is live right now
```

The relay loads the whole site into memory at startup, so editing the directory
you installed from changes nothing — `site` replaces the live copy, keeps the
previous one at `/srv/tproxy-site.bak.<timestamp>`, and restarts the relay. It
also warns about the things the response policy blocks: inline `<style>` and
`<script>`, external resources, and symlinks.

## Development

```bash
./test_install.sh
```

57 checks over input validation, the install-time patch, secret rotation, the
sponsor drop-in, site publishing and carrier mode.
Set `WEBMTPROXY_REPO` to point the bootstrap and `webmtproxy update` at a fork.

## Credits

Built on [tproxy-server](https://github.com/telegramdesktop/tproxy-server) and
[MTProxy](https://github.com/TelegramMessenger/MTProxy), fetched at install time
rather than vendored. MIT-licensed; the upstream projects carry their own terms.
