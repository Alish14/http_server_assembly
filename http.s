section .data
    response_header db "HTTP/1.0 200 OK", 0x0D, 0x0A, 0x0D, 0x0A
    len_response_header equ $ - response_header  ; Calculate the length of the message
    target db 0x0D, 0x0A, 0x0D, 0x0A

section .bss
    buffer resb 1024
    file_name resb 1024
    file_content resb 1024
    found resb 512
    length resb 120
    request_content resb 1024
    position resb 128

section .text
    global _start

_start:
    ; Create socket
    xor rax, rax
    mov rdi, 2             ; AF_INET
    mov rsi, 1             ; SOCK_STREAM
    mov rdx, 0             ; Protocol IP
    mov rax, 41            ; syscall number for socket
    syscall

    mov rbx, rax           ; Save the socket descriptor

    ; Bind socket
    mov rdi, rbx           ; Use the saved socket descriptor
    xor rcx, rcx
    push rcx               ; sin_zero
    push rcx               ; sin_addr
    push word 0x5000       ; Port 80 in network byte order
    push word 0x2          ; AF_INET
    mov rsi, rsp           ; Pointer to sockaddr_in structure
    mov rdx, 16            ; Length of sockaddr_in structure
    mov rax, 49            ; syscall number for bind
    syscall

    ; Listen on socket
    xor rax, rax
    mov rax, 50            ; syscall number for listen
    mov rdi, rbx           ; Socket file descriptor
    xor rsi, rsi           ; Backlog (number of connections to queue)
    syscall

accept:
    ; Accept connection
    xor rax, rax
    mov rax, 43            ; syscall number for accept
    mov rdi, rbx           ; Listening socket file descriptor
    xor rsi, rsi           ; NULL pointer for sockaddr
    xor rdx, rdx           ; NULL pointer for socklen_t
    syscall

    cmp rax, -1            ; Check if accept() failed
    jl accept

        xor r10,r10
    mov r10, rax           ; Save the accepted connection's file descriptor

    ; Fork a child process
    xor rax, rax
    mov rax, 57            ; syscall number for fork
    syscall

    test rax, rax
    jz child_process       ; Zero means we're in the child process
    jg parent_process      ; Positive means we're in the parent process

parent_process:
    mov rdi, r10
    mov rax, 3             ; syscall number for close
    syscall
    jmp accept             ; Loop back to accept new connections

child_process:
    ; Child process code
    ; Close the connection
    mov rdi, 3
    mov rax, 3             ; syscall number for close
    syscall

    ; Read (for handling incoming request)
    xor rdi,rdi
    mov rdi,4
    xor rax, rax           ; syscall number for read
    mov rsi, buffer        ; Buffer to store incoming request
    mov rdx, 1024          ; Max number of bytes to read
    syscall

    mov rax, buffer
    cmp byte [rax], 'G'
    je Get
    jne Post
Get:
    mov rsi,buffer
    add rsi, 4             ; Skip "GET "
    mov rdi, rsi

find_space_get:
    cmp byte [rdi], ' '
    je file_found_get
    inc rdi
    jmp find_space_get

file_found_get:
    sub rdi, rsi
    mov r12, rdi           ; Length of the file name
    mov rcx, rdi
    mov rdi, file_name
    rep movsb
    mov byte [rdi], 0x00   ; Null-terminate the file name
    jmp open


Post:
    ; Extract the file name from the GET request
    mov rsi, buffer
    add rsi, 5             ; Skip "GET "
    mov rdi, rsi

find_space:
    cmp byte [rdi], ' '
    je file_found
    inc rdi
    jmp find_space

file_found:
    sub rdi, rsi
    mov r12, rdi           ; Length of the file name
    mov rcx, rdi
    mov rdi, file_name
    rep movsb
    mov byte [rdi], 0x00   ; Null-terminate the file name



    mov rsi, buffer      ; RSI points to the start of the request
    mov rdi, target       ; RDI points to the target sequence
    mov rcx, 4           ; Length of the target sequence

find_sequence:
    mov rbx, rcx          ; Save the length of the target sequence
    mov rdi, target       ; Reset RDI to the start of the target sequence

compare_bytes:
    mov al, [rsi]         ; Load byte from request
    cmp al, [rdi]         ; Compare with byte from target
    jne next_byte         ; If not equal, go to next byte in request

    inc rsi               ; Move to the next byte in request
    inc rdi               ; Move to the next byte in target
    dec rbx               ; Decrease the length counter
    jnz compare_bytes     ; If not zero, continue comparing

    mov rax, rsi          ; Save the position where the sequence was found
    sub rax, buffer      ; Calculate the offset from the start of the request
    sub rax, 4           ; Adjust for the length of the target sequence
    mov [position], rax   ; Store the position
    mov byte [found], 1   ; If all bytes match, set found to 1
    add rsi,1
    mov r12,rsi
    jmp find_len    ; Jump to sequence_found

next_byte:
    inc rsi               ; Move to the next byte in request
    mov rcx, 4           ; Reset the length counter
    loop find_sequence    ; Repeat until the end of the request

    xor rcx,rcx
    mov [found],rsi

find_len:
    mov al,byte [rsi]
    cmp al,0x00
    je copy_string
    inc rcx
    inc rsi
    jmp find_len

copy_string:
    xor rsi,rsi
    mov rsi,r12
    xor r9,r9
    mov r9,rcx
    mov rbx,rcx
    mov rdi, found
    rep movsb
    mov byte [rdi], 0x00   ; Null-terminate the file name


sequence_found:

    ; Open the file
    mov rdi, file_name
    xor rsi,rsi
    xor rdx,rdx
    mov rdx,0777o
    mov rax, 2             ; syscall number for open
    mov rsi, 65           ; Read-only mode
    syscall

    test rax, rax
    js file_not_found

    xor r12,r12             ;save fd for later
    mov r12,rax

    mov rax, 1             ; syscall number for write
    mov rdi, r12           ; Accepted socket file descriptor
    sub r9,0x03
    mov rsi, found
    mov rdx, r9           ; Length of the file content
    syscall

    mov rdi, r12
    mov rax, 3             ; syscall number for close
    syscall

    ; Write HTTP response to socket
    mov rax, 1             ; syscall number for write
    mov rdi, r10           ; Accepted socket file descriptor
    mov rsi, response_header
    mov rdx, len_response_header
    syscall

    ; Close the connection
    mov rdi, r10
    mov rax, 3             ; syscall number for close
    syscall

    ; Exit the child process
    mov rdi, 0
    mov rax, 60            ; syscall number for exit
    syscall


open:

    ; Open the file
    mov rdi, file_name
    mov rax, 2             ; syscall number for open
    xor rsi, rsi           ; Read-only mode
    syscall

    test rax, rax
    js file_not_found

        xor r9,r9
    mov r9, rax            ; Save the file descriptor

    ; Read the file content
    mov rdi, r9
    xor rax, rax           ; syscall number for read
    mov rsi, file_content
    mov rdx, 1024          ; Max number of bytes to read
    syscall

    xor r12,r12
    mov r12, rax           ; Save the number of bytes read

    ; Close the file
    mov rdi, r9
    mov rax, 3             ; syscall number for close
    syscall

    ; Write HTTP response to socket
    mov rax, 1             ; syscall number for write
    mov rdi, r10           ; Accepted socket file descriptor
    mov rsi, response_header
    mov rdx, len_response_header
    syscall

    ; Write file content to socket
    mov rax, 1             ; syscall number for write
    mov rdi, r10           ; Accepted socket file descriptor
    mov rsi, file_content
    mov rdx, r12           ; Length of the file content
    syscall

    ; Close the connection
    mov rdi, r10
    mov rax, 3             ; syscall number for close
    syscall

    ; Exit the child process
    mov rdi, 0
    mov rax, 60            ; syscall number for exit
    syscall

file_not_found:
    jmp exit_child

exit_child:
    ; Exit the child process
    mov rdi, 0
    mov rax, 60            ; syscall number for exit
    syscall
