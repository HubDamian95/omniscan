# omniscan

Username, email and phone number scanner. Combines accurate registration-API checks on key platforms with [Sherlock](https://github.com/sherlock-project/sherlock)'s 480+ site sweep and [PhoneInfoga](https://github.com/sundowndev/phoneinfoga) phone number intelligence — all in a single command.

Forked from [socialscan](https://github.com/iojw/socialscan).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/HubDamian95/omniscan/master/install.sh | bash
```

This installs:
- **omniscan** — pre-built binary (includes Sherlock + Holehe bundled)
- **PhoneInfoga** — Go binary for phone number scanning
- **Maigret** — 2500+ site username sweep (via pipx, if available)
- **GHunt** — Google account OSINT from email (via pipx, if available)

**Requirements:** curl, tar. That's it — self-contained binaries, no Python or pip needed.

> **npm alternative** — if you prefer Node.js over Python:
> ```bash
> npm install -g omniscan
> ```
> The npm package downloads the pre-built omniscan binary for your OS.
> Note: this path does **not** include PhoneInfoga — run the curl installer above to add phone scanning on top.

## Usage

```
omniscan [usernames/email addresses/phone numbers]

options:
  -h, --help                        show this help message and exit
  --platforms [-p] platform [...]   list of platforms to query (default: all)
  --view-by {platform,query}        sort results by platform or query
  --available-only, -a              only show available usernames/emails
  --cache-tokens, -c                cache tokens to reduce total requests
  --input, -i input.txt             file containing list of queries
  --proxy-list proxy_list.txt       file containing HTTP proxy servers
  --verbose, -v                     show responses as they arrive
  --show-urls                       display profile URLs for found usernames
  --sherlock, -s                    also run Sherlock across 480+ sites
  --holehe                          check email on 120+ sites via Holehe (bundled)
  --maigret                         sweep username across 2500+ sites via Maigret
  --ghunt                           Google account OSINT from email via GHunt (requires ghunt login)
  --phoneinfoga, -n                 scan phone numbers via PhoneInfoga
  --json json.txt                   output results as JSON
  --debug                           output debug messages
  --version                         show version
```

## Examples

Check a username:
```bash
omniscan johndoe
```

Check a username with full Sherlock sweep:
```bash
omniscan johndoe --sherlock --show-urls
```

Check email availability:
```bash
omniscan johndoe@gmail.com johndoe@outlook.com
```

Scan a phone number:
```bash
omniscan +12025551234 --phoneinfoga
```

Check email on 120+ sites via Holehe:
```bash
omniscan johndoe@gmail.com --holehe
```

Sweep username across 2500+ sites via Maigret:
```bash
omniscan johndoe --maigret
```

Google account OSINT (requires `ghunt login` once):
```bash
omniscan johndoe@gmail.com --ghunt
```

Everything at once:
```bash
omniscan johndoe johndoe@gmail.com +12025551234 --sherlock --holehe --maigret --ghunt --phoneinfoga --show-urls
```

Check only specific platforms:
```bash
omniscan johndoe --platforms github reddit gitlab
```

## Supported platforms

|            | Username | Email |
|:----------:|:--------:|:-----:|
| GitHub     |    ✔     |       |
| GitLab     |    ✔     |       |
| Instagram  |    ✔     |       |
| Reddit     |    ✔     |       |
| Twitter    |    ✔     |   ✔   |
| Firefox    |          |   ✔   |

Plus 480+ sites via `--sherlock` and phone number intelligence via `--phoneinfoga`.

## License

[MPL 2.0](https://www.mozilla.org/en-US/MPL/2.0/)
