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
              mem = 8192;

              graphics = {
                enable = true;
                backend = "gtk";
              };

              shares = [
                {
                  tag = "ro-store";
                  source = "/nix/store";
                  mountPoint = "/nix/.ro-store";
                  proto = "9p";
                }
                {
                  tag = "evidence";
                  source = "./shared";
                  mountPoint = "/evidence";
                  proto = "9p";
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
              extraGroups = [ "wheel" "wireshark" ];
            };

            security.sudo.wheelNeedsPassword = false;
            services.getty.autologinUser = "analyst";

            # ── Desktop (Sway) ──────────────────────────────────

            programs.sway = {
              enable = true;
              wrapperFeatures.gtk = true;
              extraPackages = with pkgs; [
                wofi
                wl-clipboard
                grim
                slurp
                mako
                i3status
              ];
            };

            environment.etc."sway/config".text = ''
              # Use Alt as modifier (Mod1) instead of Super (Mod4)
              set $mod Mod1
              set $term foot
              set $menu wofi --show drun

              # Core keybindings
              bindsym $mod+Return exec $term
              bindsym $mod+d exec $menu
              bindsym $mod+Shift+q kill
              bindsym $mod+Shift+c reload
              bindsym $mod+Shift+e exec swaymsg exit

              # Focus
              bindsym $mod+h focus left
              bindsym $mod+j focus down
              bindsym $mod+k focus up
              bindsym $mod+l focus right
              bindsym $mod+Left focus left
              bindsym $mod+Down focus down
              bindsym $mod+Up focus up
              bindsym $mod+Right focus right

              # Move
              bindsym $mod+Shift+h move left
              bindsym $mod+Shift+j move down
              bindsym $mod+Shift+k move up
              bindsym $mod+Shift+l move right
              bindsym $mod+Shift+Left move left
              bindsym $mod+Shift+Down move down
              bindsym $mod+Shift+Up move up
              bindsym $mod+Shift+Right move right

              # Layout
              bindsym $mod+b splith
              bindsym $mod+v splitv
              bindsym $mod+s layout stacking
              bindsym $mod+w layout tabbed
              bindsym $mod+e layout toggle split
              bindsym $mod+f fullscreen
              bindsym $mod+Shift+space floating toggle
              bindsym $mod+space focus mode_toggle
              bindsym $mod+a focus parent

              # Workspaces
              bindsym $mod+1 workspace number 1
              bindsym $mod+2 workspace number 2
              bindsym $mod+3 workspace number 3
              bindsym $mod+4 workspace number 4
              bindsym $mod+5 workspace number 5
              bindsym $mod+6 workspace number 6
              bindsym $mod+7 workspace number 7
              bindsym $mod+8 workspace number 8
              bindsym $mod+9 workspace number 9
              bindsym $mod+0 workspace number 10
              bindsym $mod+Shift+1 move container to workspace number 1
              bindsym $mod+Shift+2 move container to workspace number 2
              bindsym $mod+Shift+3 move container to workspace number 3
              bindsym $mod+Shift+4 move container to workspace number 4
              bindsym $mod+Shift+5 move container to workspace number 5
              bindsym $mod+Shift+6 move container to workspace number 6
              bindsym $mod+Shift+7 move container to workspace number 7
              bindsym $mod+Shift+8 move container to workspace number 8
              bindsym $mod+Shift+9 move container to workspace number 9
              bindsym $mod+Shift+0 move container to workspace number 10

              # Resize mode
              mode "resize" {
                bindsym h resize shrink width 10px
                bindsym j resize grow height 10px
                bindsym k resize shrink height 10px
                bindsym l resize grow width 10px
                bindsym Left resize shrink width 10px
                bindsym Down resize grow height 10px
                bindsym Up resize shrink height 10px
                bindsym Right resize grow width 10px
                bindsym Return mode "default"
                bindsym Escape mode "default"
              }
              bindsym $mod+r mode "resize"

              # Status bar
              bar {
                status_command i3status
              }
            '';

            programs.dconf.enable = true;
            services.dbus.enable = true;
            security.polkit.enable = true;

            xdg.portal = {
              enable = true;
              wlr.enable = true;
              extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
              config.common.default = [ "wlr" "gtk" ];
            };

            programs.wireshark.enable = true;

            fonts.packages = [ pkgs.nerd-fonts.fira-code ];

            environment.sessionVariables = {
              XDG_CURRENT_DESKTOP = "sway";
              XDG_SESSION_TYPE = "wayland";
            };

            environment.loginShellInit = ''
              if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
                exec sway
              fi
            '';

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
              wireshark     # GUI
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
              neovim
              tmux
              less
              lnav
              util-linux

              # Terminal (Wayland-native)
              foot
            ];

            # ── MOTD ─────────────────────────────────────────────

            users.motd = ''

              ══════════════════════════════════════════════════════
                DFIR Workstation  —  Hack the Box Sherlocks
              ══════════════════════════════════════════════════════

                Evidence:  /evidence       (host: ./shared)
                Work dir:  /home/analyst   (persistent 8 GB)
                Desktop:   Sway (Alt+Return → foot, Alt+d → wofi)

                Memory:    vol3
                Disk:      fls, foremost, testdisk
                Network:   wireshark (GUI), tshark, tcpdump
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
