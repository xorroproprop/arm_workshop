// Aarch64 ASM HTTP Server
// This is going to download our rootkit deployment and staged payload.

.data 

server_fd: .quad 0
client_fd: .quad 0

reuse_opt .int 1 // enable reuse

.equ buffer, 1024

sockaddr:
    .short 2
    .short 0x1f90
    .int 0x0100007f
    .space 8

.text
.global _start
// exit program
exit:
    mov x0, #0
    mov x8, #93
    svc #0
// Quick and dirty
exit_error:
    mov x8, #57
    svc #0
    b exit 

_start:
    // Inititalize Socket
    mov x0, #2 
    mov x1, #1
    mov x2, #0
    mov x8, #198
    svc #0
    cmp x0, #0
    ble exit_error

    // Save server_fd to x3
    adrp x9, server_fd
    str x0, [x9, :lo12:server_fd]
    mov x3, x0

    // Allow Socket Reuse
    //  mains.s Error: unknown mnemonic 'ruse_opt' -- 'reuse_opt . int 1' 
    // This doesn't seem to be valid so I need to investigate and figure out
    // proper implementation
    mov x0, x3
    mov x1, #1
    mov x2, #2
    adrp x3, reuse_opt
    add x3, x3, :lo12:reuse_opt
    mov x4, #4
    mov x8, #208
    svc #0

    cmp x0, #0
    bne exit_error

    adrp x9, server_fd
    ldr x3, [x9, :lo12:server_fd]
