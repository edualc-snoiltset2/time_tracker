# Web Scraper

A small, configurable web scraper for collecting structured data for analysis.
It fetches web pages, extracts fields defined by CSS selectors, and writes the
results to CSV or JSON so they can be loaded into pandas, a spreadsheet, or any
other analysis tool.

> **Note:** This is a standalone utility script. It is not part of the Flutter
> application and has no dependency on it — it lives here for convenience when
> gathering external data for analysis.

## Features

- **Polite by default** — respects `robots.txt`, sends a descriptive
  User-Agent, and rate-limits requests between pages.
- **Resilient** — retries failed requests with exponential backoff.
- **Declarative** — describe *what* to scrape in a small JSON config; no code
  changes needed to target a new site.
- **List-aware** — use `row_selector` to turn repeating elements (table rows,
  search results, cards) into one output row each.
- **CSV or JSON output** — chosen automatically from the output file extension.

## Setup

```bash
cd scripts
python -m venv .venv && source .venv/bin/activate   # optional but recommended
pip install -r requirements.txt
```

## Usage

### With a config file

```bash
python web_scraper.py --config scrape_config.example.json --out data.csv
```

### From the command line

```bash
python web_scraper.py \
  --url https://quotes.toscrape.com/ \
  --row-selector "div.quote" \
  --field quote="span.text" \
  --field author="small.author" \
  --out data.json
```

## Config format

```jsonc
{
  "urls": ["https://example.com/page/1"],  // or "url": "https://..."
  "row_selector": "div.item",              // optional; one row per match
  "fields": {
    "title": "h2",                          // text of first <h2>
    "link": "a@href",                       // href attribute (auto-absolutized)
    "tags": "a.tag[]"                        // [] collects all matches into a list
  },
  "delay": 1.0,          // seconds between requests
  "timeout": 20.0,       // per-request timeout
  "max_retries": 3,      // retry attempts with exponential backoff
  "respect_robots": true // consult robots.txt before fetching
}
```

### Field selector shorthand

| Shorthand      | Meaning                                              |
|----------------|------------------------------------------------------|
| `h1`           | Text content of the first `<h1>`                     |
| `a@href`       | The `href` attribute of the first `<a>`              |
| `a.tag[]`      | List of the text of every `<a class="tag">`          |
| `img@src[]`    | List of `src` attributes of all `<img>` (absolutized)|

Fields can also be written in long form:

```json
{ "fields": { "price": { "selector": "span.price", "attribute": null, "multiple": false } } }
```

Relative `href` and `src` values are automatically resolved to absolute URLs,
and a `source_url` column is added to every row.

## Analyzing the output

```python
import pandas as pd
df = pd.read_csv("data.csv")   # or pd.read_json("data.json")
print(df.describe(include="all"))
```

## Google Play reviews → Excel

`duolingo_reviews_to_excel.py` scrapes user reviews from the Google Play Store
(default app: Duolingo, `com.duolingo`) and writes a formatted `.xlsx` with a
`Reviews` sheet (frozen header + autofilter) and a `Summary` sheet (total,
average rating, star distribution).

```bash
pip install -r requirements-scraper.txt

# Up to 500 Duolingo reviews (the default), newest first
python duolingo_reviews_to_excel.py --out duolingo_reviews.xlsx

# Customize: count, sort, language/country, any app id
python duolingo_reviews_to_excel.py --app-id com.duolingo \
  --max-reviews 1000 --sort newest --lang en --country us --out reviews.xlsx

# Preview the Excel layout offline, no network needed (sample data)
python duolingo_reviews_to_excel.py --demo --max-reviews 25 --out sample.xlsx
```

| Flag | Default | Meaning |
|------|---------|---------|
| `--app-id` | `com.duolingo` | Play Store application id |
| `--max-reviews` | `500` | Maximum reviews to collect (paginated automatically) |
| `--sort` | `newest` | `newest`, `rating`, or `relevance` |
| `--lang` / `--country` | `en` / `us` | Review language and store region |
| `--out` | `duolingo_reviews.xlsx` | Output workbook path |
| `--demo` | off | Generate sample rows without network (format preview) |

> **Network note:** this must be run in an environment with outbound internet
> access. It cannot fetch reviews from a sandbox whose egress policy blocks
> `play.google.com`.

## Responsible use

Only scrape sites you are permitted to. Respect each site's Terms of Service
and `robots.txt`, keep request rates modest, and avoid collecting personal
data. The `--ignore-robots` flag exists for testing against your own servers —
use it responsibly.
