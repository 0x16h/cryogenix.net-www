#### AlphaServer ES40 Emulation
Emulating an AlphaServer ES40 for running Tru64 UNIX or OpenVMS

This article was originally written for CentOS. Building ES40 on OpenBSD requires some extra work; I'll port it soon and update this page in the near future. -- 31-OCT-2018

The  [ES40 Emulator](http://www.es40.org/)  is a portable  [AlphaServer ES40](https://web.archive.org/web/20090606221007/http://www.compaq.com/alphaserver/es40/)  emulator. In many ways it is not unlike the Bochs IA-32 emulator in that it is portable, and provides VGA support through a VGA BIOS and the use of SDL, X11 or Win32 API calls.

As well as emulating a DEC Alpha AXP EV68CB CPU, the ES40 Emulator also recreated the  [Typhoon Chipset](http://www.es40.org/Typhoon), the  [Ali M1543C](http://www.es40.org/Ali_M1543C)  and additional  [devices](http://www.es40.org/Devices)  that a functioning ES40 system would require.

We are going to build and configure ES40 on a UNIX-like system without X11 or SDL support as we will be treating it as a virtual server and ES40 doesn't support running DECWindows yet anyway (but feel free to configure DECWindows with XDM or X11 Forwarding later).
### Prerequisites

As per  [the instructions](https://web.archive.org/web/20090606221007/http://www.es40.org/Building_the_Emulator_on_UNIX%2C_BSD%2C_Linux%2C_etc)  for building ES40, you will need to make sure the following are available:

-   GNU C/C++, make, unzip etc
-   [es40\_018\_src.zip](http://sourceforge.net/project/showfiles.php?group_id=187340&package_id=218669&release_id=581747)
-   [Poco C++ Libraries (1.3.2+)](https://github.com/pocoproject/poco/releases)
-   OpenSSL/LibreSSL
-   libpcap
-   OpenVMS 8.3 Alpha or Tru64 Installation kit (and hobbyist license from [HPE](https://www.hpe.com/h41268/live/index_e.aspx?qid=24548))
-   [cl67srmrom.exe](cl67srmrom.exe) from [es40.zip](https://web.archive.org/web/20090606221007/http://h18002.www1.hp.com/alphaserver/firmware/readmes/updateviaunix-es40.html) (ES40 Firmware)
-   [vgabios-0.6a.bin](http://nongnu.org/vgabios/)  - VGA BIOS

### Building

Make sure libpcap, OpenSSL/LibreSSL and their respective development files are installed on your system.

First we need to install poco; if it is not available from your system package manager, compile from source: 

    [int16h@cgxsrv01 ~]$ mkdir ES40 && cd ES40
    [int16h@cgxsrv01 ES40]$ wget poco-1.3.3p1.tar.gz
    [int16h@cgxsrv01 ES40]$ tar zxvf poco-1.3.3p1.tar.gz
    [int16h@cgxsrv01 ES40]$ cd poco-1.3.3p1
    [int16h@cgxsrv01 ES40]$ ./configure --omit=Data/ODBC,Data/MySQL
    [int16h@cgxsrv01 ES40]$ make
    [int16h@cgxsrv01 ES40]$ sudo make install
 
Create a new directory within ES40 called "es40-source" (or whatever you like) and place es40\_018\_src.zip into this directory. Unzip the archive, then we will edit the Makefile to remove any debugging flags and GUI options (as we are going for a headless 'production' server).

    [int16h@cgxsrv01 ES40]$ mkdir es40-source
    [int16h@cgxsrv01 ES40]$ unzip es40_018_src.zip -d es40-source/ && cd es40-source
    [int16h@cgxsrv01 es40-source]$ vi Makefile
Navigate down to the **CTUNINGFLAGS** section and replace 'generic' with your target CPU (this is optional)

    # CTUNINGFLAGS - tuning options for the compiler
    #       
    # Samples for g++ on x86:
    #  -O3   -- optimize at level 3
    #  -mtune=   -- cpu is one of:  generic, core2, athlon64, pentium4, etc
    # 
    CTUNINGFLAGS = -O3 -mtune=generic
By default, ES40 will compile with "**-g -DHIDE\_COUNTER -DDEBUG\_BACKTRACE**" there are many other options which are listed below, but to help improve performance I will remove all debug flags. You may include any you like, but this is being set up as if it was a production-testing server.

    # CDEBUGFLAGS - turn on debugging in ES40
    #
    # Supported flags:
    #   -g                          Include information for gdb
    #   -DHIDE_COUNTER          Do not show the cycle counter
    #   -DDEBUG_VGA             Turn on VGA Debugging
    #   -DDEBUG_SERIAL          Turn on Serial Debugging
    #   -DDEBUG_IDE             Turn on all IDE Debugging.
    #   -DDEBUG_IDE_   Turn on specific IDE debugging.  Options are:
    #                               BUSMASTER, COMMAND, DMA, INTERRUPT, REG_COMMAND,
    #                               REG_CONTROL, PACKET
    #   -DDEBUG_UNKMEM          Turn on unknown memory access debugging
    #   -DDEBUG_PCI             Turn on PCI Debugging
    #   -DDEBUG_TB              Turn on Translation Buffer debugging
    #   -DDEBUG_PORTACCESS  Turn on i/o port access debugging
    #   -DDEBUG_SCSI            Turn on SCSI debugging
    #   -DDEBUG_KBD             Turn on keyboard debugging
    #   -DDEBUG_PIC             Turn on Programmable Interrupt Controller debugging
    #   -DDEBUG_LPT         Turn on debugging for LPT Port
    #   -DDEBUG_USB         Turn on debugging for USB controller
    #   -DDEBUG_SYM         Turn on debugging for Sym53C810 controller
    #   -DDEBUG_DMA         Turn on debugging for DMA controller
    #   -DDEBUG_BACKTRACE   Turn on backtrace dump on SIGSEGV
    #
    CDEBUGFLAGS = -g -DHIDE_COUNTER -DDEBUG_BACKTRACE

I will comment out the flags at the CDEBUGFLAGS line.

    CDEBUGFLAGS = # -g -DHIDE_COUNTER -DDEBUG_BACKTRACE
Next we will remove support for SDL and X11 as we will use a virtual serial console connection over telnet.

    # ES40 Options
    #
    # -DHAVE_SDL            Use the SDL Library for GUI
    # -DHAVE_X11            Use X11 for GUI
    # -DHAVE_PCAP           Use Networking via PCAP
    # -DHAVE_NEW_FP     Use the new floating-point code (with traps,
    #                   ut unfortunately, also with bugs)
    #
    OPTIONS = -DHAVE_SDL -DHAVE_X11 -DHAVE_PCAP
Make the "OPTIONS" section look like the following:

    OPTIONS = -DHAVE_PCAP
Finally save the file and exit. Type 'make' to begin compilation.

    [int16h@cgxsrv01 es40-source]$ make
ES40 will now compile, don't worry about the warnings. Once it's complete, we will move the binary and default configuration file to a new directory:

    [int16h@cgxsrv01 es40-source]$ mkdir ../es40
    [int16h@cgxsrv01 es40-source]$ cp es40{,.cfg} ../es40/
    [int16h@cgxsrv01 es40-source]$ cd ../es40
We need to create 2 directories within here, one will store any disk images and ISOs - the other will contain our ES40 firmware and VGA bios binaries. We will also rename es40.cfg and create a new one from scratch. The default configuration appears to have been written on a Windows system as defined paths use backslashes. It will save you some time to use my config here, but you should read over the original so you are aware of all of the available options.

    [int16h@cgxsrv01 es40]$ mkdir img rom
    [int16h@cgxsrv01 es40]$ cd rom
    [int16h@cgxsrv01 rom]$ wget http://mirror.publicns.net/pub/nongnu/vgabios/vgabios-0.6b.bin
    [int16h@cgxsrv01 rom]$ ### wget ftp://ftp.hp.com/pub/alphaserver/firmware/current_platforms/v7.3_release/ES40_series/ES40/es40.zip
    [int16h@cgxsrv01 rom]$ ### unzip es40.zip cl67srmrom.exe
    [int16h@cgxsrv01 rom]$ wget https://cryogenix.net/cl67srmrom.exe
We now have the firmware and BIOS images available to us. Although we don't need the VGA BIOS, it's nice to have it there incase you decide to use it in the future. Now would be a good time to prepare your media. I already had ISO images of OpenVMS and Tru64 ready - you may also create images of your installation media by using '**dd**'. Copy your ISO image(s) into the '**img**' directory, then we can get started.

    [int16h@cgxsrv01 rom]$ cd ..
    [int16h@cgxsrv01 img]$ mv /root/OpenVMS.Alpha.8.3.iso img/
    [int16h@cgxsrv01 img]$ mv es40.cfg es40.cfg.bak
Using your favourite line/text editor, re-create **es40.cfg** and we will configure the emulator.

    // We don't need this, included for reference.
    // gui = sdl/X11/win32
    //
    // gui = X11
    // {
    //   keyboard.use_mapping = false;
    //   keyboard.map = "keys.map";
    // }
    
    sys0 = tsunami
    {
    	rom.srm = "rom/cl67srmrom.exe";
    	rom.decompressed = "rom/decompressed.rom";
    	// rom.flash = "rom/flash.rom";
    	// rom.dpr = "rom/dpr.rom";
    	
    // Memory allocation:
    // 26 = 64 MB
    // 27 = 128MB
    // 28 = 256 MB
    // 29 = 512 MB
    // 30 = 1GB
    // 31 = 2GB
    		
    	memory.bits = 28;
    
     cpu0 = ev68cb
      	{
    		// onchip-cache
    		icache = false;
    	}
    	
    // System Internal PCI Devices: ali, ali_ide, ali_usb
    pci0.7 = ali{
    	// These aren't really required for our set-up.
      	mouse.enabled = true;
      	lpt.outfile = "lpt.out";
      	vga_console = true;
    }
    
    pci0.15 = ali_ide
    {
    	disk0.0 = file
    	{
      		file =          "img/disk0.img";
      		serial_number = "VMS";
      		rev_number    = "8.3";
      		model_number  = "OpenVMS8.3";
      		read_only     = false;
      		cdrom         = false;
      		autocreate_size = 1000M;
    	}
    
        disk1.0 = file
        {
          file          = "img/OpenVMS.Alpha.8.3.iso";
          read_only     = true;
          cdrom         = true;
        }
    	
    }
    
      pci0.19 = ali_usb {}
    
      pci0.4 = dec21143 {
        adapter = "eth0" // Change to your ethernet device
      }
    
      serial0 = serial {
        port = 21264;
      }
    }
This is a good, simple configuration for your first Emulated ES40 system. You may increase "**autocreate_size**" to your liking as well as add, remove or modify any other options (refer to the documentation and the original config file). We are now ready to launch the emulator.
### Starting the Emulator

    [int16h@cgxsrv01 es40]$ sudo ./es40 
    
    
       **======================================================================**
       ||                             ES40  emulator                           ||
       ||                              Version 0.18                            ||
       ||                                                                      ||
       ||  Copyright (C) 2007-2008 by the ES40 Emulator Project                ||
       ||  Website: http://sourceforge.net/projects/es40                       ||
       ||  E-mail : camiel@camicom.com                                         ||
       ||                                                                      ||
       ||  This program is free software; you can redistribute it and/or       ||
       ||  modify it under the terms of the GNU General Public License         ||
       ||  as published by the Free Software Foundation; either version 2      ||
       ||  of the License, or (at your option) any later version.              ||
       **======================================================================**
    
    sys0(tsunami): $Id: System.cpp,v 1.68 2008/03/04 19:05:21 iamcamiel Exp $
    sys0(tsunami): $Id: DPR.cpp,v 1.16 2008/02/29 10:23:09 iamcamiel Exp $
    sys0(tsunami): $Id: Flash.cpp,v 1.15 2007/12/30 15:10:22 iamcamiel Exp $
    cpu0(ev68cb): $Id: AlphaCPU.cpp,v 1.71 2008/03/04 19:05:21 iamcamiel Exp $
    pci0.7(ali): $Id: AliM1543C.cpp,v 1.60 2008/02/27 12:04:19 iamcamiel Exp $
    kbc: $Id: Keyboard.cpp,v 1.4 2008/02/29 10:23:09 iamcamiel Exp $
    dma: $Id: DMA.cpp,v 1.2 2008/02/26 15:43:47 iamcamiel Exp $
    %IDE-I-INIT: New IDE emulator initialized.
    pci0.15(ali_ide).disk0.0(file): Could not open file img/disk0.img!
    pci0.15(ali_ide).disk0.0(file): writing 2000 1kB blocks:  99%
    pci0.15(ali_ide).disk0.0(file): 2000 MB file img/disk0.img created.
    pci0.15(ali_ide).disk0.0(file): Mounted file img/disk0.img, 4096000 512-byte blocks, 5120/16/50.
    pci0.15(ali_ide).disk1.0(file): Mounted file img/OpenVMS.Alpha.8.3.iso, 270233 2048-byte blocks, 270233/1/1.
    pci0.19(ali_usb): $Id: AliM1543C_usb.cpp,v 1.5 2008/02/27 12:04:20 iamcamiel Exp $
    
    %NIC-Q-CHNIC: Choose a network adapter to connect to:
    1. eth0
         (No description available)
    2. lo
         (No description available)
    %NIC-Q-NICNO: Enter the interface number (1-2): 1
    pci0.4(dec21143): $Id: DEC21143.cpp,v 1.30 2008/03/02 09:42:52 iamcamiel Exp $
    serial0(serial): Waiting for connection on port 21264.
At this point you will telnet to the IP bound to the interface you chose for the serial console to proceed.

    cgxlap:~ int16h$ telnet 10.0.0.11
    Escape character is '^]'.
    This is serial port #-1489766912 on AlphaSim
Quickly look at the other terminal where you started ES40 and you will notice that the emulator has now resumed.

    serial0(serial): $Id: Serial.cpp,v 1.39 2008/03/02 09:42:52 iamcamiel Exp $
    %SYS-I-READROM: Reading original ROM image from rom/cl67srmrom.exe.
    %SYS-I-DECOMP: Decompressing ROM image.
    0%....10%....20%....30%....40%....50%....60%....70%....80%....90%......100%
    %SYS-I-ROMWRT: Writing decompressed rom to rom/decompressed.rom.
    %SYM-I-PATCHROM: Patching ROM for speed.
    %SYS-I-ROMLOADED: ROM Image loaded successfully!
    flash: 2097156 bytes restored.
    %FLS-I-RESTST: Flash state restored from flash.rom
    dpr: 16384 bytes restored.
    %DPR-I-RESTST: DPR state restored from dpr.rom
    6232 | 000000000008bb9c
Our ROM image has been decompressed and patched, and the emulator has started properly. Now go back to your telnet serial console and wait for the system to initialise. Depending on your system, this may take a couple of minutes. It should be noted that this emulator is emulating an 847Mhz 64-Bit Alpha CPU as well as all the associated hardware... as you can imagine, accomplishing this on a 32-bit Intel system will put a lot of strain on the system and the emulated system itself will run slowly unless you have a high-spec machine. I'm running this on an old AMD Sempron 2800+ system with less than 1GB of RAM, I recommend  **at least**  an Intel Core2 Duo system.

After your (hopefully short) wait, you will see the following initialisation messages:

    starting console on CPU 0
    initialized idle PCB
    initializing semaphores
    initializing heap
    initial heap 240c0
    memory low limit = 1b0000 heap = 240c0, 17fc0
    initializing driver structures
    initializing idle process PID
    initializing file system
    initializing hardware
    initializing timer data structures
    lowering IPL
    CPU 0 speed is 847 MHz
    create dead_eater
    create poll
    create timer
    create powerup
    access NVRAM
    Memory size 256 MB
    testing memory
    ..
    probe I/O subsystem
    probing hose 1, PCI
    probing hose 0, PCI
    probing PCI-to-ISA bridge, bus 1
    bus 0, slot 4 -- ewa -- DE500-BA Network Controller
    bus 0, slot 15 -- dqa -- Acer Labs M1543C IDE
    bus 0, slot 15 -- dqb -- Acer Labs M1543C IDE
    starting drivers
    entering idle loop
    *** system serial number not set. use set sys_serial_num command.
    Partition 0, Memory base: 000000000, size: 010000000
    initializing GCT/FRU at 1c8000
    Initializing ewa dqa dqb 
    Memory Testing and Configuration Status
      Array       Size       Base Address    Intlv Mode
    ---------  ----------  ----------------  ----------
        0        256Mb     0000000000000000    4-Way
    
         256 MB of System Memory
    Testing the System
    Testing the Network
    AlphaServer ES40 Console V7.3-1, built on Feb 27 2007 at 12:57:47
    P00>>>
Huzzah! The virtual AlphaServer is now online and ready for you to boot your installation media. Let's have a look at available devices and boot from the ISO.

    P00>>>sh dev
    dqa0.0.0.15.0              DQA0                    OpenVMS8 .3
    dqb0.0.1.15.0              DQB0         OpenVMS. Alpha.8.3.iso
    dva0.0.0.1000.0            DVA0                               
    ewa0.0.0.4.0               EWA0              08-00-2B-E5-40-00
    
    P00>>>boot DQB0
    (boot dqb0.0.1.15.0 -flags 0)
    block 0 of dqb0.0.1.15.0 is a valid boot block
    reading 1226 blocks from dqb0.0.1.15.0
    bootstrap code read in
    base = 200000, image_start = 0, image_bytes = 99400(627712)
    initializing HWRPB at 2000
    initializing page table at ff56000
    initializing machine state
    setting affinity to the primary CPU
    jumping to bootstrap code
    
    
    	OpenVMS (TM) Alpha Operating System, Version V8.3    
    	? Copyright 1976-2006 Hewlett-Packard Development Company, L.P.
    
    	    Installing required known files...
    
        Configuring devices...
    %EWA0, Auto-negotiation mode set by console
    %EWA0, Link state: UP
    %EWA0, Auto-negotiation (internal) starting
    %EWA0, Full Duplex 100baseTX connection selected
    
        ****************************************************************
    
        You can install or upgrade the OpenVMS ALPHA operating system
        or you can install or upgrade layered products that are included
        on the OpenVMS ALPHA distribution media (CD/DVD).
    
        You can also execute DCL commands and procedures to perform
        "standalone" tasks, such as backing up the system disk.
    
        Please choose one of the following:
    
            1)  Upgrade, install or reconfigure OpenVMS ALPHA Version V8.3
            2)  Display layered products that this procedure can install
            3)  Install or upgrade layered products
            4)  Show installed products
            5)  Reconfigure installed products
            6)  Remove installed products
            7)  Find, Install or Undo patches; Show or Delete Recovery Data
            8)  Execute DCL commands and procedures
            9)  Shut down this system
    
    Enter CHOICE or ? for help: (1/2/3/4/5/6/7/8/9/?)
From here you can continue to install OpenVMS as normal. So far I have been able to install and run OpenVMS 8.3 Alpha and Tru64 UNIX. This is an excellent emulator, and although it isn't "finished" - I think it runs pretty well. It should be noted however that the network interface is a little buggy - In Tru64 I can configure it and ping the local IP, but I'm unable to send or receive traffic outside of there currently.



