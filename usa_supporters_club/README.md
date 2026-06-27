# Stars & Stripes Club — USA Supporters Landing Page

A standalone, self-contained landing page for an (independent, fan-run) USA
supporters club for the **FIFA World Cup 26™**.

## Contents

- `index.html` — the complete landing page. All CSS and JavaScript are inlined,
  so there are **no build steps and no external dependencies**.

## Viewing it

Open the file directly in any browser:

```bash
# from the repo root
open usa_supporters_club/index.html        # macOS
xdg-open usa_supporters_club/index.html    # Linux
```

Or serve it locally:

```bash
python3 -m http.server --directory usa_supporters_club 8080
# then visit http://localhost:8080
```

## Features

- **Hero** with a live countdown to the provisional June 11, 2026 kickoff.
- **Perks / Why Join** section.
- **Three membership tiers** (Rookie / Patriot / Legend).
- **Provisional group-stage schedule** across host cities.
- **Sign-up form** with front-end-only validation (demo — no backend wired up).
- Fully **responsive** (red/white/blue USA theme) with a mobile nav.

## Notes

This page is independent fan content and is **not affiliated with or endorsed by
FIFA or U.S. Soccer**. Dates, opponents, and venues are placeholders pending the
official FIFA draw, and the sign-up form is a front-end demo only — wire it to a
real mailing-list backend before going live.
