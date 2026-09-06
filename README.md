# coddy.dev (GitHub Pages)

Landing site and install scripts for [Coddy Agent](https://github.com/coddy-project/coddy-agent).

Custom domain: **https://coddy.dev** (`CNAME` → `coddy.dev`).

## Contents

| File | Role |
|------|------|
| `index.html` | Landing page (Coddy UI tokens) |
| `styles.css` | Shared styles |
| `assets/` | Logo, `og-image.png` (1280×640 social preview), screenshots |
| `install.sh` | Linux / macOS installer |
| `install.ps1` | Windows installer |
| `robots.txt` | Crawl policy: everything allowed, AI crawlers listed explicitly, sitemap pointer |
| `sitemap.xml` | Single-URL sitemap with image entries |
| `llms.txt` | [llms.txt](https://llmstxt.org/) summary for AI assistants, links to the raw docs in `coddy-agent` |
| `404.html` | Branded not-found page served by GitHub Pages |
| `CNAME` | GitHub Pages custom domain |

Install scripts are maintained **only in this repo**, not in coddy-agent.

## Install

```bash
curl -fsSL https://coddy.dev/install.sh | bash
```

```powershell
irm https://coddy.dev/install.ps1 | iex
```

Social preview: `https://coddy.dev/assets/og-image.png`

## Search and AI visibility

`index.html` carries JSON-LD (`Organization`, `WebSite`, `SoftwareApplication`, `FAQPage`) and a visible FAQ section; `robots.txt`, `sitemap.xml` and `llms.txt` live in the repo root. The domain is proxied by Cloudflare, so crawler access is ultimately decided by the zone's **AI Crawl Control** and **managed robots.txt** settings, not by this repo. Quick checks after a deploy:

```bash
curl -sI -A 'Mozilla/5.0 (compatible; ClaudeBot/1.0)' https://coddy.dev/ | head -1   # expect 200
curl -s https://coddy.dev/robots.txt | head -20
npx --yes lighthouse https://coddy.dev/ --only-categories=seo,accessibility --quiet --chrome-flags='--headless=new'
npx --yes foglift-scan https://coddy.dev
```
