# coddy.dev (GitHub Pages)

Landing site and install scripts for [Coddy Agent](https://github.com/coddy-project/coddy-agent).

Custom domain: **https://coddy.dev** (`CNAME` → `coddy.dev`).

## Contents

| File | Role |
|------|------|
| `index.html` | Landing page (Coddy UI tokens) |
| `compare/index.html` | Comparison page: Coddy against seventeen other agent harnesses, five tables |
| `nav.js` | Shared header behaviour (mobile drawer, anchor scrolling, release pill) used by every page |
| `styles.css` | Shared styles |
| `assets/` | Logo, `og-image.png` (1280×640 social preview), screenshots |
| `install.sh` | Linux / macOS installer: binary, man page, shell completions, and the rc-file block that wires them up |
| `install.ps1` | Windows installer |
| `robots.txt` | Crawl policy: everything allowed, AI crawlers listed explicitly, sitemap pointer |
| `sitemap.xml` | Sitemap with image entries for `/` and `/compare/` |
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

`install.sh` installs the binary into `~/.local/bin` and, when the release archive carries them, the
man page and the bash and zsh completions into the matching `share` directory. A user-level install
then writes one guarded block to the rc file of the login shell (`~/.zshrc`, or `~/.bashrc` /
`~/.bash_profile`) so a new terminal has the binary on `PATH`, `man coddy` finds the page, and Tab
completion works. The block is rewritten in place on every run rather than appended to; a system
prefix such as `/usr/local` gets none of it, and `--no-shell-setup` opts out.

Handy for testing the script against something other than a real release:

```bash
CODDY_API=http://127.0.0.1:8080 CODDY_DOWNLOAD_BASE=http://127.0.0.1:8080 ./install.sh -y
```

Social preview: `https://coddy.dev/assets/og-image.png`

## Search and AI visibility

`index.html` carries JSON-LD (`Organization`, `WebSite`, `SoftwareApplication`, `FAQPage`) and a visible FAQ section, `compare/index.html` adds `Article`, `WebPage`, `BreadcrumbList`, `ItemList` and its own `FAQPage`; `robots.txt`, `sitemap.xml` and `llms.txt` live in the repo root. The domain is proxied by Cloudflare, so crawler access is ultimately decided by the zone's **AI Crawl Control** and **managed robots.txt** settings, not by this repo. Quick checks after a deploy:

```bash
curl -sI -A 'Mozilla/5.0 (compatible; ClaudeBot/1.0)' https://coddy.dev/ | head -1   # expect 200
curl -s https://coddy.dev/robots.txt | head -20
npx --yes lighthouse https://coddy.dev/ --only-categories=seo,accessibility --quiet --chrome-flags='--headless=new'
npx --yes foglift-scan https://coddy.dev
```
