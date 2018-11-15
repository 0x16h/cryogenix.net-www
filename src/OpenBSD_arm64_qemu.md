#### OpenBSD/arm64 on QEMU with networking 

With the increasing popularity of ARM64/AArch64 systems, from the Raspberry Pi 3 and PINE64 to Fujitsu's move away from SPARC64 supercomputers, there hasn't been a better time to get started with learning this architecture.

I wanted to make a start to an Aarch64 assembly language tutorial but didn't have access to my RPi3, so I looked into the state of QEMU's emulation. I didn't need RPi3-specific hardware - which is just as well as I can't remember off-hand how the bootcode and start.elf crap would work with QEMU - anyway, I opted for a generic device using Linaro's EDK2 UEFI firmware.

The first pre-built EDK2 binary I downloaded wouldn't play nicely with the OpenBSD kernel so I grabbed a release mentioned by the [FreeBSD team](https://wiki.freebsd.org/arm64/QEMU) - which worked.

#### Prerequisites

- OpenBSD/amd64 host
- miniroot64.fs (arm64)
- [QEMU_EFI.fd](http://releases.linaro.org/components/kernel/uefi-linaro/16.02/release/qemu64/QEMU_EFI.fd) (v16.02) 
- QEMU (doas pkg_add qemu)

#### Network Prep

The procedure here is pretty much identical to that outlined in [faq16](https://www.openbsd.org/faq/faq16.html). We create a vether0 and bridge0 interface for our tap interface to NAT through egress.

    $ doas su -
    # echo 'inet 192.168.54.1 255.255.255.0 NONE' >/etc/hostname.vether0
    # echo 'add vether0' >/etc/hostname.bridge0
    # sh /etc/netstart vether0 
    # sh /etc/netstart bridge0 
    # sysctl net.inet.ip.forwarding=1

Add the following rule to /etc/pf.conf (replace egress if necessary with your network_interface:0):

    match out on egress from vether0:network to any nat-to (egress)

Reload our pf configuration:

    # pfctl -f /etc/pf.conf

Create /etc/dhcpd.conf so your VM can use dhcp:

    option domain-name "cryogenix.net"
    option domain-name-servers 1.1.1.1;

    subnet 192.168.54.0 netmask 255.255.255.0 {
    	option routers 192.168.54.1;
    	range 192.168.54.100 192.168.54.199;
    }

Start dhcpd:

    # rcctl -f start dhcpd

#### Preparing QEMU

Fetch miniroot64.fs, SHA256, SHA256.sig, and QEMU_EFI.fd:

    $ ftp https://cdn.openbsd.org/pub/OpenBSD/6.4/arm64/{SHA256,SHA256.sig,miniroot64.fs}
    $ ftp http://releases.linaro.org/components/kernel/uefi-linaro/16.02/release/qemu64/QEMU_EFI.fd 
    $ signify -Cp /etc/signify/openbsd-64-base.pub -x SHA256.sig miniroot64.fs

Create a qcow2 image to use as our disk:

    $ qemu-img create -f qcow2 root.qcow2 10G

#### Booting miniroot64.fs

Thanks to [jsg@](https://marc.info/?l=openbsd-arm&m=151582483025728&w=2) for the -M and -device arguments to use instead of -M raspi3.

    doas sh -c "qemu-system-aarch64 -runas $USER \
    -m 2048 \
    -M virt \
    -cpu cortex-a57 \
    -bios QEMU_EFI.fd \
    -device virtio-rng-device \
    -drive file=miniroot64.fs,format=raw,id=drive1 \
    -netdev tap,id=net0 -device virtio-net-device,netdev=net0 \
    -drive file=root.qcow2,if=none,id=drive0,format=qcow2 \
    -device virtio-blk-device,drive=drive0 \
    -nographic \
    -serial tcp::4450,server,telnet,wait"

In another terminal (hello, tmux!):

    $ telnet localhost 4450
    >> OpenBSD/arm64 BOOTAA64 0.13
    boot>

Proceed to install OpenBSD as normal; at set selection -x* -g* is recommended. To boot into your new system, remove the line with miniroot64.fs from the command above and perhaps saving the full command as a shell script for your convenience. We don't need the serial console anymore if you elected to start sshd at boot, so the -serial line could either be removed or changed to '-serial FILE:serial.log'.

    Tue Nov 13 16:43:48 GMT 2018
    
    OpenBSD/arm64 (foo.cryogenix.net) (console)
    
    login:

Done.

    $ uname -a
    OpenBSD foo.cryogenix.net 6.4 GENERIC#511 arm64
    
    $ sysinfo.pl
    Hostname: foo - OS: OpenBSD 6.4/arm64 - CPU:  - Processes: 31 
    Uptime: 2m - Users: 1 - Load Average: 1.19 - 
    Memory Usage: 26.94MB/1990.47MB (1.35%) - 
    Disk Usage: 0.62GB/9.73GB (6.42%)
    
    cc -dumpmachine: aarch64-unknown-openbsd6.4

As always, thank you for reading and all feedback is welcome. 
