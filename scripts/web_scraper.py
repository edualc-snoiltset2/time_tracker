#!/usr/bin/env python3
"""Configurable web scraper for collecting structured data for analysis.

This script fetches one or more web pages, extracts fields defined by CSS
selectors, and writes the results to CSV or JSON so they can be loaded into
pandas, a spreadsheet, or any other analysis tool.

Design goals
------------
* **Polite by default** - respects ``robots.txt``, sends a descriptive
  User-Agent, and rate-limits requests.
* **Resilient** - retries failed requests with exponential backoff.
* **Declarative** - what to scrape is described in a small JSON config,
  so no code changes are needed to target a new site.

Example
-------
Create a config file (see ``scrape_config.example.json``) and run::

    python web_scraper.py --config scrape_config.example.json --out data.csv

Or scrape a single page from the command line::

    python web_scraper.py --url https://example.com \\
        --field title=h1 --field link=a@href --out data.json

Dependencies: ``requests`` and ``beautifulsoup4`` (see requirements.txt).
"""

from __future__ import annotations

import argparse
import csv
import json
import logging
import sys
import time
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Optional
from urllib.parse import urljoin, urlparse
from urllib.robotparser import RobotFileParser

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError as exc:  # pragma: no cover - dependency guard
    sys.stderr.write(
        "Missing dependency: {name}. Install requirements with:\n"
        "    pip install -r requirements.txt\n".format(name=exc.name)
    )
    raise SystemExit(1)


logger = logging.getLogger("web_scraper")

DEFAULT_USER_AGENT = (
    "time-tracker-scraper/1.0 (+https://github.com/edualc-snoiltset2/time_tracker)"
)


@dataclass
class FieldSpec:
    """Describes how to extract a single field from a page.

    Attributes:
        name: Output column / key name.
        selector: A CSS selector identifying the element(s).
        attribute: Optional element attribute to read (e.g. ``href``). When
            omitted, the element's text content is used.
        multiple: When True, collect all matches into a list; otherwise take
            the first match.
    """

    name: str
    selector: str
    attribute: Optional[str] = None
    multiple: bool = False

    @classmethod
    def parse(cls, name: str, spec: Any) -> "FieldSpec":
        """Build a FieldSpec from either a shorthand string or a dict.

        Shorthand string forms:
            "h1"          -> text of first <h1>
            "a@href"      -> href attribute of first <a>
            "a@href[]"    -> href attribute of every <a> (list)
        """
        if isinstance(spec, dict):
            return cls(
                name=name,
                selector=spec["selector"],
                attribute=spec.get("attribute"),
                multiple=bool(spec.get("multiple", False)),
            )

        selector = str(spec)
        multiple = False
        if selector.endswith("[]"):
            multiple = True
            selector = selector[:-2]

        attribute = None
        if "@" in selector:
            selector, attribute = selector.rsplit("@", 1)

        return cls(
            name=name,
            selector=selector.strip(),
            attribute=(attribute.strip() if attribute else None),
            multiple=multiple,
        )


@dataclass
class ScrapeConfig:
    """Top-level scraping configuration."""

    urls: List[str]
    fields: List[FieldSpec]
    row_selector: Optional[str] = None
    user_agent: str = DEFAULT_USER_AGENT
    delay: float = 1.0
    timeout: float = 20.0
    max_retries: int = 3
    respect_robots: bool = True
    headers: Dict[str, str] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ScrapeConfig":
        raw_fields = data.get("fields", {})
        fields = [FieldSpec.parse(name, spec) for name, spec in raw_fields.items()]
        if not fields:
            raise ValueError("Config must define at least one field under 'fields'.")

        urls = data.get("urls") or ([data["url"]] if data.get("url") else [])
        if not urls:
            raise ValueError("Config must define 'url' or a non-empty 'urls' list.")

        return cls(
            urls=list(urls),
            fields=fields,
            row_selector=data.get("row_selector"),
            user_agent=data.get("user_agent", DEFAULT_USER_AGENT),
            delay=float(data.get("delay", 1.0)),
            timeout=float(data.get("timeout", 20.0)),
            max_retries=int(data.get("max_retries", 3)),
            respect_robots=bool(data.get("respect_robots", True)),
            headers=dict(data.get("headers", {})),
        )


class RobotsCache:
    """Caches robots.txt parsers per host to avoid refetching."""

    def __init__(self, user_agent: str) -> None:
        self._user_agent = user_agent
        self._cache: Dict[str, Optional[RobotFileParser]] = {}

    def can_fetch(self, url: str) -> bool:
        parsed = urlparse(url)
        host = f"{parsed.scheme}://{parsed.netloc}"
        parser = self._cache.get(host, "unset")

        if parser == "unset":
            parser = self._load(host)
            self._cache[host] = parser

        # If robots.txt could not be loaded, err on the side of allowing.
        if parser is None:
            return True
        return parser.can_fetch(self._user_agent, url)

    def _load(self, host: str) -> Optional[RobotFileParser]:
        robots_url = urljoin(host, "/robots.txt")
        parser = RobotFileParser()
        parser.set_url(robots_url)
        try:
            parser.read()
            logger.debug("Loaded robots.txt from %s", robots_url)
            return parser
        except Exception as exc:  # noqa: BLE001 - network/parse errors are non-fatal
            logger.warning("Could not read %s (%s); proceeding without it.", robots_url, exc)
            return None


class Scraper:
    """Fetches pages and extracts fields according to a ScrapeConfig."""

    def __init__(self, config: ScrapeConfig) -> None:
        self.config = config
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": config.user_agent})
        self.session.headers.update(config.headers)
        self._robots = RobotsCache(config.user_agent) if config.respect_robots else None

    def run(self) -> List[Dict[str, Any]]:
        """Scrape all configured URLs and return the collected rows."""
        rows: List[Dict[str, Any]] = []
        for index, url in enumerate(self.config.urls):
            if index > 0 and self.config.delay > 0:
                time.sleep(self.config.delay)

            if self._robots and not self._robots.can_fetch(url):
                logger.warning("Skipping %s (disallowed by robots.txt).", url)
                continue

            html = self._fetch(url)
            if html is None:
                continue

            page_rows = self._extract(html, url)
            logger.info("Extracted %d row(s) from %s", len(page_rows), url)
            rows.extend(page_rows)

        return rows

    def _fetch(self, url: str) -> Optional[str]:
        """Fetch a URL with retries and exponential backoff."""
        backoff = 1.0
        for attempt in range(1, self.config.max_retries + 1):
            try:
                response = self.session.get(url, timeout=self.config.timeout)
                response.raise_for_status()
                return response.text
            except requests.RequestException as exc:
                logger.warning(
                    "Attempt %d/%d failed for %s: %s",
                    attempt,
                    self.config.max_retries,
                    url,
                    exc,
                )
                if attempt < self.config.max_retries:
                    time.sleep(backoff)
                    backoff *= 2
        logger.error("Giving up on %s after %d attempts.", url, self.config.max_retries)
        return None

    def _extract(self, html: str, base_url: str) -> List[Dict[str, Any]]:
        """Extract rows from a page.

        When ``row_selector`` is set, each matching element becomes one row and
        field selectors are evaluated relative to it (useful for lists, tables,
        or search results). Otherwise the whole page yields a single row.
        """
        soup = BeautifulSoup(html, "html.parser")

        if self.config.row_selector:
            containers = soup.select(self.config.row_selector)
            return [
                self._extract_fields(container, base_url) for container in containers
            ]
        return [self._extract_fields(soup, base_url)]

    def _extract_fields(self, scope: Any, base_url: str) -> Dict[str, Any]:
        row: Dict[str, Any] = {"source_url": base_url}
        for spec in self.config.fields:
            elements = scope.select(spec.selector)
            values = [self._value(el, spec, base_url) for el in elements]
            values = [v for v in values if v is not None]

            if spec.multiple:
                row[spec.name] = values
            else:
                row[spec.name] = values[0] if values else None
        return row

    def _value(self, element: Any, spec: FieldSpec, base_url: str) -> Optional[str]:
        if spec.attribute:
            value = element.get(spec.attribute)
            if value is None:
                return None
            # Resolve relative links/resources to absolute URLs.
            if spec.attribute in {"href", "src"}:
                return urljoin(base_url, value)
            return value
        text = element.get_text(strip=True)
        return text or None


def write_output(rows: List[Dict[str, Any]], path: str) -> None:
    """Write rows to CSV or JSON, inferred from the file extension."""
    if not rows:
        logger.warning("No rows to write.")

    if path.lower().endswith(".json"):
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(rows, fh, indent=2, ensure_ascii=False)
    else:
        fieldnames = _collect_fieldnames(rows)
        with open(path, "w", encoding="utf-8", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=fieldnames)
            writer.writeheader()
            for row in rows:
                writer.writerow({k: _stringify(row.get(k)) for k in fieldnames})

    logger.info("Wrote %d row(s) to %s", len(rows), path)


def _collect_fieldnames(rows: Iterable[Dict[str, Any]]) -> List[str]:
    fieldnames: List[str] = []
    for row in rows:
        for key in row:
            if key not in fieldnames:
                fieldnames.append(key)
    return fieldnames


def _stringify(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, (list, dict)):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


def build_config_from_args(args: argparse.Namespace) -> ScrapeConfig:
    """Build a ScrapeConfig from a config file and/or CLI flags."""
    data: Dict[str, Any] = {}
    if args.config:
        with open(args.config, "r", encoding="utf-8") as fh:
            data = json.load(fh)

    if args.url:
        data["urls"] = list(args.url)

    if args.field:
        fields = dict(data.get("fields", {}))
        for item in args.field:
            if "=" not in item:
                raise ValueError(f"Invalid --field '{item}'; expected name=selector.")
            name, spec = item.split("=", 1)
            fields[name.strip()] = spec.strip()
        data["fields"] = fields

    if args.row_selector:
        data["row_selector"] = args.row_selector
    if args.delay is not None:
        data["delay"] = args.delay
    if args.user_agent:
        data["user_agent"] = args.user_agent
    if args.ignore_robots:
        data["respect_robots"] = False

    return ScrapeConfig.from_dict(data)


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scrape structured data from web pages for analysis.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--config", help="Path to a JSON scrape config file.")
    parser.add_argument(
        "--url",
        action="append",
        help="URL to scrape (repeatable). Overrides 'urls' in the config.",
    )
    parser.add_argument(
        "--field",
        action="append",
        help="Field as name=selector, e.g. title=h1 or link=a@href (repeatable).",
    )
    parser.add_argument(
        "--row-selector",
        help="CSS selector for repeating rows (e.g. table row or list item).",
    )
    parser.add_argument("--delay", type=float, help="Seconds to wait between requests.")
    parser.add_argument("--user-agent", help="Custom User-Agent header.")
    parser.add_argument(
        "--ignore-robots",
        action="store_true",
        help="Do not consult robots.txt (use responsibly).",
    )
    parser.add_argument(
        "--out",
        default="scraped_data.csv",
        help="Output file path; .json or .csv chosen by extension.",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable debug logging.",
    )
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )

    if not args.config and not args.url:
        logger.error("Provide --config or at least one --url. See --help.")
        return 2

    try:
        config = build_config_from_args(args)
    except (ValueError, KeyError, json.JSONDecodeError, OSError) as exc:
        logger.error("Configuration error: %s", exc)
        return 2

    scraper = Scraper(config)
    rows = scraper.run()
    write_output(rows, args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
