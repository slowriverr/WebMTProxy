<h1 align="center">WebMTProxy</h1>

<p align="center">
  پروکسی جدید تلگرام (<b>WEB proxy</b>) با یک دستور —
  به‌همراه پنل خط فرمان و پشتیبانی از <b>کانال اسپانسر</b>.
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <b>فارسی</b> ·
  <a href="README.ru.md">Русский</a>
</p>

<p align="center">
  <img alt="shell" src="https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white">
  <img alt="platform" src="https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu%20x86__64-A81D33?logo=debian&logoColor=white">
  <img alt="tests" src="https://img.shields.io/badge/tests-50%20passing-brightgreen">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-blue">
</p>

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/slowriverr/WebMTProxy/main/install.sh)
```

<div dir="rtl">

کل نصب همین است. دامنه و ایمیل را می‌پرسد، همه‌چیز را بیلد می‌کند، گواهی TLS
می‌گیرد و در پایان لینک `t.me/webproxy` و کد QR را تحویل می‌دهد.

---

## چه چیزی می‌گیری

- **یک دستور.** دامنه، ایمیل، سکرت، سایت پوششی، TLS، فایروال و سرویس‌ها.
- **زود خطا می‌دهد، نه دیر.** روت بودن، معماری، systemd، اینکه رکورد A واقعاً به
  همین سرور اشاره می‌کند و اینکه پورت‌های ۸۰ و ۴۴۳ آزادند — همه پیش از دست‌زدن
  به چیزی بررسی می‌شوند.
- **بار اول کار می‌کند.** یک باگ دسترسی که در حالت عادی پروکسی را همان اول
  از کار می‌اندازد، حین نصب اصلاح می‌شود.
- **کانال اسپانسر.** می‌توانی تگ تبلیغاتی [@MTProxybot](https://t.me/MTProxybot)
  را وصل کنی — چیزی که نصب‌کننده‌ی اصلی اصلاً فلگی برایش ندارد. پیش‌فرض خاموش،
  با یک دستور روشن.
- **یک پنل واقعی.** سلامت سرویس‌ها، اعتبار گواهی، اتصال‌های زنده، چرخش سکرت،
  لاگ‌ها، آپدیت و حذف تمیز.
- **بدون state پنهان.** پنل همه‌چیز را از فایل‌های پیکربندی زنده می‌خواند؛ چیزی
  drift نمی‌کند و چیزی لازم نیست هم‌گام نگه داشته شود.

</div>

```text
Telegram app ──WebView / HTTPS──▶ your domain ──▶ backend ──▶ Telegram
                                       └── every other request: your website
```

<div dir="rtl">

## پیش‌نیازها

|  | |
| --- | --- |
| **سرور** | Debian یا Ubuntu، معماری **x86_64**، systemd، دسترسی روت |
| **DNS** | رکورد A دامنه که به همان سرور اشاره کند و منتشر شده باشد |
| **پورت** | ۸۰ و ۴۴۳ آزاد |

## نصب

</div>

```bash
git clone https://github.com/slowriverr/WebMTProxy
cd WebMTProxy
sudo ./install.sh
```

<div dir="rtl">

بدون تعامل:

</div>

```bash
sudo ./install.sh --domain proxy.example.com --email you@example.com --yes
```

<div dir="rtl">

بین ۵ تا ۱۵ دقیقه طول می‌کشد — همه‌چیز از سورس کامپایل می‌شود و گواهی صادر
می‌گردد. پیشرفت روی صفحه است و خروجی کامل در
`/var/log/webmtproxy-install.log`.

<details>
<summary><b>همه فلگ‌های نصب‌کننده</b></summary>

| فلگ | معنی |
| --- | --- |
| `-d, --domain HOST` | نام دامنه عمومی، مثلاً `proxy.example.com` |
| `-e, --email ADDR` | ایمیل تماس برای Let's Encrypt |
| `-s, --secret HEX` | ۳۲ کاراکتر hex، اختیاراً با پیشوند `dd` — اگر ندهی پرسیده می‌شود |
| `-t, --tag HEX` | تگ کانال اسپانسر از [@MTProxybot](https://t.me/MTProxybot) (پیش‌فرض: ندارد) |
| `--site-dir DIR` | این پوشه به‌عنوان سایت پوششی سرو شود |
| `--site-upstream URL` | سایت پوششی از `http://127.0.0.1:PORT` پروکسی شود |
| `--workers N` | تعداد ورکرها (پیش‌فرض ۱) |
| `--max-connections N` | حداکثر اتصال (پیش‌فرض ۴۰۹۶) |
| `-y, --yes` | بدون سؤال و بدون تأیید |
| `-v, --verbose` | نمایش خروجی بیلد به‌جای اسپینر |

هر چیزی که ندهی، به‌صورت تعاملی پرسیده می‌شود.

</details>

## پنل

</div>

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

    https://t.me/webproxy?server=proxy.example.com&secret=dd7f3c1e…
```

<div dir="rtl">

| دستور | کار |
| --- | --- |
| `webmtproxy` | همان پنل بالا |
| `webmtproxy link` | چاپ لینک `t.me/webproxy` |
| `webmtproxy qr` | چاپ همان لینک به شکل QR |
| `webmtproxy rotate-secret [HEX]` | سکرت جدید، ری‌استارت، چاپ لینک تازه |
| `webmtproxy sponsor [TAG]` | نمایش، ست کردن، یا حذف (`off`) تگ کانال اسپانسر |
| `webmtproxy site [DIR]` | نمایش سایت پوششی فعلی، یا پابلیش کردن `DIR` به‌جای آن |
| `webmtproxy restart` | ری‌استارت همه سرویس‌ها |
| `webmtproxy logs` | دنبال‌کردن همه لاگ‌ها |
| `webmtproxy update` | گرفتن آخرین نسخه و بیلد مجدد |
| `webmtproxy uninstall [--purge]` | حذف کامل |

`uninstall` بدون `--purge` مسیرهای `/srv/tproxy-site` و `/var/lib/caddy` را نگه
می‌دارد؛ صدور دوباره گواهی سهمیه Let's Encrypt را می‌سوزاند.

## کانال اسپانسر

پیش‌فرض خاموش است. پروکسی را در [@MTProxybot](https://t.me/MTProxybot) ثبت کن،
تگی که می‌دهد را بردار و:

```bash
sudo webmtproxy sponsor aabbccddeeff00112233445566778899
sudo webmtproxy sponsor off
```

تگ به‌شکل یک drop-in سیستم‌دی اعمال می‌شود که از روی خط فرمان خود سرویس ساخته
می‌شود، پس با آپدیت‌ها از بین نمی‌رود. یک نکته: @MTProxybot یک `host:port` ثبت
می‌کند، در حالی که اینجا کاربر از طریق HTTPS روی دامنه‌ات وصل می‌شود نه آن پورت —
تگ به بک‌اند پاس داده می‌شود، ولی تا وقتی خودت کارکردنش را ندیده‌ای رویش حساب
قطعی باز نکن.

## سایت پوششی

دامنه‌ات یک سایت معمولی HTTPS باقی می‌ماند. فقط درخواستی که کلید مشتق‌شده از
دامنه و سکرت را داشته باشد به پروکسی می‌رسد؛ بقیه سایت پوششی را می‌بینند.
نصب‌کننده یک صفحه خالی آنجا می‌گذارد، ولی همان صفحه خالی خودش نشانه است — با
`--site-dir` یک سایت باورپذیر بگذار.

</div>

```bash
sudo ./install.sh -d proxy.example.com -e you@example.com --site-dir /opt/my-site
```

<div dir="rtl">

برای تعویض بعد از نصب، یک پوشه را روی نسخه‌ی زنده پابلیش کن:

</div>

```bash
sudo webmtproxy site /opt/my-site
sudo webmtproxy site                    # الان چه چیزی سرو می‌شود
```

<div dir="rtl">

رله کل سایت را موقع استارت به حافظه لود می‌کند، پس ویرایش همان پوشه‌ای که از آن
نصب کردی هیچ اثری ندارد. `site` نسخه‌ی زنده را جایگزین می‌کند، قبلی را در
`/srv/tproxy-site.bak.<timestamp>` نگه می‌دارد و رله را ری‌استارت می‌کند. درباره‌ی
چیزهایی که سیاست پاسخ بلاک می‌کند هم هشدار می‌دهد: inline `<style>` و `<script>`،
منابع خارجی، و symlink.

</div>

<div dir="rtl">

## توسعه

</div>

```bash
./test_install.sh
```

<div dir="rtl">

۵۰ تست روی اعتبارسنجی ورودی‌ها، پچ زمان نصب، چرخش سکرت، drop-in تگ اسپانسر و پابلیش سایت. برای اینکه بوت‌استرپ و
`webmtproxy update` به فورک خودت اشاره کنند، `WEBMTPROXY_REPO` را ست کن.

## اعتبارها

ساخته‌شده روی [tproxy-server](https://github.com/telegramdesktop/tproxy-server) و
[MTProxy](https://github.com/TelegramMessenger/MTProxy) که حین نصب دریافت
می‌شوند و داخل ریپو کپی نشده‌اند. لایسنس MIT؛ پروژه‌های بالادستی شرایط خودشان را
دارند.

</div>
