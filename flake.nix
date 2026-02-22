{
  description = "Air-gapped DFIR VM for Hack the Box Sherlock challenges (microvm.nix + QEMU)";

  # Optional: add to ~/.config/nix/nix.conf for faster builds:
  #   extra-substituters = https://microvm.cachix.org
  #   extra-trusted-public-keys = microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys=

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, microvm }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.sherlock = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          microvm.nixosModules.microvm
          ({ pkgs, ... }: {

            # ── MicroVM ──────────────────────────────────────────

            microvm = {
              hypervisor = "qemu";
              vcpu = 4;
              mem = 4096;

              shares = [
                {
                  tag = "ro-store";
                  source = "/nix/store";
                  mountPoint = "/nix/.ro-store";
                  proto = "virtiofs";
                }
                {
                  tag = "evidence";
                  source = "./shared";
                  mountPoint = "/evidence";
                  proto = "virtiofs";
                }
              ];

              volumes = [
                {
                  image = "sherlock-work.img";
                  mountPoint = "/home/analyst";
                  size = 8192;
                  autoCreate = true;
                }
              ];

              interfaces = []; # air-gapped — no network
            };

            # ── Nixpkgs ──────────────────────────────────────────

            nixpkgs.config.allowUnfreePredicate = pkg:
              builtins.elem (pkgs.lib.getName pkg) [ "volatility3" ];

            # ── System ───────────────────────────────────────────

            system.stateVersion = "24.11";
            networking.hostName = "sherlock";
            networking.useDHCP = false;
            time.timeZone = "UTC";

            boot.tmp = {
              useTmpfs = true;
              tmpfsSize = "2G";
            };

            # ── User ────────────────────────────────────────────

            users.users.analyst = {
              isNormalUser = true;
              home = "/home/analyst";
              extraGroups = [ "wheel" ];
            };

            security.sudo.wheelNeedsPassword = false;
            services.getty.autologinUser = "analyst";

            # Ensure correct ownership after volume mount
            systemd.tmpfiles.rules = [
              "d /home/analyst 0700 analyst users -"
            ];

            # ── DFIR Tooling ─────────────────────────────────────

            environment.systemPackages = with pkgs; [
              # Memory forensics
              volatility3

              # Disk forensics
              sleuthkit
              testdisk
              foremost

              # Network capture analysis
              wireshark-cli # tshark
              tcpdump

              # Malware / pattern matching
              yara
              binwalk
              ssdeep

              # Windows artifacts
              chainsaw

              # Binary inspection
              file
              binutils # strings
              xxd
              radare2
              exiftool

              # Archives
              p7zip
              unzip

              # Data processing
              jq
              ripgrep
              fd
              bat
              hexyl

              # Python environment
              (python3.withPackages (ps: with ps; [
                pefile
                oletools
                yara-python
                scapy
                dpkt
                evtx
                impacket
                malduck
                dissect
                lnkparse3
                python-registry
                ipython
                pandas
              ]))

              # Utilities
              vim
              tmux
              less
              util-linux
            ];

            # ── MOTD ─────────────────────────────────────────────

            users.motd = ''

              ══════════════════════════════════════════════════════
                DFIR Workstation  —  Hack the Box Sherlocks
              ══════════════════════════════════════════════════════

                Evidence:  /evidence       (host: ./shared)
                Work dir:  /home/analyst   (persistent 8 GB)

                Memory:    vol3
                Disk:      fls, foremost, testdisk
                Network:   tshark, tcpdump
                Malware:   yara, binwalk, ssdeep, chainsaw
                Binary:    r2, strings, exiftool, hexyl
                Python:    pefile, oletools, scapy, impacket,
                           malduck, dissect, evtx, lnkparse3,
                           python-registry, pandas, ipython

                No network — air-gapped by design
                Shutdown:  sudo poweroff

              ══════════════════════════════════════════════════════
            '';
          })
        ];
      };

      packages.${system}.default =
        self.nixosConfigurations.sherlock.config.microvm.declaredRunner;
    };
}
