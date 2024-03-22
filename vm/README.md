# vm
The OS builder uses the `nixos-generators` program to create an ISO users can work with. The most efficent way to use this tool is by running it inside NixOS, as building for Arm processors on x86 hardware is much easier than it would be if it were running on another OS.

To do this, the OS builder emulates an x86 system running NixOS using QEMU. To make the process easier for users, QEMU is ran in a Docker container, which is managed in tandem with other containers the OS builder uses via Docker Compose. Users can then use Docker Compose to run the OS builder.

## how it works
On boot, the VM begins watching for changes to the `/nexus_bootstrap/pipe_in` file via the `inotify(7)` API. When this file changes, the VM executes it as a Bash script.

At some undefined time later, a process running in another Docker container will connect to the VM via SSH and begin editing the file. This is how data is sent in and out of the VM &mdash; the file acts as a pipe, sending data (in the form of bash commands) to the VM.

The VM also has a file, `/nexus_bootstrap/pipe_out`. This file is watched by the container managing the SSH connection with the VM. This file is used to pipe data out of the VM.

When the user is ready to build an ISO, build instructions and necessary information are piped into the VM. Once the VM completes the build, it pipes back out the location of the build and instructions on downloading the build from the VM.

## building the vm
The NixOS installer images provided by the NixOS maintainers do not contain enough tooling to support this process automatically. Therefore, we must use `nixos-generators` to create an ISO of the builder VM. The ISO is based on the `configuration.nix` file located beside this README. It includes all the tooling necessary for the VM.

> [!IMPORTANT]
> Building the VM requires KVM, 4 CPU cores, 16GB of ram, and 128GB of disk space by default. In many cases, the VM doesn't need this much and you can lower these to something you can handle.

To build the VM, follow these steps:
1. Spawn a NixOS 23.11 Docker container using the following command:
   ```bash
   sudo docker run -it --rm --name qemu --cpus=4 --memory=16GB -e "BOOT=https://channels.nixos.org/nixos-23.11/latest-nixos-minimal-x86_64-linux.iso" -e "CPU_CORES=4" -e "RAM_SIZE=16GB" -e "DISK_SIZE=128GB" -p 8006:8006 -p 2022:22 --device=/dev/kvm --cap-add NET_ADMIN qemux/qemu-docker
   ```
2. Open [localhost:8006](https://localhost:8006) in your browser. You should now be connected to the container using VNC. You'll need to add a password to the root account to be able to connect to it via SSH, so run the following commands in the VNC window:
   ```bash
   sudo -i
   passwd
   ```
3. On the host machine, open a terminal at the root of this repository and run the following to copy the VM's configuration file to the container:
   ```bash
   scp -P 2022 ./vm/configuration.nix root@localhost:/
   ```
4. SSH into [root@localhost:2022](ssh://root@localhost:2022) and run the following commands in the container to build the VM:
   ```bash
   cd /
   nix-shell -p nixos-generators --run "nixos-generate -c configuration.nix -f iso -I nixpkgs=channel:nixos-23.11 -o /nexus"
   ```
5. On the host machine, open another terminal at the root of this repository (or use the previous one if it's still open) and run the following to download the VM from the container and kill it:
   ```bash
   scp -P 2022 root@localhost:/nexus/iso/*.iso ./vm/vm.iso
   chmod +w ./vm/vm.iso
   sudo docker stop qemu
   sudo docker rm qemu
   ```
You've now successfully built the VM! You can find it beside this README as `vm.iso`.