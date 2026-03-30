# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Nix Flake-based DFIR (Digital Forensics and Incident Response) microVM for solving Hack the Box Sherlock challenges. The entire system — desktop environment, forensics tools, user config, and VM parameters — is declaratively defined in `flake.nix`.

## Architecture

The host runs a QEMU microVM (via microvm.nix) with a NixOS guest. Key mount points:
- **`/nix/.ro-store`** — Host Nix store shared read-only via virtiofs (high performance)
- **`/evidence`** — `./shared/` directory mounted via 9p (place challenge archives here)
- **`/home/analyst`** — 8 GB persistent disk image (`sherlock-work.img`)

The guest runs Sway (Wayland tiling WM) with autologin as `analyst` (passwordless sudo). Networking is user-mode NAT (outbound only).

## Commands

```bash
# Build and run the VM
nix run

# Rebuild after flake.nix changes (the microvm-run script handles virtiofsd + QEMU startup)
nix build

# Update dependency pins
nix flake update
```

All configuration lives in `flake.nix` — there is no separate NixOS configuration directory.

## Key Sections of flake.nix

- **Lines ~33-50**: Package overrides (oletools test fix, Wireshark icon cache fix)
- **Lines ~56-97**: MicroVM hardware config (vCPUs, memory, shares, volumes, graphics)
- **Lines ~104-130**: NixOS system basics (hostname, TLS certs, user account)
- **Lines ~132-244**: Sway desktop environment config (keybindings, status bar, theming)
- **Lines ~276-356**: Installed DFIR packages (forensics tools, Python libraries)
- **Lines ~388-417**: `microvm-run` startup script (virtiofsd daemon + VM launch)

## Forensics Tooling

The VM includes: volatility3, sleuthkit, wireshark/tshark/tcpdump, yara, binwalk, chainsaw, radare2, exiftool, and a Python environment with pefile, oletools, scapy, impacket, dissect, evtx, malduck, and more.

## Known Workarounds

- **Wireshark icon cache**: Custom derivation pre-caches GTK icons to avoid a 75-second startup hang from 143K futile `access()` calls
- **Oletools tests**: Disabled due to pyparsing deprecation warning failures
- **QEMU cursor**: Hardware cursors disabled (`WLR_NO_HARDWARE_CURSORS=1`) to fix upside-down/misaligned cursor with virtio-gpu
- **Proxy CA**: `proxy-ca.crt` added for TLS-intercepting proxy support
