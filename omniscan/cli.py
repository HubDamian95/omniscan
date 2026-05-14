# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import argparse
import asyncio
import json
import logging
import sys
import time
from collections import defaultdict, namedtuple
from dataclasses import asdict
from operator import attrgetter

import aiohttp
import colorama
import tqdm
from colorama import Fore, Style

from omniscan import __version__
from omniscan.platforms import PlatformResponse, Platforms
from omniscan.util import EMAIL_REGEX, PHONE_REGEX, init_checkers, init_prerequest, query

BAR_WIDTH = 50
BAR_FORMAT = "{l_bar}{bar}| {n_fmt}/{total_fmt} [{elapsed_s:.2f}s]"

DIVIDER_LENGTH = 40

Colour = namedtuple("Colour", ["Primary", "Secondary"])
COLOUR_AVAILABLE = Colour(Fore.LIGHTGREEN_EX, Fore.LIGHTGREEN_EX)
COLOUR_UNAVAILABLE = Colour(Fore.YELLOW, Fore.WHITE)
COLOUR_INVALID = Colour(Fore.CYAN, Fore.WHITE)
COLOUR_ERROR = Colour(Fore.RED, Fore.RED)


def init_parser():
    parser = argparse.ArgumentParser(
        description="Command-line interface for checking email address and username usage on online platforms: "
        + ", ".join(p.value.__name__ for p in Platforms)
    )
    parser.add_argument(
        "queries",
        metavar="query",
        nargs="*",
        help="one or more usernames/email addresses to query (email addresses are automatically be queried if they match the format)",
    )
    parser.add_argument(
        "--platforms",
        "-p",
        metavar="platform",
        nargs="*",
        help="list of platforms to query " "(default: all platforms)",
    )
    parser.add_argument(
        "--view-by",
        dest="view_key",
        choices=["platform", "query"],
        default="query",
        help="view results sorted by platform or by query (default: query)",
    )
    parser.add_argument(
        "--available-only",
        "-a",
        action="store_true",
        help="only print usernames/email addresses that are available and not in use",
    )
    parser.add_argument(
        "--cache-tokens",
        "-c",
        action="store_true",
        help="cache tokens for platforms requiring more than one HTTP request (Snapchat, GitHub, Instagram. Lastfm, Tumblr & Yahoo), reducing total number of requests sent",
    )
    parser.add_argument(
        "--input", "-i", metavar="input.txt", help="file containg list of queries to execute"
    )
    parser.add_argument(
        "--proxy-list",
        metavar="proxy_list.txt",
        help="file containing list of HTTP proxy servers to execute queries with",
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="show query responses as they are received"
    )
    parser.add_argument(
        "--show-urls",
        action="store_true",
        help="display profile URLs for usernames on supported platforms (profiles may not exist if usernames are reserved or belong to deleted/banned accounts)",
    )
    parser.add_argument(
        "--json",
        metavar="json.txt",
        help="output results in JSON format to the specified file",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="output debug messages",
    )
    parser.add_argument(
        "--sherlock",
        "-s",
        action="store_true",
        help="also run Sherlock to check username across 400+ additional sites",
    )
    parser.add_argument(
        "--phoneinfoga",
        "-n",
        action="store_true",
        help="run PhoneInfoga to scan phone numbers (e.g. +12025551234); requires phoneinfoga in PATH",
    )
    parser.add_argument("--version", version=f"%(prog)s {__version__}", action="version")
    return parser


def pretty_print(results, *, view_value, available_only, show_urls):
    for key, responses in results.items():
        if available_only and not [r for r in responses if r.available]:
            continue

        header = (
            f"{'-' * DIVIDER_LENGTH}\n"
            f"{' ' * (DIVIDER_LENGTH // 2 - len(key) // 2) + Style.BRIGHT + str(key) + Style.RESET_ALL}\n"
            f"{'-' * DIVIDER_LENGTH}"
        )
        print(header)

        responses.sort(key=lambda response: str(getattr(response, view_value)).lower())
        responses.sort(key=attrgetter("available", "valid", "success"), reverse=True)
        for response in responses:
            value = str(getattr(response, view_value))
            if available_only and not response.available:
                continue
            if not response.success:
                print(COLOUR_ERROR.Primary + f"{value}: {response.message}", file=sys.stderr)
            elif not response.valid:
                print(
                    COLOUR_INVALID.Primary
                    + f"{value}: {COLOUR_INVALID.Secondary}{response.message}"
                )
            else:
                col = COLOUR_AVAILABLE if response.available else COLOUR_UNAVAILABLE
                result_text = col.Primary + value
                if response.link and show_urls:
                    result_text += col.Secondary + f" - {response.link}"
                print(result_text)

    print("\n" + COLOUR_AVAILABLE.Primary + "Available, ", end="")
    print(COLOUR_UNAVAILABLE.Primary + "Taken/Reserved, ", end="")
    print(COLOUR_INVALID.Primary + "Invalid, ", end="")
    print(COLOUR_ERROR.Primary + "Error")


def print_json(results, *, file, available_only):
    if available_only:
        results = {key: [v for v in values if v.available] for key, values in results.items()}

    def serialize(obj):
        if isinstance(obj, PlatformResponse):
            # Omit None and convert Platform objects to str
            return asdict(
                obj,
                dict_factory=lambda data: dict(
                    [(x[0], str(x[1])) for x in data if x[1] is not None]
                ),
            )

    with open(file, "w") as f:
        f.write(json.dumps(results, default=serialize, indent=4))


async def run_sherlock(username, per_request_timeout=10, overall_timeout=120):
    from sherlock_project.notify import QueryNotify
    from sherlock_project.sherlock import sherlock as sherlock_scan
    from sherlock_project.sites import SitesInformation

    sites_info = SitesInformation()
    site_data = {site.name: site.information for site in sites_info}
    try:
        return await asyncio.wait_for(
            asyncio.to_thread(
                sherlock_scan, username, site_data, QueryNotify(), timeout=per_request_timeout
            ),
            timeout=overall_timeout,
        )
    except asyncio.TimeoutError:
        print(f"\nomniscan: Sherlock scan timed out after {overall_timeout}s")
        return {}


def print_sherlock_results(sherlock_results, *, available_only, show_urls):
    from sherlock_project.result import QueryStatus

    print("\n" + "=" * DIVIDER_LENGTH)
    print(" " * (DIVIDER_LENGTH // 2 - 8) + Style.BRIGHT + "SHERLOCK SCAN" + Style.RESET_ALL)
    print("=" * DIVIDER_LENGTH)

    for username, results in sherlock_results.items():
        header = (
            f"{'-' * DIVIDER_LENGTH}\n"
            f"{' ' * (DIVIDER_LENGTH // 2 - len(username) // 2) + Style.BRIGHT + username + Style.RESET_ALL}\n"
            f"{'-' * DIVIDER_LENGTH}"
        )
        print(header)

        claimed = sorted(
            [(site, info) for site, info in results.items()
             if info["status"].status == QueryStatus.CLAIMED],
            key=lambda x: x[0].lower(),
        )
        available = sorted(
            [(site, info) for site, info in results.items()
             if info["status"].status == QueryStatus.AVAILABLE],
            key=lambda x: x[0].lower(),
        )

        if not available_only:
            for site, info in claimed:
                line = COLOUR_UNAVAILABLE.Primary + site
                if show_urls:
                    line += COLOUR_UNAVAILABLE.Secondary + f" - {info['url_user']}"
                print(line)

        if available_only:
            for site, info in available:
                print(COLOUR_AVAILABLE.Primary + site)

        if not available_only:
            errors = sum(
                1 for info in results.values()
                if info["status"].status not in (QueryStatus.CLAIMED, QueryStatus.AVAILABLE, QueryStatus.ILLEGAL)
            )
            print(
                f"\n{COLOUR_UNAVAILABLE.Primary}{len(claimed)} found"
                f"{Fore.RESET}, {COLOUR_AVAILABLE.Primary}{len(available)} available"
                f"{Fore.RESET}, {COLOUR_ERROR.Primary}{errors} errors"
            )


async def run_phoneinfoga(number, overall_timeout=60):
    import os
    import shutil
    import subprocess

    phoneinfoga_bin = shutil.which("phoneinfoga")
    if not phoneinfoga_bin:
        bin_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
        candidate = os.path.join(bin_dir, "phoneinfoga.exe" if sys.platform == "win32" else "phoneinfoga")
        if os.path.exists(candidate):
            phoneinfoga_bin = candidate

    if not phoneinfoga_bin:
        print(
            "\nomniscan: PhoneInfoga not found.\n"
            "Install it from: https://github.com/sundowndev/phoneinfoga/releases\n"
            "Then make sure 'phoneinfoga' is in your PATH."
        )
        return None

    try:
        result = await asyncio.wait_for(
            asyncio.to_thread(
                subprocess.run,
                [phoneinfoga_bin, "scan", "-n", number],
                capture_output=True,
                text=True,
            ),
            timeout=overall_timeout,
        )
        return (result.stdout + result.stderr).strip()
    except asyncio.TimeoutError:
        print(f"\nomniscan: PhoneInfoga scan timed out after {overall_timeout}s")
        return None


def print_phoneinfoga_results(phoneinfoga_results):
    print("\n" + "=" * DIVIDER_LENGTH)
    print(" " * (DIVIDER_LENGTH // 2 - 8) + Style.BRIGHT + "PHONEINFOGA SCAN" + Style.RESET_ALL)
    print("=" * DIVIDER_LENGTH)

    for number, output in phoneinfoga_results.items():
        header = (
            f"{'-' * DIVIDER_LENGTH}\n"
            f"{' ' * (DIVIDER_LENGTH // 2 - len(number) // 2) + Style.BRIGHT + number + Style.RESET_ALL}\n"
            f"{'-' * DIVIDER_LENGTH}"
        )
        print(header)
        if output:
            print(output)
        else:
            print(COLOUR_ERROR.Primary + "No results returned.")


async def main():
    start_time = time.time()
    colorama.init(autoreset=True)
    if sys.version_info >= (3, 7):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = init_parser()
    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    queries = args.queries
    if args.input:
        with open(args.input, "r") as f:
            for line in f:
                queries.append(line.strip("\n"))
    if not args.queries:
        raise ValueError("You must specify either at least one query or an input file")
    queries = list(dict.fromkeys(queries))
    phone_queries = [q for q in queries if PHONE_REGEX.match(q)]
    queries = [q for q in queries if not PHONE_REGEX.match(q)]
    if phone_queries and not args.phoneinfoga:
        print(
            f"Note: {len(phone_queries)} phone number(s) detected but --phoneinfoga flag not set. "
            "Use -n / --phoneinfoga to scan them."
        )
    if args.platforms:
        platforms = []
        for p in args.platforms:
            if p.upper() in Platforms.__members__:
                platforms.append(Platforms[p.upper()])
            else:
                raise ValueError(p + " is not a valid platform")
    else:
        platforms = [p for p in Platforms]
    proxy_list = []
    if args.proxy_list:
        with open(args.proxy_list, "r") as f:
            for line in f:
                proxy_list.append(line.strip("\n"))
    if args.view_key == "query":
        view_value = "platform"
    elif args.view_key == "platform":
        view_value = "query"

    async with aiohttp.ClientSession() as session:
        checkers = init_checkers(session, proxy_list=proxy_list)
        results = defaultdict(list)
        if args.cache_tokens:
            print("Caching tokens...", end="")
            await asyncio.gather(*(init_prerequest(platform, checkers) for platform in platforms))
            print(end="\r")
        platform_queries = [query(q, p, checkers) for q in queries for p in platforms]
        for future in tqdm.tqdm(
            asyncio.as_completed(platform_queries),
            total=len(platform_queries),
            disable=args.verbose or args.debug,
            leave=False,
            ncols=BAR_WIDTH,
            bar_format=BAR_FORMAT,
        ):
            platform_response = await future
            if platform_response is None:
                continue
            if args.verbose:
                print(platform_response, getattr(platform_response, args.view_key))
                print(
                    f"Checked {platform_response.query: ^25} on {platform_response.platform.value.__name__:<10}: {platform_response.message}"
                )
            results[str(getattr(platform_response, args.view_key))].append(platform_response)

    if args.json:
        print_json(results, file=args.json, available_only=args.available_only)
    else:
        pretty_print(
            results,
            view_value=view_value,
            available_only=args.available_only,
            show_urls=args.show_urls,
        )
    print(f"Completed {len(platform_queries)} queries in {time.time() - start_time:.2f}s")

    if args.sherlock:
        username_queries = [q for q in queries if not EMAIL_REGEX.match(q)]
        if username_queries:
            print("\nRunning Sherlock scan (this may take a moment)...")
            sherlock_results = {}
            for uq in username_queries:
                sherlock_results[uq] = await run_sherlock(uq)
            print_sherlock_results(
                sherlock_results,
                available_only=args.available_only,
                show_urls=args.show_urls,
            )
        else:
            print("\n[Sherlock] Skipped: Sherlock only supports username queries, not email addresses.")

    if args.phoneinfoga and phone_queries:
        print("\nRunning PhoneInfoga scan (this may take a moment)...")
        phoneinfoga_results = {}
        for pq in phone_queries:
            phoneinfoga_results[pq] = await run_phoneinfoga(pq)
        print_phoneinfoga_results(phoneinfoga_results)
    elif args.phoneinfoga and not phone_queries:
        print("\n[PhoneInfoga] Skipped: no phone numbers detected in queries (expected format: +12025551234).")
