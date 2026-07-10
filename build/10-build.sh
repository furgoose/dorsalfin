#!/usr/bin/bash

set -euo pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -euo pipefail for strict error handling.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

echo "::group:: Copy Bluefin Config from Common"

# Copy just files from @projectbluefin/common (includes 00-entry.just which imports 60-custom.just)
mkdir -p /usr/share/ublue-os/just/
shopt -s nullglob
cp -r /ctx/oci/common/bluefin/usr/share/ublue-os/just/* /usr/share/ublue-os/just/
shopt -u nullglob

# Shared overlay from @projectbluefin/common: provides the /usr/bin/ujust wrapper
# itself plus the shared/apps/default/update just recipes it imports (required -
# without these, `ujust` doesn't exist at all), along with cross-desktop systemd
# units, udev rules, and polkit rules (e.g. pcscd smart-card access).
rsync -rvK /ctx/oci/common/shared/ /

echo "::endgroup::"

echo "::group:: Overlay Brew Integration Files"

# Brew integration files from @ublue-os/brew OCI (tarball, systemd services, shell integration)
rsync -rvK /ctx/oci/brew/ /

echo "::endgroup::"

echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >>/usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /usr/share/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /usr/share/flatpak/preinstall.d/

# Copy YubiKey/GnuPG config templates (deployed per-user via `ujust setup-yubikey`)
mkdir -p /usr/share/ublue-os/yubikey/
cp /ctx/custom/yubikey/*.conf /usr/share/ublue-os/yubikey/

echo "::endgroup::"

echo "::group:: Install Packages"

# Install a minimal package to verify the cache is working
# This ensures the DNF cache is populated for future builds
dnf5 install -y tmux

# micro - simple, modern terminal text editor for quick config edits
dnf5 install -y micro

# just - required by the /usr/bin/ujust wrapper shipped in @projectbluefin/common's
# shared overlay; without it, `ujust` fails with "command not found: just"
dnf5 install -y just

# YubiKey / GnuPG smart-card tooling, per https://github.com/drduh/YubiKey-Guide
dnf5 install -y \
    gnupg2 gnupg2-scdaemon cryptsetup \
    pcsc-lite pcsc-lite-ccid \
    yubikey-manager yubikey-personalization-gui \
    pinentry-gnome3

# Example using COPR with isolated pattern:
# copr_install_isolated "ublue-os/staging" package-name

echo "::endgroup::"

echo "::group:: System Configuration"

# Apply default enablement for units brought in by the common shared overlay
# (their state is declared via /usr/lib/systemd/system-preset/*.preset)
systemctl preset-all

# Enable/disable systemd services
systemctl enable podman.socket
systemctl enable brew-setup.service
systemctl enable brew-update.timer
systemctl enable brew-upgrade.timer
systemctl enable pcscd.socket
# Example: systemctl mask unwanted-service

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

echo "Custom build complete!"
