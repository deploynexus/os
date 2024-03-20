{ config, pkgs, ... }: {

    # import installer configuration
    imports = [ <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix> ];

    # enable ssh via port 22
    services.openssh.enable = true;
   
    # shouldn't need all of these, but they might be useful
    environment.systemPackages = with pkgs; [ neofetch curl inotify-tools nettools coreutils htop gnutar gzip nixos-generators ];

    # daemon that listens for instructions from the host, and runs them
    systemd.services.nxsbstpd = {
        description = "Nexus Bootstrapper";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
            ExecStart = let
                script = pkgs.writeShellScript "nxsbstpd" ''
                    echo "Starting..."
                    # ensure clean state
                    rm -rf /nexus_bootstrap
                    mkdir /nexus_bootstrap
                    touch /nexus_bootstrap/pipe_in
                    touch /nexus_bootstrap/pipe_out
                    # begin waiting for updates
                    echo "Waiting for instructions..."
                    while inotifywait -e modify /nexus_bootstrap/pipe_in; do
                        bash /nexus_bootstrap/pipe
                    done
                '';
            in "${script}";
        };
    };
    
    # user the host communicates to the vm with
    users.users.nxsbstpd = {
        isNormalUser = true;
        description = "Nexus Bootstrapper";
        extraGroups = [ "wheel" ];
        password = "password"; # this is fine its a public account
    };

}
