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

To build the VM, first start a container emulating NixOS:
```bash
sudo docker run -it --rm --name qemu -e "BOOT=https://channels.nixos.org/nixos-23.11/latest-nixos-minimal-x86_64-linux.iso" -p 8006:8006 -p 2022:22 --device=/dev/kvm --cap-add NET_ADMIN qemux/qemu-docker
```
> [!CAUTION]
> This requires KVM. If you don't have KVM enabled, please enable it as this process will be incredibly slow without it. 
> 
> However, if your system doesn't support KVM at all, run this command instead:
> ```bash
> sudo docker run -it --rm --name qemu -e "BOOT=https://channels.nixos.org/nixos-23.11/latest-nixos-minimal-x86_64-linux.iso" -e "KVM=N" -p 8006:8006 -p 2022:22 --cap-add NET_ADMIN qemux/qemu-docker
> ```

Now, you need to navigate to [localhost:8006](https://localhost:8006) in your browser and add a password to the VM via the `passwd` command. It doesn't need to be secure because the VM won't store any vulnerable information. It just needs to exist because NixOS doesn't allow SSH connections without a password.

Now, you can SSH into [nixos@localhost:2022](ssh://nixos@localhost:2022) to transfer the `configuration.nix` file to the VM and build using `nixos-generators`.

Once you've built an ISO and downloaded it from the VM, you can clean up your environment and delete the VM with `sudo docker stop qemu && sudo docker rm qemu`.
