# http_server_assembly
x86_64 Assembly HTTP Server

# x86_64 Assembly HTTP Server

A simple HTTP server written in x86_64 assembly language for Linux. This project demonstrates:
- Socket programming in assembly
- HTTP protocol basics
- Process forking
- File I/O operations

## Features
- Handles GET and POST requests
- Serves static files
- Basic HTTP response headers
- Multi-process architecture

## Building
1. Install NASM and ld
2. Assemble with: `nasm -f elf64 server.asm -o server.o`
3. Link with: `ld server.o -o server`

## Running
Execute with: `sudo ./server` (requires root for port 80)
Access via: `http://localhost/`

Note: This is an educational project and not suitable for production use.
