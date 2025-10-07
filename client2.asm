; client_fixed2.asm - connect to 127.0.0.1:8080, send message, recv echo, print
bits 32
global _start

section .data
    AF_INET     equ 2
    SOCK_STREAM equ 1

    SC_SOCKET   equ 1
    SC_CONNECT  equ 3
    SC_SEND     equ 9
    SC_RECV     equ 10
    SC_CLOSE    equ 6

; sockaddr_in for 127.0.0.1:8080
c_sockaddr:
    dw AF_INET
    dw 0x901F            ; port 8080 -> bytes 0x1F 0x90 in memory (network order)
    dd 0x0100007F        ; assembler stores little-endian -> in-memory bytes 7F 00 00 01 (127.0.0.1)
    dd 0

msg db "Hello from ASM client!",10
len_msg equ $-msg

err_bind db "connect failed",10
len_err equ $-err_bind

args_socket dd AF_INET, SOCK_STREAM, 0
args_connect dd 0, c_sockaddr, 16
args_send dd 0, msg, len_msg, 0
args_recv dd 0, 0, 2048, 0    ; will fill buf ptr later

section .bss
    buffer resb 2048

section .data
    sockfd dd 0

section .text

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

    ; set sockfd into args that need it
    mov dword [args_connect], eax
    mov dword [args_send], eax
    mov dword [args_recv], eax
    mov dword [args_recv+4], buffer

    ; connect()
    mov eax, 102
    mov ebx, SC_CONNECT
    mov ecx, args_connect
    int 0x80
    jl .fail

    ; send()
    mov eax, 102
    mov ebx, SC_SEND
    mov ecx, args_send
    int 0x80
    jl .close_conn

    ; recv()
    mov eax, 102
    mov ebx, SC_RECV
    mov ecx, args_recv
    int 0x80
    cmp eax, 0
    jle .close_conn

    ; write received to stdout
    mov ebx, 1
    mov ecx, buffer
    mov edx, eax
    call _write

.close_conn:
    ; close socket
    push dword [sockfd]
    mov eax, 102
    mov ebx, SC_CLOSE
    mov ecx, esp
    int 0x80
    add esp, 4
    call _exit

.fail:
    mov ebx, 1
    mov ecx, err_bind
    mov edx, len_err
    call _write
    mov ebx, 1
    call _exit
