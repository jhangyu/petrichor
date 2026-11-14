# Mockup design brief (both teams)

Frozen acceptance: docs/design/contract.md. Page functions & sample data: docs/design/preflight/page-inventory.md.
Shared foundation (do NOT edit): docs/design/tokens-fluent2-light.css, docs/design/components.css, docs/design/components.html.

## Rules for every page file
- Path: docs/design/team-<a|b>/<page>.html, pages: home, radar, warnings, rainfall, location.
- `<link>` ../tokens-fluent2-light.css and ../components.css by relative path. Reuse component classes from components.css; page-specific CSS goes in one `<style>` block in the page and uses only `var(--*)` tokens for color, spacing, radius, shadow, type.
- Light theme only. No dark theme of any form.
- Top of file: HTML comment listing every function from page-inventory.md that this page covers.
- Show the default data state, plus loading / error / empty / permission-denied states as additional frames side by side (or stacked) labeled with captions.
- Phone frame 375px wide is the primary design; the file must also not scroll horizontally at 1280px (center the frames).
- Inline SVG icons only (reuse the ones in components.html). No external resources except Google Fonts.
- Chinese UI text (Traditional), realistic Taiwan sample data from page-inventory.md §5.
- Bottom navigation with the 5 pages, active item = current page; link between page files so the mockup is clickable.
- Spacing on the 4px grid; every item in a row vertically centered; card contents share the same left edge.

## Team A — "Glanceable dashboard"
Hero-first layout: one large current-condition hero card at the top of each page, then stacked cards. Generous whitespace, larger type, horizontal scrollers for time series, card radius = largest radius token. Elevation via shadow tokens.

## Team B — "Dense information list"
Pivot/tab-first layout: compact app bar with Fluent pivot tabs under it, content as grouped lists and tables with dividers (stroke tokens), minimal shadows, smaller card radius. Optimized for scanning many values.

## Team-internal consistency
Each team's members must keep the same app bar, hero/pivot pattern, section heading style, and card/list style across pages. Read your teammates' finished page files in the same team folder before finishing and align to them; the home page designer's file is the reference when they conflict.
