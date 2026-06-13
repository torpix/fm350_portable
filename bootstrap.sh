#!/bin/sh
set -eu

if command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER=pacman
elif command -v apt >/dev/null 2>&1; then
    PKG_MANAGER=apt
else
    printf '%s\n' 'ERROR: no supported package manager found (pacman/apt)' >&2
    exit 1
fi

if ! command -v fish >/dev/null 2>&1; then
    case "$PKG_MANAGER" in
        pacman)
            sudo pacman -S --needed --noconfirm fish
            ;;
        apt)
            sudo apt update
            sudo apt install -y fish
            ;;
    esac
fi

if ! command -v git >/dev/null 2>&1; then
    printf '%s\n' 'ERROR: git is not installed' >&2
    exit 1
fi

sudo fish ./install_fm350.fish --autoconnect yes
