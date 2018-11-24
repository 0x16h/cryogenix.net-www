#### Cross-compiling for OpenBSD/arm64

Following on from [OpenBSD/arm64 on QEMU](https://cryogenix.net/OpenBSD_arm64_qemu.html), it's not always practical to compile userland software or a new kernel on some systems, particularly small SoCs with limited space and memory - or indeed QEMU, in fear of melting your CPU. 

There are two scenarios here - the first, if you are looking for a standard cross-compiler for Aarch64, and the second if you want an OpenBSD-specific environment.

#### Scenario 1: Linaro ARM/AArch64 toolchain

Available in ports, this is the go-to GCC toolchain for cross-compilation to ARM targets.  aarch64-none-elf-gcc-linaro is relatively new and there doesn't exist a port for gdb nor newlib as yet.

This will pull in binutils and gcc, which will be installed to /usr/local/aarch64-none-elf-*:

    doas pkg_add aarch64-none-elf-gcc-linaro

The 32-bit ARM toolchain is also available, which includes GDB and newlib for the ARM target. 32-bit ARM binaries will run on Aarch64, which is why you see devices such as the Raspi3 having 32-bit or mixed-arch operating systems (64-bit kernel, 32-bit userland for example).

    doas pkg_add arm-none-eabi-gcc-linaro 
    doas pkg_add arm-none-eabi-gdb
    doas pkg_add arm-none-eabi-newlib

This will give us a traditional cross-compilation environment with gdb built to use your host, in my case x86_64-unknown-openbsd6.4 and a target of arm-none-eabi. Newlib is an implementation of the standard C library which was intended to be a free library for embedded devices and is popular with OS development hobbyists at stages where they have not written their own implementations.  This will allow us to write and compile C code that uses the std C library.


#### Scenario 2: OpenBSD aarch64 development

Cross-building is unsupported on OpenBSD - if you've ever dabbled in OS development or LinuxFromScratch, you can probably guess why; it can be unpredictable.
Moreover, the OpenBSD platform lifecycle focuses on making OpenBSD self-hosting and only cross-compiles to the target platform for initial bootstrapping.

There, you have been duly warned; now let's get down to building our AArch64 toolchain!

I must admit, I have never looked at /usr/src/Makefile.cross before - so instead of jumping in I had a look to see if there was any existing resources on the process.

- [openbsd-cross-building-tips](https://gist.github.com/uebayasi/6328591) by [Masao Uebayashi](https://github.com/uebayasi)
- [arm@ list: error in cross-compiling for armv7](http://openbsd-archive.7691.n7.nabble.com/error-in-cross-compiling-for-armv7-td300810.html)

As the process is unsupported anyway, I'm not using /usr/src. We can't even build a release without hacking to death the Makefiles and wrappers so that may be in a future article.  Grab the source somewhere in your home dir:

    mkdir arm64
    cd arm64
    cvs -qd anoncvs@anoncvs.fr.openbsd.org:/cvs checkout -rOPENBSD_6_4 -P src

Set some environment variables for our build tree:

    target=arm64
    topdir=${HOME}/arm64
    srcdir=${topdir}/src
    destdir=${topdir}/dest.${target}
    objdir=${topdir}/obj.${target}
    toolsdir=${topdir}/tools.${target}
    cd ${srcdir}

As root, we create the directories for our toolchain, set the environment, then build the toolchain itself.  Aarch64 is strictly an llvm/lld platform on OpenBSD (thanks, brynet!) - but for some reason when I tried to build the toolchain it complained about ld.bfd being missing from somewhere in ${destdir}... quick solution: touch the file and run make again as below!
 
    doas make -f Makefile.cross TARGET=${target} CROSSDIR=${destdir} cross-env
    doas make -f Makefile.cross TARGET=${target} CROSSDIR=${destdir} cross-dirs
    doas make -f Makefile.cross TARGET=${target} CROSSDIR=${destdir} cross-tools

Build and install Aarch64 userland to our destination:

    doas make -f Makefile.cross TARGET=${target} CROSSDIR=${destdir} cross-distrib

Create some convient links

    ln -sf ${destdir}/usr/obj ${objdir}
    ln -sf ${destdir}/usr/${target}-unknown-openbsd6.4 ${toolsdir}

chown everything back to your user and group (modify as required):

    doas chown -R ${USER}:${USER} ${objdir}/*

Finally, test our environment out by compiling a C file with cc (clang):

    $ eval export $( make -f Makefile.cross TARGET=${target} CROSSDIR=${destdir} cross-env )
    $ cd ..
    $ cat <<EOF >>hello.c
    #include <stdio.h>
    
    int
    main(void) {
    	printf("Hello Aarch64\n");
    }
    EOF
    
    $ ${CC} -o hello hello.c
    $ file hello
    hello: ELF 64-bit LSB shared object, AArch64, version 1
    
    $ ${destdir}/usr/aarch64-unknown-openbsd6.4/bin/readelf -h hello

    ELF Header:
    Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00 
    Class:                             ELF64
    Data:                              2's complement, little endian
    Version:                           1 (current)
    OS/ABI:                            UNIX - System V
    ABI Version:                       0
    Type:                              DYN (Shared object file)
    Machine:                           AArch64
    <--CUT-->

All working as expected!

