# Install Coddy from GitHub Releases (Windows amd64).
# Usage:
#   irm https://coddy.dev/install.ps1 | iex
#   .\install.ps1 [-Version "0.9.5"] [-InstallDir $path] [-Home $path]
param(
    [string]$Version = $env:CODDY_VERSION,
    [string]$Repo = $(if ($env:CODDY_REPO) { $env:CODDY_REPO } else { "coddy-project/coddy-agent" }),
    [string]$InstallDir = $(if ($env:CODDY_INSTALL_DIR) { $env:CODDY_INSTALL_DIR } else { "" }),
    [Alias("Home")]
    [string]$CoddyHome = $(if ($env:CODDY_HOME) { $env:CODDY_HOME } else { "" }),
    [string]$Api = $(if ($env:CODDY_API) { $env:CODDY_API } else { "https://api.github.com" }),
    [switch]$Yes  # accepted for compatibility; existing installs never prompt
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$Message) { Write-Host "coddy-install: $Message" }

if (-not $InstallDir) {
    $InstallDir = Join-Path $env:LOCALAPPDATA "Programs\coddy"
}
if (-not $CoddyHome) {
    $CoddyHome = Join-Path $env:USERPROFILE ".coddy"
}

$arch = "amd64"
if ($env:PROCESSOR_ARCHITECTURE -notmatch "64") {
    throw "coddy-install: Windows arm64 is not published yet; use amd64 Windows."
}

$headers = @{
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "coddy-install"
}

if ($Version) {
    $ver = $Version.TrimStart("v")
    $relUri = "$Api/repos/$Repo/releases/tags/$ver"
} else {
    $relUri = "$Api/repos/$Repo/releases/latest"
}

$rel = Invoke-RestMethod -Uri $relUri -Headers $headers
$tag = ($rel.tag_name -replace "^v", "").Trim()
if (-not $tag) { throw "coddy-install: empty release tag" }

$asset = "coddy_${tag}_windows_${arch}.zip"
$downloadUrl = "https://github.com/$Repo/releases/download/$tag/$asset"

New-Item -ItemType Directory -Force -Path $InstallDir, $CoddyHome, (Join-Path $CoddyHome "sessions"), (Join-Path $CoddyHome "skills") | Out-Null

$dest = Join-Path $InstallDir "coddy.exe"
# Running the installer over an existing binary is the consent: an update is
# what the script is for, so it just replaces it.
if (Test-Path $dest) {
    Write-Info "replacing existing $dest"
}

$tmp = Join-Path $env:TEMP ("coddy-install-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    Write-Info "downloading $asset ($tag)"
    $zipPath = Join-Path $tmp "archive.zip"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $tmp -Force
    $bin = Join-Path $tmp "coddy.exe"
    if (-not (Test-Path $bin)) { throw "coddy-install: archive missing coddy.exe" }
    Copy-Item -Path $bin -Destination $dest -Force
    Write-Info "installed $dest"
} finally {
    Remove-Item -Recurse -Force -Path $tmp -ErrorAction SilentlyContinue
}

# Write the example config as Windows text. The file in the repository ends its lines
# with a bare line feed, which Notepad before Windows 10 1809 shows as a single endless
# line - the first thing an operator does with this file is open it in an editor, so it
# arrives with CRLF endings and without a byte order mark, the shape every editor here
# writes and every YAML tool reads.
function Write-WindowsText([string]$Path, [string]$Text) {
    $normalized = ($Text -replace "`r`n", "`n") -replace "`n", "`r`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $normalized, $utf8NoBom)
}

$config = Join-Path $CoddyHome "config.yaml"
if (-not (Test-Path $config)) {
    $exampleUrl = "https://raw.githubusercontent.com/$Repo/$tag/config.example.yaml"
    Write-Info "fetching $exampleUrl"
    $exampleFile = Join-Path $env:TEMP ("coddy-config-" + [guid]::NewGuid().ToString() + ".yaml")
    try {
        Invoke-WebRequest -Uri $exampleUrl -OutFile $exampleFile -UseBasicParsing
        Write-WindowsText $config ([System.IO.File]::ReadAllText($exampleFile))
    } finally {
        Remove-Item -Force -Path $exampleFile -ErrorAction SilentlyContinue
    }
    Write-Info "created $config from release example"
} else {
    # A config saved as "Unicode" rather than UTF-8 is not a file Coddy can read, and
    # the parser cannot say so in words that help. Say it here instead.
    try {
        $head = [System.IO.File]::ReadAllBytes($config) | Select-Object -First 2
        if ($head.Count -eq 2 -and (($head[0] -eq 0xFF -and $head[1] -eq 0xFE) -or ($head[0] -eq 0xFE -and $head[1] -eq 0xFF))) {
            Write-Info "warning: $config is UTF-16 text; re-save it as UTF-8 or coddy will refuse to read it"
        }
    } catch {
        # Unreadable for any other reason is not this script's business.
    }
    Write-Info "kept existing $config"
}

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$InstallDir*") {
    $newPath = if ($userPath) { "$InstallDir;$userPath" } else { $InstallDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = "$InstallDir;$env:Path"
    Write-Info "added $InstallDir to user PATH (open a new terminal if needed)"
}

& $dest -v
Write-Info "next: set API keys in $config, then: coddy serve"
