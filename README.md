# omniscan

Username and email availability scanner with full-spectrum coverage. Combines accurate registration-API checks on key platforms with [Sherlock](https://github.com/sherlock-project/sherlock)'s 480+ site sweep, giving you both precision and breadth in a single command.

Forked from [socialscan](https://github.com/iojw/socialscan) with the following improvements:
- Fixed GitHub checks (switched from broken signup-page scraping to the public REST API)
- Fixed Instagram checks (updated to profile-page existence check)
- Fixed Pinterest crashes (defensive Content-Type header handling)
- Added `--sherlock` / `-s` flag for full 480+ site coverage via Sherlock

## Installation

```
git clone https://github.com/HubDamian95/omniscan.git
cd omniscan
pip install .
```

## Usage

```
omniscan [usernames/email addresses]

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
  --json json.txt                   output results as JSON
  --debug                           output debug messages
  --version                         show version
```

## Examples

Check a username across all built-in platforms:
```
omniscan johndoe
```

Check a username and run the full Sherlock sweep:
```
omniscan johndoe --sherlock --show-urls
```

Check email availability:
```
omniscan johndoe@gmail.com johndoe@outlook.com
```

Check only specific platforms:
```
omniscan johndoe --platforms github reddit gitlab
```

## Supported platforms

|           | Username | Email |
|:---------:|:--------:|:-----:|
| GitHub    |    ✔️    |       |
| GitLab    |    ✔️    |       |
| Instagram |    ✔️    |       |
| Reddit    |    ✔️    |       |
| Snapchat  |    ✔️    |       |
| Tumblr    |    ✔️    |  ✔️  |
| Twitter   |    ✔️    |  ✔️  |
| Yahoo     |    ✔️    |       |
| Lastfm    |    ✔️    |  ✔️  |
| Firefox   |          |  ✔️  |
| Pinterest |          |  ✔️  |

Plus 480+ sites via `--sherlock`.

## License

[MPL 2.0](https://www.mozilla.org/en-US/MPL/2.0/)
