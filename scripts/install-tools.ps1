# scripts/install-tools.ps1
# ─────────────────────────────────────────────────────────────────────────────
# Installs required development tools on Windows using Chocolatey:
#   - Docker Desktop
#   - GNU Make
#   - Git
#   - Python 3.12
#
# Run in an ELEVATED (Administrator) PowerShell window:
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\scripts\install-tools.ps1
# ─────────────────────────────────────────────────────────────────────────────
#Requires -RunAsAdministrator

function Log  { param($msg) Write-Host "[install-tools] $msg" -ForegroundColor Green }
function Warn { param($msg) Write-Host "[install-tools] $msg" -ForegroundColor Yellow }

# ── Install Chocolatey if missing ─────────────────────────────────────────────
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Log "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
} else {
    Log "Chocolatey already installed."
}

# ── Install tools ──────────────────────────────────────────────────────────────
$tools = @(
    @{ name = "git";            cmd = "git" },
    @{ name = "make";           cmd = "make" },
    @{ name = "python312";      cmd = "python" },
    @{ name = "docker-desktop"; cmd = "docker" }
)

foreach ($tool in $tools) {
    if (Get-Command $tool.cmd -ErrorAction SilentlyContinue) {
        Log "$($tool.name) is already installed."
    } else {
        Log "Installing $($tool.name)..."
        choco install $tool.name -y
    }
}

# ── Refresh PATH ──────────────────────────────────────────────────────────────
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

Log ""
Log "All tools installed. Open a NEW terminal and verify with:"
Log "  docker --version"
Log "  docker compose version"
Log "  make --version"
Log "  python --version"
Log ""
Warn "Docker Desktop requires a restart to complete setup."
Log "Next step: copy .env.example to .env and run  .\make.ps1 compose-up"
