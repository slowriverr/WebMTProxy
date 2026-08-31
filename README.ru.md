<h1 align="center">WebMTProxy</h1>

<p align="center">
  Новый <b>WEB proxy</b> Telegram одной командой —
  с CLI-панелью и поддержкой <b>спонсорского канала</b>.
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.fa.md">فارسی</a> ·
  <b>Русский</b>
</p>

<p align="center">
  <img alt="shell" src="https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white">
  <img alt="platform" src="https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu%20x86__64-A81D33?logo=debian&logoColor=white">
  <img alt="tests" src="https://img.shields.io/badge/tests-65%20passing-brightgreen">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-blue">
</p>

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/slowriverr/WebMTProxy/main/install.sh)
```

Это вся установка. Скрипт спросит домен и e-mail, всё соберёт, получит
TLS-сертификат и выдаст ссылку `t.me/webproxy`.

---

## Что вы получаете

- **Одна команда.** Домен, e-mail, секрет, сайт-прикрытие, TLS, файрвол, сервисы.
- **Падает рано, а не поздно.** Root, архитектура, systemd, действительно ли
  A-запись указывает сюда, свободны ли порты 80 и 443 — всё проверяется до того,
  как что-либо будет изменено.
- **Работает с первого раза.** Ошибка прав доступа, из-за которой прокси иначе не
  запускается вовсе, исправляется во время установки.
- **Спонсорский канал.** Можно подключить рекламный тег
  [@MTProxybot](https://t.me/MTProxybot) — у upstream-установщика такого флага
  нет вовсе. По умолчанию выключено, включается одной командой.
- **Настоящая панель.** Состояние сервисов, срок сертификата, живые подключения,
  смена секрета, логи, обновление, чистое удаление.
- **Никакого скрытого состояния.** Панель читает всё из рабочих конфигов —
  нечему рассинхронизироваться.

```text
Telegram app ──WebView / HTTPS──▶ your domain ──▶ backend ──▶ Telegram
                                       └── every other request: your website
```

## Требования

|  | |
| --- | --- |
| **Сервер** | Debian или Ubuntu, **x86_64**, systemd, root |
| **DNS** | A-запись домена, указывающая на сервер, уже распространившаяся |
| **Порты** | 80 и 443 свободны |

## Установка

```bash
git clone https://github.com/slowriverr/WebMTProxy
cd WebMTProxy
sudo ./install.sh
```

Без интерактива:

```bash
sudo ./install.sh --domain proxy.example.com --email you@example.com --yes
```

Займёт 5–15 минут — всё компилируется из исходников и выпускается сертификат.
Прогресс на экране, полный вывод в `/var/log/webmtproxy-install.log`.

<details>
<summary><b>Все флаги установщика</b></summary>

| Флаг | Значение |
| --- | --- |
| `-d, --domain HOST` | публичное имя хоста, например `proxy.example.com` |
| `-e, --email ADDR` | контактный e-mail для Let's Encrypt |
| `-s, --secret HEX` | 32 hex-символа, можно с префиксом `dd` — если не задан, будет спрошено |
| `-t, --tag HEX` | тег спонсорского канала от [@MTProxybot](https://t.me/MTProxybot) (по умолчанию нет) |
| `--site-dir DIR` | отдавать этот каталог как сайт-прикрытие |
| `--site-upstream URL` | проксировать сайт-прикрытие на `http://127.0.0.1:PORT` |
| `--workers N` | число воркеров, `0` — один процесс (по умолчанию 0) |
| `--max-connections N` | лимит подключений, `0` — без лимита (по умолчанию 0) |
| `-y, --yes` | без вопросов и подтверждения |
| `-v, --verbose` | показывать вывод сборки вместо спиннера |

Всё, что не передано, будет спрошено интерактивно.

</details>

## Панель

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
    mtproxy        0 worker(s)

    https://t.me/webproxy?server=proxy.example.com&secret=dd7f3c1e…

  commands  link · qr · rotate-secret · sponsor · site · mode · domain
            -M N · -C N · restart · logs · update · uninstall · help
```

| Команда | Что делает |
| --- | --- |
| `webmtproxy` | панель выше |
| `webmtproxy link` | вывести ссылку `t.me/webproxy` |
| `webmtproxy qr` | вывести её в виде QR-кода |
| `webmtproxy rotate-secret [HEX]` | новый секрет, перезапуск, новая ссылка |
| `webmtproxy sponsor [TAG]` | показать, задать или убрать (`off`) тег спонсорского канала |
| `webmtproxy site [DIR]` | показать текущий сайт-прикрытие или опубликовать `DIR` |
| `webmtproxy mode [MODE]` | транспорт: `https`, `https-lanes`, `websocket`, `websocket-lanes` |
| `webmtproxy domain [HOST]` | показать или сменить домен и вывести новую ссылку |
| `webmtproxy -M N [-C N]` | воркеры MTProxy (`0` — один процесс) и лимит подключений (`0` — без лимита) |
| `webmtproxy restart` | перезапустить все сервисы |
| `webmtproxy logs` | следить за всеми журналами |
| `webmtproxy update` | получить свежую версию и пересобрать, сохранив настройки |
| `webmtproxy uninstall [--purge]` | удалить всё |

Без `--purge` удаление сохраняет `/srv/tproxy-site` и `/var/lib/caddy` —
повторный выпуск сертификатов расходует лимиты Let's Encrypt.

## Спонсорский канал

По умолчанию выключен. Зарегистрируйте прокси в
[@MTProxybot](https://t.me/MTProxybot), возьмите выданный тег и:

```bash
sudo webmtproxy sponsor aabbccddeeff00112233445566778899
sudo webmtproxy sponsor off
```

Тег применяется systemd-дропином, который пересобирается из собственной команды
запуска сервиса, поэтому переживает обновления. Важный нюанс: @MTProxybot
регистрирует `host:port`, а клиенты приходят по HTTPS на ваш домен, а не на этот
порт — тег передаётся бэкенду, но до первой проверки считайте доставку
спонсорского канала не гарантированной.

## Транспорт

WebView может нести сессию четырьмя способами. `https` — по умолчанию;
остальные дают ту же полезную нагрузку с другой формой трафика, что важно,
когда одну из форм режут.

```bash
sudo webmtproxy mode websocket
sudo webmtproxy mode              # что задано сейчас
```

| Режим | Форма |
| --- | --- |
| `https` | один последовательный HTTPS-носитель |
| `https-lanes` | независимые HTTPS-полосы на логическую сессию |
| `websocket` | один мультиплексированный WebSocket |
| `websocket-lanes` | отдельный WebSocket на логическую сессию |

Клиенты подхватят новый режим в следующей сессии; переустановка не нужна.

## Сайт-прикрытие

Ваш домен остаётся обычным HTTPS-сайтом. До прокси доходит только запрос с
ключом, выведенным из имени хоста и секрета; всё остальное получает
сайт-прикрытие. Установщик кладёт туда заглушку, но заглушка сама по себе
выдаёт вас — укажите `--site-dir` на что-то правдоподобное.

```bash
sudo ./install.sh -d proxy.example.com -e you@example.com --site-dir /opt/my-site
```

Чтобы поменять его позже, опубликуйте каталог поверх рабочего:

```bash
sudo webmtproxy site /opt/my-site
sudo webmtproxy site                    # что отдаётся сейчас
```

Релей загружает весь сайт в память при старте, поэтому правка каталога, из
которого вы устанавливали, ничего не меняет. `site` заменяет рабочую копию,
сохраняет прежнюю в `/srv/tproxy-site.bak.<timestamp>` и перезапускает релей.
Он также предупреждает о том, что блокирует политика ответов: inline `<style>`
и `<script>`, внешние ресурсы и симлинки.

## Разработка

```bash
./test_install.sh
```

65 проверок: валидация ввода, патч во время установки, смена секрета, drop-in тега, публикация сайта, режим транспорта и смена домена.
Задайте `WEBMTPROXY_REPO`, чтобы bootstrap и `webmtproxy update` смотрели на форк.

## Благодарности

Построено на [tproxy-server](https://github.com/telegramdesktop/tproxy-server) и
[MTProxy](https://github.com/TelegramMessenger/MTProxy) — они загружаются во время
установки, а не копируются в репозиторий. Лицензия MIT; у upstream-проектов свои
условия.
