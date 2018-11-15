#### Assembly language on OpenBSD amd64+arm64

This is a short introduction to assembly language programming on OpenBSD/amd64+arm64.  Because of security features in the kernel, I have had to rethink a series of tutorials covering Aarch64 assembly language on OpenBSD, and therefore this will serve as a placeholder-cum-reminder.

OpenBSD, like many UNIX and unix-like operating systems, uses the Executable and Linkable Format (ELF) for its binary libraries and executables.  Although the structure of this format is beyond the scope of this short introduction, it is necessary for me to explain part of one of the headers.

Within the program header there are sections known as PT_NOTE that OpenBSD and other systems use to distinguish their ELF executables - OpenBSD looks for this section to check if it should attempt to execute the program or not.

The section uses a structure similar to the following:

    PT_NOTE {
    	long	namesz;   /* size of name */
    	long	descsz;   /* size of desc */
    	long	type;     /* ABI type? */
    	char	name;	  /* ABI name */
    	long	desc;	  /* description */
    }

For our assembled programs to link correctly with GNU/LLVM as+ld, we must create this section; there's probably a cute way of doing this with ld and crt0 but I haven't looked into it.

##### Our first program: in C!

It's often a good idea to prototype your assembly programs in a high level language such as C - it can then double up as both a set of notes and a working program that you can debug and compile into assembly language to compare with your own asm code. Create sysexit.c:

    #include <unistd.h>
    #include <sys/syscall.h>

    int
    main(void)
    {
    	syscall(SYS_exit, 123);
	return 0;
    }

OK, return 0 here is a little redundant as we have already called SYS\_exit() to exit our program.

Compile with clang:

    clang -o sysexit sysexit.c

Or with GNU:

    gcc -o sysexit sysexit.c

If you run the program, it should do nothing - just silently exit and return you to the shell prompt.  Exciting! Next we will rewrite this program in assembly language.
 
##### Our first program: in x86-64 Asm!

x86-64 General Purpose Registers:

    RAX    Accumulator
    RBX    Base
    RCX    Counter
    RDX    Data (can extent Accumulator)
    RSI    Source Index for string ops
    RDI    Destination Index for string ops
    RSP    Stack Pointer
    RBP    Base Pointer
    R8-15  General purpose 

System calls such as exit/SYS\_exit are defined in <sys/syscall.h> - assemblers, unlike C compilers, don't know about these C/C++ include files so we need to extract defines and macros from them to implement in assembly.

If you look at /usr/include/sys/syscall.h you will see SYS_exit is defined near the top of the file:

    /* syscall: "exit" ret: "void" args: "int" */
    #define SYS_exit	1

Our exit syscall returns void and takes one int as an argument. SYS\_exit itself is is defined as '1'.  So when we make a syscall and pass SYS\_exit, we are actually passing an integer that represents the function.

Syscall numbers are loaded into the rax register, and any parameters are put int rdi, rsi, rdx, etc. Any return value is left in rax.

Equipped with this knowledge and the previous notes about the ELF program header, we can write our first assembly program, sysexit.s:

    .section ".note.openbsd.ident", "a"
    	.p2align 2		/* padding */
    	.long 0x8		/* namesz */
        .long 0x4		/* descsz */
        .long 0x1		/* type */ 
        .ascii "OpenBSD\0"	/* name */
        .long 0x0		/* desc */
        .p2align 2		
    
    .section .text	/* .text section begins */
    .globl _start	/* make _start symbol global/known to ld */
    _start:
   	movq $1,%rax	/* copy 1 (SYS_exit) into rax register */
	movq $123,$rdi	/* 1st parameter: 123
	syscall 	/* call syscall (int 0x80 on 32-bit) */

Assemble and link with GNU tools:

    $ as sysexit.s -o sysexit.o
    $ ld -e _start -static sysexit.o -o sysexit

- -e _start instructs the linker to use _start as an entry symbol/point
- -static is required for compatibility with OpenBSD - I'm not sure why, but without it the program will abort.  Some kernel security feature?



##### Our first program: in ARMv8 AArch64 assembly

AArch64 is the 64-bit state of ARMv8 processors; these processors can run a 32-bit kernel with 32-bit userland, or a 64-bit kernel with both 32 and 64-bit userland.  The architecture changes a little when in the 64-bit state.

Registers:

    X0 - X7	= Argument / results registers
    X8		= indirect result location
    X9 - X15	= temporary registers
    X16 - X17	= temporary intra-proc call
    X18		= platform register
    X19 - X29	= Callee-saved register (must preserve)
    X30		= link register

sysexit-arm.s:

    .section ".note.openbsd.ident", "a"
    .p2align 2
    .long    0x8
    .long    0x4
    .long    0x1
    .ascii    "OpenBSD\0"
    .long    0x0
    .p2align 2
    
    .text
    .globl main
    main:
        mov x0, #123	/* copy 123 to x0 - reverse of AT&T syntax */
        mov x8, #1	/* copy 1 into x8
        svc #0 		/* supervisor instruction - formerly swi */

Assemble and link:

    gas sysexit-arm.s -o sysexit-arm.o
    ld -s sysexit-arm.o -o sysexit-arm // -z notext -static

Or with clang:

    clang sysexit-arm.s -o sysexit-arm

