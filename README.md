# coddy.dev (GitHub Pages)

Landing site and **install scripts** for [Coddy Agent](https://github.com/coddy-project/coddy-agent).

Planned custom domain: **coddy.dev** (add a `CNAME` file with that hostname when DNS is ready).

## Contents

| File | Role |
|------|------|
| `index.html` | Landing page (Coddy UI tokens) |
| `styles.css` | Shared styles |
| `assets/` | Logo and screenshots |
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

After **coddy.dev** CNAME is active, the same paths work on `https://coddy.dev/install.sh`.
