# YubiKey / GnuPG Configuration

This directory contains the hardened GnuPG config templates from
[drduh/YubiKey-Guide](https://github.com/drduh/YubiKey-Guide), used to configure
the image for GPG- and SSH-over-smartcard use with a YubiKey.

## How It Works

1. **During Build**: `gpg.conf`, `gpg-agent.conf`, and `scdaemon.conf` are copied
   into the image at `/usr/share/ublue-os/yubikey/`, and the required packages
   (`gnupg2`, `pcsc-lite`, `pcsc-lite-ccid`, `yubikey-manager`,
   `yubikey-personalization-gui`, `pinentry-gnome3`, `cryptsetup`) are installed.
   The `pcscd.socket` smart-card service is enabled.
2. **At Runtime**: A user opts in by running `ujust setup-yubikey`, which copies
   these templates into `~/.gnupg/`, picks an available `pinentry` backend, and
   wires up `SSH_AUTH_SOCK`/`GPG_TTY` in their shell rc so `gpg-agent` can serve
   as their SSH agent.

## What This Does NOT Do

Generating your Certify/Subkeys, moving them onto the physical YubiKey, and
setting PINs are deliberately **not** automated. The upstream guide recommends
doing this offline/air-gapped with the key in hand, so `ujust setup-yubikey`
only prepares the software environment and points you at
[the guide](https://github.com/drduh/YubiKey-Guide) for the rest.

## Files

- [`gpg.conf`](gpg.conf) - cipher/digest preferences, long key IDs, cross-certification
- [`gpg-agent.conf`](gpg-agent.conf) - enables SSH support, sets cache TTLs
- [`scdaemon.conf`](scdaemon.conf) - `disable-ccid`, avoids duplicate-prompt bug with pcscd

See [`custom/ujust/custom-yubikey.just`](../ujust/custom-yubikey.just) for the
setup command, and [`build/10-build.sh`](../../build/10-build.sh) for the
package/service configuration.
