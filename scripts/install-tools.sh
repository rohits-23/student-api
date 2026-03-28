#!/usr/bin/env bash
# scripts/install-tools.sh
# ─────────────────────────────────────────────────────────────────────────────
# Installs required development tools:
#   - Docker Engine / Docker Compose
#   - GNU Make
#   - Git
#   - Python 3.12+
#
# Supported OS: Ubuntu/Debian, macOS (via Homebrew)
# Run as root or with sudo: bash scripts/install-tools.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[install-tools]${NC} $*"; }
warn() { echo -e "${YELLOW}[install-tools]${NC} $*"; }
err()  { echo -e "${RED}[install-tools]${NC} $*" >&2; exit 1; }

require_command() {
    if command -v "$1" &>/dev/null; then
        log "$1 is already installed ($(command -v "$1"))"
        return 0
    fi
    return 1
}

# ── Detect OS ─────────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
    Linux*)   PLATFORM=linux ;;
    Darwin*)  PLATFORM=macos ;;
    *)        err "Unsupported OS: $OS. Use Windows instructions in README.md." ;;
esac
log "Platform detected: $PLATFORM"

# ─────────────────────────────────────────────────────────────────────────────
# macOS — install via Homebrew
# ─────────────────────────────────────────────────────────────────────────────
install_macos() {
    if ! command -v brew &>/dev/null; then
        log "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        log "Homebrew already installed."
    fi

    log "Updating Homebrew..."
    brew update

    for pkg in git make python@3.12; do
        if brew list "$pkg" &>/dev/null; then
            log "$pkg already installed."
        else
            log "Installing $pkg..."
            brew install "$pkg"
        fi
    done

    if ! command -v docker &>/dev/null; then
        log "Installing Docker Desktop via Homebrew cask..."
        brew install --cask docker
        warn "Docker Desktop installed. Open the Docker Desktop app once to complete setup."
    else
        log "Docker already installed."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Linux (Ubuntu / Debian)
# ─────────────────────────────────────────────────────────────────────────────
install_linux() {
    log "Updating apt package list..."
    sudo apt-get update -qq

    # Git
    if ! require_command git; then
        log "Installing git..."
        sudo apt-get install -y git
    fi

    # Make
    if ! require_command make; then
        log "Installing make..."
        sudo apt-get install -y make
    fi

    # Python 3.12
    if ! require_command python3.12; then
        log "Installing Python 3.12..."
        sudo apt-get install -y software-properties-common
        sudo add-apt-repository -y ppa:deadsnakes/ppa
        sudo apt-get update -qq
        sudo apt-get install -y python3.12 python3.12-venv python3.12-dev
    fi

    # Docker Engine
    if ! require_command docker; then
        log "Installing Docker Engine..."
        sudo apt-get install -y ca-certificates curl gnupg lsb-release
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
            https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" \
            | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -qq
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo usermod -aG docker "$USER"
        warn "Docker installed. Log out and back in for group permissions to take effect."
    fi

    # Docker Compose plugin check
    if ! docker compose version &>/dev/null 2>&1; then
        log "Installing Docker Compose plugin..."
        sudo apt-get install -y docker-compose-plugin
    else
        log "Docker Compose already available."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Run installer
# ─────────────────────────────────────────────────────────────────────────────
case "$PLATFORM" in
    macos) install_macos ;;
    linux) install_linux ;;
esac

log ""
log "All tools installed. Verify with:"
log "  docker --version"
log "  docker compose version"
log "  make --version"
log "  python3.12 --version"
log ""
log "Next step: copy .env.example to .env and run  make compose-up"
