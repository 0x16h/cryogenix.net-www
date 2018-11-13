#### Reverse Engineering Tutorial: level1 - What's the password?

Welcome to level1 of the Reverse Engineering Tutorial.  I will be using OpenBSD 6.4/amd64 to demonstrate one way to solve level1 of the 
Cryogenix wargame (yet TBA).

You may download the binary, or if you're a bit tinfoilhat-inclined the source is also available.  You'll also need gdb (lldb will be added at 
a later date), binutils, and optionally Vim.

##### Get level1

Binary (OpenBSD/amd64):

    ftp https://cryogenix.net/RET/level1/level1

Source:

    ftp https://cryogenix.net/RET/level1/level1.c
    gcc -fno-stack-protector -o level1 level1.c

##### Let's begin...

    ./level1
    
    Welcome to Cryogenix
    Password: 12345
    
    12345 is incorrect!
    $

Our goal is, if it wasn't immediately obvious, to find the correct password - or otherwise access what requires the correct password to 
level1.  This could be accomplished through static (disassembly) techniques, but that would be boring!  Let's load our binary into gdb:

    $ gdb level1

Set a breakpoint on main() and run the program to see what we're dealing with

    (gdb) b main
    Breakpoint 1 at 0x772
    (gdb) r
    Breakpoint 1 at 0x54486b00772
    Breakpoint 1, 0x0000054486b00772 in main ()
    	from /home/level1/level1

Next we instruct gdb to disassemble the current function:

    (gdb) disas
    
    Dump of assembler code for function main:
    0x0000054486b0076e <main+0>:    push   %rbp
    76f <main+1>:    mov    %rsp,%rbp
    772 <main+4>:    lea    1050137(%rip),%rdi	 # 0x54486c
    779 <main+11>:   callq  0x54486b003a0 <__init+80>
    77e <main+16>:   lea    1050147(%rip),%rdi	 # 0x54486c00da8
    785 <main+23>:   mov    $0x0,%eax
    78a <main+28>:   callq  0x54486b00370 <__init+32>
    78f <main+33>:   mov    $0x0,%eax
    794 <main+38>:   callq  0x54486b00700 <checkpass>
    799 <main+43>:   leaveq
    79a <main+44>:   retq
    79b <main+45>:   int3
    End of assembler dump.

We're fortunate here that gdb is aware of a function named 'checkpass' - so there's no point teasing you with the other calls that could be 
interesting but probably are not; it's safe to assume they are printing text to stdout ;).  Let's create a breakpoint on checkpass():

    (gdb) b checkpass
    Breakpoint 2 at 0xe4f6ee00704
    (gdb) c
    Continuing.
    
    Welcome to Cryogenix
    
    Breakpoint 2, 0x00000e4f6ee00704 in checkpass ()
    	from /home/level1/level1
    (gdb) disas
    
    Dump of assembler code for function checkpass:
    0x00000e4f6ee00700 <checkpass+0>:       push   %rbp
    0x00000e4f6ee00701 <checkpass+1>:       mov    %rsp,%rbp
    0x00000e4f6ee00704 <checkpass+4>:       sub    $0x10,%rsp
    0x00000e4f6ee00708 <checkpass+8>:       lea    0xfffffffffffffff3(%rbp),%rdi
    0x00000e4f6ee0070c <checkpass+12>:      callq  0xe4f6ee005e4 <gets>
    0x00000e4f6ee00711 <checkpass+17>:      lea    0xfffffffffffffff3(%rbp),%rsi
    0x00000e4f6ee00715 <checkpass+21>:      lea    2103524(%rip),%rdi        # 0xe4f6f002000 <password>
    0x00000e4f6ee0071c <checkpass+28>:      callq  0xe4f6ee003c0 <__init+112>
    0x00000e4f6ee00721 <checkpass+33>:      mov    %eax,0xfffffffffffffffc(%rbp)
    0x00000e4f6ee00724 <checkpass+36>:      cmpl   $0x0,0xfffffffffffffffc(%rbp)
    0x00000e4f6ee00728 <checkpass+40>:      jne    0xe4f6ee0074d <checkpass+77>
    0x00000e4f6ee0072a <checkpass+42>:      lea    0xfffffffffffffff3(%rbp),%rsi
    0x00000e4f6ee0072e <checkpass+46>:      lea    1050155(%rip),%rdi        # 0xe4f6ef00d60 <__fini+1050048>
    0x00000e4f6ee00735 <checkpass+53>:      mov    $0x0,%eax
    0x00000e4f6ee0073a <checkpass+58>:      callq  0xe4f6ee00370 <__init+32>
    0x00000e4f6ee0073f <checkpass+63>:      lea    1050155(%rip),%rdi        # 0xe4f6ef00d71 <__fini+1050065>
    0x00000e4f6ee00746 <checkpass+70>:      callq  0xe4f6ee003a0 <__init+80>
    0x00000e4f6ee0074b <checkpass+75>:      jmp    0xe4f6ee0076c <checkpass+108>
    0x00000e4f6ee0074d <checkpass+77>:      lea    0xfffffffffffffff3(%rbp),%rsi
    0x00000e4f6ee00751 <checkpass+81>:      lea    1050151(%rip),%rdi        # 0xe4f6ef00d7f <__fini+1050079>
    0x00000e4f6ee00758 <checkpass+88>:      mov    $0x0,%eax
    0x00000e4f6ee0075d <checkpass+93>:      callq  0xe4f6ee00370 <__init+32>
    0x00000e4f6ee00762 <checkpass+98>:      mov    $0x1,%edi
    0x00000e4f6ee00767 <checkpass+103>:     callq  0xe4f6ee003f0 <__init+160>
    0x00000e4f6ee0076c <checkpass+108>:     leaveq
    0x00000e4f6ee0076d <checkpass+109>:     retq
    End of assembler dump.

If you aren't familiar with x86_64 assembly, here's a commentary of what's happening in the checkpass() function:

    700: push	%rbp

700: push/save (to the stack) the old stack pointer stored in %rbp 
(base pointer register) onto the stack

    701: mov	%rsp,%rbp

701: copy the contents of the stack pointer register 
(%rsp) into the base pointer register (%rbp)

    704: sub	$0x10,%rsp

704: subtract 0x10 (16 decimal) from the stack pointer

    708: lea	0xfffffffffffffff3(%rbp),%rdi	

708: calculate and move whatever is at %rbp-13 into %rdi (register dest index)

    70c: callq	0xe4f6ee005e4 <gets>

70c: call gets() (which begins at address 0xe4f6ee005e4 - a function inside our program!)

    711: lea        0xfffffffffffffff3(%rbp),%rsi

711: copy %rbp-13 to %rsi (register source index)

By this point, input has been read from stdin and copied to $rax. This can be confirmed if you type (gdb) ni (next instruction) until after 
you are asked for the password, then: (gdb) x/s $rax - examine string in the rax register.  We can also see what the lea instruction is 
actually copying by doing (gdb) x/s $rbp-13 and (gdb) x/s $rsi - it's our entered password!

    715: lea	2103524(%rip),%rdi		

715: load whatever is at %rip+2103524 into %rdi. %rip (instruction pointer register)
addresses are relative to the instruction pointer register - i.e. the next instruction,
so are used for global variables. Whatever is at %rip+2103524 is a global var.
0xe4f6ee0071c+0x2018E4 (2103524 in hex) = 0xe4f6f002000 (gdb helpfully tells us the var
name at this address. SPOILER: (gdb) x/s 0xe4f6f002000 or (gdb) x/s $rip+2103524.

*BIG SPOILER* for the impatient:
    (gdb) x/s $rip+2103524
    0xe4f6f002000 *REDACTED*
    (gdb) set {char[6]}0xe4f6f002000 = "12345"
    (gdb) x/s $rip+2103524
    (gdb) c

    71c: callq	0xe4f6ee003c0 <__init+112>	

71c: - this is somewhat specific to the platform compiled on (OpenBSD); in gdb, type:
(gdb) x/i 0xe4f6ee003c0 - x/i is shorthand for 'examine instruction'. The instruction
called at that address is a jmp to __retguard - the OpenBSD stack protector.

    721: mov	%eax,0xfffffffffffffffc(%rbp)   # copy eax into %rbp-4
    724: cmpl	$0x0,0xfffffffffffffffc(%rbp)	# if $0x0 = %rbp-4 [set zero flag]:
    728: jne	0xe4f6ee0074d			# If not equal, jump to 74d (incorrect password)

If you didn't opt for the *SPOILER* or *BIG SPOILER*, we have another opportunity to win this level,
though it is a little sloppy - and is a bit of a 'cheat'.

We now Know that there is a jne instruction at 0xe4f6ee00728 that decides whether the password we entered is correct or not;
assembly language is assembled into machine language - which, among other things, contains our assembly instructions
as opcodes. Opcodes are specific to each CPU architecture.

If you study Intel architecture manuals, you will find that jne (jnz in intel syntax) is a one-byte op-code. If you don't have
a reference handy, use gdb to examine the first byte at address 0xe4f6ee00728:

    (gdb) x/1bx 0x00000678b7200728
    0x678b7200728 <checkpass+40>:   0x75

So our opcode for jne/jnz is 0x75.  To save you looking it up, I can tell you that the opcode for the opposing instruction - je/jz - is 0x74.
We are going to change the instruction, not in memory this time, but in the actual executable file (I told you it was sloppy). 

To find the physical offset of our instruction, it is necessary to view the Elf headers (assuming you are using an OS which uses the Elf format for executables); for this we can use readelf (part of binutils):

    $ readelf -l level1

We are looking for a LOAD header with the executable (E) flag:

    Type  Offset             VirtAddr           PhysAddr           FileSiz            MemSiz              Flags  Align
    LOAD  0x0000000000000000 0x0000000000000000 0x0000000000000000 0x00000000000007ae 0x00000000000007ae  R E    100000

Our offset, virtual address and physical address are all 0x0 - so 0x00000678b7200728 (virtual/memory address) is equal to 0x00000728 (physical address). If the Offset was a different value, or if VirtAddr and PhysAddr differed - you would need to do some hexadecimal arithmetic. 

Using xxd, we can view 16 bytes starting at 0x00000678b7200720 which will include our instruction at *728:

    $ xxd -s 0x720 -l 16 level1
    00000720: ff89 45fc 837d fc00 7523 488d 75f3 488d  ..E..}..u#H.u.H.

Or, if you prefer hexdump(1):

    $ hexdump -C -s 0x720 -n 16 level1
    00000720  ff 89 45 fc 83 7d fc 00  75 23 48 8d 75 f3 48 8d  |..E..}..u#H.u.H.|

There are two 0x75 bytes listed, so count along from 0x720 to 0x728 to confirm which is the opcode we are looking for.

We could do something fancy in a ksh script and xxd, but I think you've been through enough for level1 - so we will edit the file using Vim:

    $ vim -b level1
    :set syntax=xxd
    :%!xxd

Move down to 00000720, find our lucky number 75 and change it to 74.  Next use xxd's reverse (-r) option and save the file:

    :%!xxd -r
    :wq

Confirm that the changes were made:

    $ xxd -s 0x720 -l 16 level1
    00000720: ff89 45fc 837d fc00 7423 488d 75f3 488d  ..E..}..u#H.t.H.

Brilliant! Now to test:

    $ ./level1

    Welcome to Cryogenix
    Password: yourmum

    yourmum is correct!

    Secret stuff

We're covered quite a lot in this short tutorial, particularly if you weren't familiar with the tools we used.  I suggest you read the man pages for them all so you can familiarise yourself fully with them before trying the yet-to-be-released level2!

level1 was written in a way that it could be solved through a number of methods - this tutorial covered a couple of them.  There are intentional vulnerabilities in the code which could be exploited and will be covered in a separate line of tutorials, but the *biggest spoiler* of them all is that you could have solved this level simply by viewing the strings in our executable file:

    $ strings level1 | tail -n 5

Oops!

I hope you enjoyed this lesson, and appreciate any feedback or ideas for subsequent levels and tutorials. Apologies for any technical errors, AT&T syntax is not my native language.
