; server_fixed.asm - simple TCP echo server (ELF32 NASM)
bits 32
global _start

section .data
    AF_INET     equ 2
    SOCK_STREAM equ 1

    SC_SOCKET   equ 1
    SC_BIND     equ 2
    SC_LISTEN   equ 4
    SC_ACCEPT   equ 5
    SC_CLOSE    equ 6
    SC_SEND     equ 9
    SC_RECV     equ 10

    ; sockaddr_in: sin_family(2), sin_port(2 big-endian), sin_addr(4), sin_zero(4)
sockaddr:
    dw AF_INET
    dw 0x901F            ; bytes in memory will be 0x1F 0x90 -> htons(8080)
    dd 0                 ; INADDR_ANY (4 bytes)
    dd 0                 ; padding (sin_zero)

msg_listen db "listening on port 8080",10
len_listen equ $-msg_listen
msg_fail   db "syscall failed",10
len_fail   equ $-msg_fail

section .bss
    buffer resb 2048

section .data
    args_socket    dd AF_INET, SOCK_STREAM, 0
    args_bind      dd 0, sockaddr, 16
    args_listen    dd 0, 5
    args_accept    dd 0, 0, 0
    args_recv      dd 0, buffer, 2048, 0
    args_send      dd 0, buffer, 0, 0
    sockfd         dd 0

section .text

; write(fd, buf, len)
_write:
    mov eax, 4
    int 0x80
    ret

_exit:
    mov eax, 1
    int 0x80

_start:
    ; socket()
    mov eax, 102
    mov ebx, SC_SOCKET
    mov ecx, args_socket
    int 0x80
    jl .fail
    mov [sockfd], eax
    mov ebx, eax

    ; populate args first element (fd) for others
    mov dword [args_bind], eax
    mov dword [args_listen], eax
    mov dword [args_accept], eax
    mov dword [args_recv], eax
    mov dword [args_send], eax

    ; bind()
    mov eax, 102
    mov ebx, SC_BIND
    mov ecx, args_bind
    int 0x80
    jl .fail

    ; listen()
    mov eax, 102
    mov ebx, SC_LISTEN
    mov ecx, args_listen
    int 0x80
    jl .fail

    ; print listening message
    mov ebx, 1
    mov ecx, msg_listen
    mov edx, len_listen
    call _write

.accept_loop:
    ; accept()
    mov eax, 102
    mov ebx, SC_ACCEPT
    mov ecx, args_accept
    int 0x80
    jl .fail
    mov esi, eax    ; client fd

.conn_loop:
    ; prepare recv args (sockfd already set in args_recv)
    mov dword [args_recv], esi        ; use client fd for recv
    mov dword [args_recv+4], buffer
    mov dword [args_recv+8], 2048
    mov dword [args_recv+12], 0

    mov eax, 102
    mov ebx, SC_RECV
    mov ecx, args_recv
    int 0x80
    cmp eax, 0
    je .client_closed
    jl .conn_err

    ; eax = bytes received
    mov ecx, buffer
    mov edx, eax
    mov ebx, 1
    call _write          ; print to stdout

    ; echo back using send
    mov dword [args_send], esi
    mov dword [args_send+4], buffer
    mov dword [args_send+8], eax
    mov dword [args_send+12], 0

    mov eax, 102
    mov ebx, SC_SEND
    mov ecx, args_send
    int 0x80
    ; ignore send errors here (could check eax)

    jmp .conn_loop

.client_closed:
    ; close client fd
    push esi
    mov eax, 102
    mov ebx, SC_CLOSE
    mov ecx, esp
    int 0x80
    add esp, 4
    jmp .accept_loop

.conn_err:
    ; close client fd and continue
    push esi
    mov eax, 102
    mov ebx, SC_CLOSE
    mov ecx, esp
    int 0x80
    add esp, 4
    jmp .accept_loop

.fail:
    mov ebx, 2
    mov ecx, msg_fail
    mov edx, len_fail
    call _write
    mov ebx, 1
    call _exit
