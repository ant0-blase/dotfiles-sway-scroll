#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./install.sh [--no-deps]

Install required Arch packages, then link the config directories into
$XDG_CONFIG_HOME (or ~/.config). Use --no-deps to create links only.
EOF
}

install_deps=true
case "${1:-}" in
    '') ;;
    --no-deps) install_deps=false ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
config_home="${XDG_CONFIG_HOME:-"$HOME/.config"}"
configs=(alacritty gtk-3.0 gtk-4.0 rofi scroll waybar)

if (( EUID == 0 )); then
    printf 'Run this script as your regular user, not as root.\n' >&2
    exit 1
fi

if [[ "$config_home" != /* ]]; then
    printf 'XDG_CONFIG_HOME must be an absolute path: %s\n' "$config_home" >&2
    exit 1
fi

for name in "${configs[@]}"; do
    if [[ ! -d "$script_dir/$name" ]]; then
        printf 'Config directory not found: %s\n' "$script_dir/$name" >&2
        exit 1
    fi
done

if [[ "$install_deps" == true ]]; then
    if [[ ! -r /etc/os-release ]]; then
        printf 'Cannot identify this distribution. Arch Linux is required for dependency installation.\n' >&2
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
        *' arch '*) ;;
        *)
            printf 'Dependency installation supports Arch Linux and Arch-based distributions.\n' >&2
            printf 'Use --no-deps to link the configs without installing packages.\n' >&2
            exit 1
            ;;
    esac

    if ! command -v pacman >/dev/null 2>&1; then
        printf 'pacman is required to install dependencies.\n' >&2
        exit 1
    fi

    packages=(
        adwaita-cursors
        alacritty
        bluez
        bluez-utils
        blueman
        brightnessctl
        code
        dbus
        firefox
        grim
        gtk3
        gtk4
        libpulse
        mako
        network-manager-applet
        networkmanager
        pcmanfm
        playerctl
        polkit-gnome
        psmisc
        rofi
        slurp
        swaybg
        swaylock
        ttf-jetbrains-mono-nerd
        virt-manager
        waybar
        wf-recorder
        wl-clipboard
        xdg-user-dirs
        xorg-xwayland
    )

    aur_packages=()
    if ! command -v scroll >/dev/null 2>&1 || ! command -v scrollmsg >/dev/null 2>&1; then
        packages+=(base-devel git)
        aur_packages+=(sway-scroll-git)
    fi

    if ((${#aur_packages[@]})); then
        aur_helper=''
        if command -v paru >/dev/null 2>&1; then
            aur_helper=paru
        elif command -v yay >/dev/null 2>&1; then
            aur_helper=yay
        else
            printf 'Scroll is not installed. Install yay or paru first to fetch sway-scroll-git from the AUR.\n' >&2
            exit 1
        fi
        "$aur_helper" -S --needed "${packages[@]}" "${aur_packages[@]}"
    else
        if ! command -v sudo >/dev/null 2>&1; then
            printf 'sudo is required to install packages with pacman.\n' >&2
            exit 1
        fi
        sudo pacman -S --needed "${packages[@]}"
    fi
fi

mkdir -p -- "$config_home"
config_home="$(cd -- "$config_home" && pwd -P)"

for name in "${configs[@]}"; do
    source_dir="$script_dir/$name"
    target="$config_home/$name"

    if [[ -L "$target" && "$(readlink -- "$target")" == "$source_dir" ]]; then
        printf '[=] Already linked: %s\n' "$target"
        continue
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        stamp="$(date +%Y%m%d-%H%M%S)"
        backup="$target.bak-$stamp"
        suffix=1
        while [[ -e "$backup" || -L "$backup" ]]; do
            backup="$target.bak-$stamp-$suffix"
            suffix=$((suffix + 1))
        done
        mv -- "$target" "$backup"
        printf '[~] Backed up: %s\n' "$backup"
    fi

    ln -s -- "$source_dir" "$target"
    printf '[+] Linked: %s -> %s\n' "$target" "$source_dir"
done

printf 'Configs installed in %s\n' "$config_home"
