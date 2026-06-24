# STR Listing Optimizer

One-click AI-powered audit tool for Airbnb and Booking.com listings. Paste a URL → get a full revenue audit, ranked fixes with dollar amounts, dynamic pricing tiers, rewritten copy, and a branded PDF report — powered by Claude Code.

## What it does

- Scrapes the listing (bypasses 403 via browser rendering)
- Runs parallel market research: ADR, occupancy, top-quartile rates, competitor intel
- Builds a 6-month event calendar with exact demand dates
- Audits 6 categories (Title, Description, Photos, Pricing, Amenities, Reviews), graded A–D
- Ranks all fixes by annual dollar impact with payback periods
- Generates a 2×2 effort/impact matrix
- Writes two title options + a ready-to-paste 100–150 word description rewrite
- Produces a prioritised photo shot list
- Outputs a branded A4 PDF report (navy `#1A1A2E` / red `#E94560`)

## Quick start

**One-click launcher (Windows):**

1. Double-click `run_report.cmd`
2. Paste an Airbnb or Booking.com URL into the dialog box
3. Wait ~3–5 minutes (scraping + research + audit)
4. PDF opens automatically from the `output/` folder

**Command line:**

```powershell
powershell -File run_report.ps1 -Url "https://www.airbnb.com/rooms/12345678"
# Optional: use a specific model
powershell -File run_report.ps1 -Url "https://www.airbnb.com/rooms/12345678" -Model "claude-sonnet-4-6"
```

**Manual / no automation:**

Open `str_optimizer_tool.html` in a browser. Run the analysis through the chat, paste the returned `listing_data.json`, click **Render report**, then **Save as PDF**.

## Requirements

| Requirement | Notes |
|---|---|
| [Claude Code](https://claude.ai/code) desktop app | The bundled `claude.exe` is the AI engine |
| Google Chrome | Used for headless PDF rendering |
| Windows 10 / 11 | The launcher is PowerShell; the HTML tool works on any OS |

No Python, Node.js, or API keys required beyond the Claude Code subscription.

## Files

| File | Purpose |
|---|---|
| `run_report.cmd` | Double-click launcher |
| `run_report.ps1` | PowerShell orchestrator (scrape → analyse → PDF) |
| `report_prompt.md` | The analysis instructions sent to Claude — edit to focus the report |
| `report_template.html` | Branded HTML report layout (data injected at run time) |
| `str_optimizer_tool.html` | Standalone browser tool for manual JSON → PDF workflow |
| `.claude/settings.json` | Scoped permission allowlist for unattended runs |

## Output

Each run produces three files in `output/`:

- `listing_data.json` — structured analysis (the data layer)
- `str_optimization_report.html` — rendered HTML report
- `str_optimization_report_<timestamp>.pdf` — final A4 PDF

## Permissions

The launcher uses a **scoped allowlist** (`.claude/settings.json`) — the unattended agent is allowed only to search the web, fetch the listing URL, and write files in this folder. No global permission bypass.

## Customising the analysis

Edit `report_prompt.md` to change the focus:

```
# Example: focus on shoulder-season pricing
Add to the end of the prompt:
"The operator wants extra focus on shoulder-season pricing uplift. 
Weight the pricing section accordingly."
```

## Report sections

1. Cover — listing name, platform, location, capacity, rating
2. Plain-English Owner Summary — headline + 5 decision bullets
3. Business Metrics Dashboard — current vs. potential RevPAR, market ADR, annual gap
4. Full Listing Audit — all 6 categories with A–D grades and issues
5. Dollar Leak Ranking — all fixes ranked by annual value, with ROI column
6. Effort vs. Impact Matrix — 2×2 classification
7. AI Revenue Management — seasonal rates + named event surge dates
8. Title & Description Rewrites — ready-to-paste copy
9. Photo Action Plan — prioritised shot list
10. Review Strategy — score gap, sub-score fixes, response playbook
11. Priority Action Checklist — CRITICAL / HIGH / MEDIUM / LOW

## License

MIT
