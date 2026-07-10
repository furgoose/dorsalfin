# vim: set ft=make :
######################
### custom-yubikey.just
######################
## YubiKey / GnuPG smart-card setup, based on:
## https://github.com/drduh/YubiKey-Guide
## Deploys the hardened GnuPG config and SSH-agent shell integration.
## Generating keys and moving them to the YubiKey is deliberately left
## manual - see the guide for that (offline/air-gapped) part.

# Set up GnuPG for YubiKey-backed GPG and SSH keys
[group('YubiKey')]
setup-yubikey:
    #!/usr/bin/env bash
    set -euo pipefail

    CONF_SRC="/usr/share/ublue-os/yubikey"
    if [[ ! -d "$CONF_SRC" ]]; then
        echo "YubiKey config templates not found at $CONF_SRC."
        exit 1
    fi

    # Marks a deployed file as ours, so re-running this command updates it
    # silently instead of mistaking our own edits (e.g. the pinentry-program
    # line below) for user customization that needs a confirmation prompt.
    MANAGED_TAG="# Managed by ujust setup-yubikey - local edits here will be overwritten on re-run"

    mkdir -p -m 700 "$HOME/.gnupg"
    for f in gpg.conf gpg-agent.conf scdaemon.conf; do
        dest="$HOME/.gnupg/$f"
        if [[ -f "$dest" ]] && ! grep -qF "$MANAGED_TAG" "$dest"; then
            REPLY="n"
            read -r -p "~/.gnupg/$f already exists and isn't managed by this command. Overwrite with the hardened template? [y/N] " REPLY || true
            if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
                echo "Skipping $f"
                continue
            fi
        fi
        { cat "$CONF_SRC/$f"; echo "$MANAGED_TAG"; } >"$dest"
        chmod 600 "$dest"
    done

    # Pick a pinentry backend available on this system
    PINENTRY=""
    for candidate in pinentry-gnome3 pinentry-gtk-2 pinentry-curses pinentry; do
        if command -v "$candidate" &>/dev/null; then
            PINENTRY="$(command -v "$candidate")"
            break
        fi
    done
    if [[ -n "$PINENTRY" ]] && [[ -f "$HOME/.gnupg/gpg-agent.conf" ]] && ! grep -q "^pinentry-program" "$HOME/.gnupg/gpg-agent.conf"; then
        echo "pinentry-program $PINENTRY" >>"$HOME/.gnupg/gpg-agent.conf"
    fi

    gpgconf --kill gpg-agent 2>/dev/null || true

    if ! systemctl is-active --quiet pcscd.socket 2>/dev/null && ! systemctl is-active --quiet pcscd.service 2>/dev/null; then
        echo "Starting pcscd..."
        sudo systemctl enable --now pcscd.socket || echo "Could not start pcscd automatically; run 'sudo systemctl enable --now pcscd.socket' manually."
    fi

    MARKER="# Added by ujust setup-yubikey (GnuPG SSH agent)"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]] && ! grep -qF "$MARKER" "$rc"; then
            {
                echo ""
                echo "$MARKER"
                echo 'export GPG_TTY=$(tty)'
                echo 'export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)'
                echo "gpgconf --launch gpg-agent"
                echo "gpg-connect-agent updatestartuptty /bye > /dev/null"
            } >>"$rc"
            echo "Updated $rc"
        fi
    done

    FISH_CONF="$HOME/.config/fish/config.fish"
    if [[ -f "$FISH_CONF" ]] && ! grep -qF "$MARKER" "$FISH_CONF"; then
        {
            echo ""
            echo "$MARKER"
            echo "set -x GPG_TTY (tty)"
            echo "set -x SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)"
            echo "gpgconf --launch gpg-agent"
        } >>"$FISH_CONF"
        echo "Updated $FISH_CONF"
    fi

    echo ""
    echo "GnuPG hardened config installed to ~/.gnupg, and SSH-agent integration"
    echo "added to your shell rc. Restart your shell (or 'source ~/.bashrc') to"
    echo "pick up SSH_AUTH_SOCK/GPG_TTY."
    echo ""
    echo "Next: generate your Certify key and Subkeys and move them to the"
    echo "YubiKey. That step is intentionally manual and should be done"
    echo "offline - follow the official guide:"
    echo "  https://github.com/drduh/YubiKey-Guide"
