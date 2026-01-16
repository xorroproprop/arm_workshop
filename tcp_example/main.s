//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// aarch64 assembly TCP networking stack
// The objective is to create a TCP Ping Server that reponds back to anyone trying to connect.
// I don't really know what I'm doing, using arm assembler manual to piece this together and many trial and error runs.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Network Configuration
// Port: 9000
// IP: localhost
// Build: as main.s -o main.o
//        ld -w main.o -o tcpserver
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

.data

server_fd: .quad 0
client_fd: .quad 0

string: .asciz "Server Active\n"
port: .short 0x2870  // 10352 in network byte order
response: .ascii "PONG" // 4 bytes long
response_len = . - response // Response length
buffer: .space 1024 // Buffer size (1024)

/*
Socket Creation
socket(AF_INET, SOCK_STREAM, 0) 
-----------------------------------
x0 - AF_INET (2)
x1 - SOCK_STREAM (1)
x2 - IPPROTO_TCP (0)
 */

sockaddr:
    .short 2            // AF_INET
    .short 0x2870       // Port 10352
    .int 0x0100007f     // 127.0.0.1 in network byte order
    .space 8

.text
.global _start

exit:
    mov x0, #0 // exit code 
    mov x8, #93 // sys_exit
    svc #0 // execute syscall

exit_error:
    adrp x9, server_fd              // x9 = page base of server_fd variable
    ldr x0, [x9, :lo12:server_fd]   // x0 = load server socket fd from memory
    cmp x0, #0                      // check if server_fd is zero (socket never created)
    beq exit                        // if zero, skip close and just exit normally
    mov x8, #57                     // x8 = 57 (SYS_CLOSE syscall number)
    svc #0                          // invoke close syscall to clean up socket
    b exit                          // jump to exit routine

close_client:
    mov x0, x4 // client_fd that was stored
    mov x8, #57 // sys_close syscall
    svc #0 // run syscall
    b .accept_loop // loopback to accept more connections

_start:
    // Create socket
    mov x0, #2 // AF_INET
    mov x1, #1 // SOCK_STREAM 
    mov x2, #0 // IPPROTO_TCP
    mov x8, #198 // sys_socket
    svc #0 // make syscalls 
    cmp x0, #0 // check for errors
    ble exit_error // branch on less or equal to exit_error routine
    
    // Save server_fd
    //Full Address = [Upper Bits (page-aligned)] + [Lower 12 Bits (offset within page)]
    adrp x9, server_fd // retrieve page aligned address from server_fd
    str x0, [x9, :lo12:server_fd] // 12 bit offset 
    mov x3, x0 // keep fd in x3 for later usage
    
    // Print "Server Active"
    mov x0, #1              // x0 = 1 (stdout file descriptor)
    ldr x1, =string         // x1 = address of "Server Active\n" string
    mov x2, #15             // x2 = 15 (length of string to write)
    mov x8, #64             // x8 = 64 (SYS_WRITE syscall number)
    svc #0                  // invoke write syscall
    
    // Bind socket
    mov x0, x3              // x0 = server socket fd (saved in x3 earlier)
    adrp x1, sockaddr       // x1 = page base address of sockaddr struct
    add x1, x1, :lo12:sockaddr  // x1 = exact address of sockaddr
    mov x2, #16             // x2 = 16 (size of sockaddr_in structure)
    mov x8, #200            // x8 = 200 (SYS_BIND syscall number)
    svc #0                  // invoke bind syscall
    cmp x0, #0              // check if bind succeeded (returns 0 on success)
    blt exit_error          // if negative, jump to error handler
    
    // Listen on socket
    mov x0, x3              // x0 = server socket fd
    mov x1, #5              // x1 = 5 (backlog: max pending connections)
    mov x8, #201            // x8 = 201 (SYS_LISTEN syscall number)
    svc #0                  // invoke listen syscall
    cmp x0, #0              // check if listen succeeded
    blt exit_error          // if negative, jump to error handler

.accept_loop:
    // Wait for incoming connection
    adrp x9, server_fd      // x9 = page base of server_fd variable
    ldr x0, [x9, :lo12:server_fd]  // x0 = load server socket fd from memory
    mov x1, #0              // x1 = 0 (NULL: don't fill client address)
    mov x2, #0              // x2 = 0 (NULL: don't need address length)
    mov x8, #202            // x8 = 202 (SYS_ACCEPT syscall number)
    svc #0                  // invoke accept syscall - blocks until connection arrives
    cmp x0, #0              // check if accept succeeded
    ble exit_error          // if zero or negative, jump to error handler
    
    // Save client file descriptor
    adrp x9, client_fd      // x9 = page base of client_fd variable
    str x0, [x9, :lo12:client_fd]  // store accepted client fd to memory
    mov x4, x0              // x4 = client fd (keep it safe for later use)
    
    // Read from client
    adrp x1, buffer         // x1 = page base of buffer array
    add x1, x1, :lo12:buffer  // x1 = exact address of buffer
    mov x0, x4              // x0 = client fd (setup for read syscall)
    mov x2, #1024           // x2 = 1024 (max bytes to read)
    mov x8, #63             // x8 = 63 (SYS_READ syscall number)
    svc #0                  // invoke read syscall
    cmp x0, #0              // check if read returned data (> 0 bytes)
    ble close_client        // if zero/negative, close connection and loop
    
    // Send response
    mov x0, x4              // x0 = client fd (setup for write syscall)
    adrp x1, response       // x1 = page base of "PONG" response string
    add x1, x1, :lo12:response  // x1 = exact address of response
    mov x2, #4              // x2 = 4 (length of "PONG")
    mov x8, #64             // x8 = 64 (SYS_WRITE syscall number)
    svc #0                  // invoke write syscall to send "PONG"
    
    // Close connection and loop
    b close_client          // jump to close_client (closes fd and loops back)