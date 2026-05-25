# coddy.dev (GitHub Pages)

Landing site and **install scripts** for [Coddy Agent](https://github.com/coddy-project/coddy-agent).

Planned custom domain: **coddy.dev** (add a `CNAME` file with that hostname when DNS is ready).

## Contents

| File | Role |
|------|------|
| `index.html` | Landing page (Coddy UI tokens) |
| `styles.css` | Shared styles |
| `assets/` | Logo, `og-image.png` (1280x640 social preview for Open Graph), screenshots |
| `install.sh` | Linux / macOS installer |
| `install.ps1` | Windows installer |

Install scripts are maintained **only in this repo**, not in coddy-agent.

## Publish

Push to `main` on the GitHub Pages branch configured for this repository.

## Install URLs

```bash
curl -fsSL https://coddy-project.github.io/install.sh | bash
```

```powershell
irm https://coddy-project.github.io/install.ps1 | iex
```

After **coddy.dev** CNAME is active, add `CNAME` with `coddy.dev` and update `canonical` / `og:*` URLs in `index.html` (or rely on the hostname script block).

Social preview image: `assets/og-image.png` (from `coddy-logo-social-1280x640.png` in the agent repo).
