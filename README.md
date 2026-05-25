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
