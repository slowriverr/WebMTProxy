<h1 align="center">WebMTProxy</h1>

<p align="center">
  Telegram's new <b>WEB proxy</b> on a fresh server — one command, then a CLI panel.
</p>

<p align="center">
  <img alt="shell" src="https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white">
  <img alt="platform" src="https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu%20x86__64-A81D33?logo=debian&logoColor=white">
  <img alt="tests" src="https://img.shields.io/badge/tests-29%20passing-brightgreen">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-blue">
</p>

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/slowriverr/WebMTProxy/main/install.sh)
```

That is the whole install. It asks for a domain and an e-mail, builds MTProxy and
the relay, gets a TLS certificate, and hands you a `t.me/webproxy` link and a QR
code. Then `webmtproxy` runs it.

---

## Why

Telegram's WEB proxy needs two projects wired together — the
[`tproxy-server`](https://github.com/telegramdesktop/tproxy-server) relay and a stock
[`MTProxy`](https://github.com/TelegramMessenger/MTProxy) backend — behind Caddy,
on a hostname that also has to look like a real website. Doing that by hand means
a dozen steps, three services, and one upstream bug that leaves the proxy dead on
arrival.

WebMTProxy is the installer and the control panel for that stack.

- **One command.** Domain, e-mail, secret, cover site, TLS, firewall, services.
- **Fails early, not late.** Checks root, architecture, systemd, that your A record
  actually points here, and that ports 80/443 are free — before touching anything.
- **Fixes the upstream `umask 077`.** It leaks into the MTProxy build and leaves
  `objs/bin/mtproto-proxy` mode `0700`, so the `mtproxy` service cannot execute it.
- **A real panel.** Service health, TLS expiry, live connections, secret rotation,
  logs, updates, clean uninstall.
- **No hidden state.** The panel reads the hostname and secret from the files the
  deploy scripts write. Nothing to drift, nothing to keep in sync.

```text
Telegram app ──WebView/HTTPS──▶ Caddy ──▶ tproxy-server ──▶ MTProxy ──▶ Telegram
                                  └── every other request: your cover website
```

## Requirements

|  | |
| --- | --- |
| **Server** | Debian or Ubuntu, **x86_64**, systemd, root — the stock MTProxy build requires x86_64 |
| **DNS** | an A record for your hostname pointing at the server, already propagated |
| **Ports** | 80 and 443 free — Caddy needs both for ACME and for serving |

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

Expect 5–15 minutes: MTProxy is compiled from source, the Go relay is built, and
Let's Encrypt issues a certificate. Progress is on screen, full output in
`/var/log/webmtproxy-install.log`.

<details>
<summary><b>All installer flags</b></summary>

| Flag | Meaning |
| --- | --- |
| `-d, --domain HOST` | public hostname, e.g. `proxy.example.com` |
| `-e, --email ADDR` | contact e-mail for Let's Encrypt |
| `-s, --secret HEX` | 32 hex chars, optionally `dd`-prefixed (default: random) |
| `--site-dir DIR` | serve this directory as the cover website |
| `--site-upstream URL` | proxy the cover website to `http://127.0.0.1:PORT` |
| `--workers N` | MTProxy workers (default 1) |
| `--max-connections N` | MTProxy max connections (default 4096) |
| `-y, --yes` | no prompts, no confirmation |
| `-v, --verbose` | stream the build output instead of a spinner |

Anything not passed is asked for interactively.

</details>

## The panel

```console
$ sudo webmtproxy

  ╭────────────────────────────────────────────────────╮
  │ WebMTProxy                                         │
  │ proxy.example.com                            online │
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

    https://t.me/webproxy?server=proxy.example.com&secret=dd7f3c1e…
```

| Command | What it does |
| --- | --- |
| `webmtproxy` | the panel above |
| `webmtproxy link` | print the `t.me/webproxy` link |
| `webmtproxy qr` | print it as a QR code |
| `webmtproxy rotate-secret [HEX]` | new secret, restart, print the new link |
| `webmtproxy restart` | restart mtproxy, relay and Caddy |
| `webmtproxy logs` | follow all three journals |
| `webmtproxy update` | pull WebMTProxy, rebuild from upstream |
| `webmtproxy uninstall [--purge]` | remove everything |

`uninstall` keeps `/srv/tproxy-site` and `/var/lib/caddy` unless you pass
`--purge` — re-issuing certificates burns Let's Encrypt rate limits.

## The cover website

Your hostname stays an ordinary HTTPS site. Only a request carrying the capability
derived from the hostname and the secret gets the bridge page; everything else gets
the cover site. The installer drops a placeholder there, but a placeholder is a
tell — point `--site-dir` at something plausible.

```bash
sudo ./install.sh -d proxy.example.com -e you@example.com --site-dir /opt/my-site
```

## Development

```bash
./test_install.sh
```

29 checks over input validation, the upstream umask patch (including the fallback
for when those lines move), and secret rotation across both config files.

Set `WEBMTPROXY_REPO`, or edit the `REPO` line in `install.sh`, to point the
bootstrap and `webmtproxy update` at your own fork.

## Credits and licence

WebMTProxy is the installer and the panel. The proxy itself is
[`telegramdesktop/tproxy-server`](https://github.com/telegramdesktop/tproxy-server)
and [`TelegramMessenger/MTProxy`](https://github.com/TelegramMessenger/MTProxy),
fetched and built at install time — neither is vendored here, so upstream fixes
arrive on the next `webmtproxy update`.

The scripts in this repository are MIT-licensed. That covers this repository only,
not the upstream projects, which carry their own terms.

---

<div dir="rtl">

## فارسی

نصب پروکسی جدید تلگرام (WEB proxy) روی یک سرور تازه با یک دستور، به‌همراه پنل
مدیریت خط فرمان.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/slowriverr/WebMTProxy/main/install.sh)
```

**پیش‌نیازها:** سرور Debian یا Ubuntu روی معماری **x86_64** با systemd و دسترسی
روت، رکورد A دامنه که به همان سرور اشاره کند، و آزاد بودن پورت‌های ۸۰ و ۴۴۳.

نصب‌کننده دامنه و ایمیل را می‌پرسد، سکرت تصادفی می‌سازد، MTProxy و رله را بیلد
می‌کند، گواهی TLS می‌گیرد و در پایان QR و لینک `t.me/webproxy` را نشان می‌دهد.
حدود ۵ تا ۱۵ دقیقه طول می‌کشد و لاگ کامل در `/var/log/webmtproxy-install.log`
است.

بعد از نصب، دستور `webmtproxy` پنل مدیریت را باز می‌کند: وضعیت سرویس‌ها، سلامت
رله و سایت، اعتبار گواهی، تعداد اتصال‌های فعال و لینک. زیردستورها: `link`،
`qr`، `rotate-secret`، `restart`، `logs`، `update` و `uninstall`.

دامنه همچنان یک وب‌سایت معمولی HTTPS باقی می‌ماند و فقط درخواستی که سکرت درست را
داشته باشد به پروکسی می‌رسد؛ بقیه سایت پوششی را می‌بینند. سایت پیش‌فرض یک صفحه
خالی است و همین خودش نشانه است — با `--site-dir` یک سایت باورپذیر بگذارید.

</div>
