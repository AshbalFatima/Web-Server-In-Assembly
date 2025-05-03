.intel_syntax noprefix
.globl _start

.section .data
msg:
.asciz "HTTP/1.0 200 OK\r\n\r\n"	#static message
buffer:
.space 1024
open_path:
.space 1024
read_file:
.space 1024
read_file_count:
.space 1024
bytes_read:
.quad 0 		#initialize to zero, allocate 8 bytes
socket_addr:
	.short 2 	# sa-family= AF_INET
	.short 0x5000	# big endian = 0x00 0x50
	.long 0		# sin-addr = inet_addr("0.0.0.0")
	.fill 8,1,0	# padding, 8 bytes of zeroes
.section .text

_start:
	#socket
	mov rdi, 2
	mov rsi, 1
	mov rdx, 0
	mov rax, 41
	syscall			#return value is submitted in rax
	mov r10, rax

	#bind
	mov rdi, r10
	lea rsi, [socket_addr]
	mov rdx, 16
	mov rax, 49
	syscall

	#listen
	mov rdi, r10
	mov rsi, 0
	mov rax, 50
	syscall

processing_requests:
	#accept
	mov rdi, r10
	mov rsi, 0
	mov rdx, 0
	mov rax, 43
	syscall
	mov r12, rax

	#fork
	mov rax, 57
	syscall

	#check if return value is zero
	test rax, rax
	jnz closing_parent
	jz child_execution

	#close the parent process
closing_parent:
	#close(r12)
        mov rdi, r12
        mov rax, 3
        syscall

	jmp processing_requests

child_execution:
	#close(3)
        mov rdi, r10
        mov rax, 3
        syscall

	#read
	mov rdi, 4
	lea rsi, [buffer]
	mov rdx, 1024
	mov rax, 0
	syscall

	#verify if it is actually POST or GET
	lea rsi, [buffer]
	lodsb
	cmp al, 'P'
	je post_implementation
	cmp al, 'G'
	je get_implementation

post_implementation:
	#point rsi to the buffer and add 5 to it to ignore ,POST ,
	lea rsi, [buffer+5]

	#null-terminate the path
	lea rdi, [open_path] 	#rdi points to where the path will be stored (after ,POST ,

copy_path:
	lodsb 			#load a single byte from [rsi] to al, increment rsi
	cmp al, ' '
	je done_copying
	stosb			#store the path from al into [RDI], open_path
	jmp copy_path

done_copying:
	xor al, al
	stosb

	#open the POST request
	lea rdi, [open_path]
	mov rsi, 0x41
	mov rdx, 0777
	mov rax, 2
	syscall
	mov r11, rax

	#point rsi to the buffer and add 5 to it to ignore ,POST ,
        lea rsi, [buffer+5]

        #check where the body starts
        lea rdi, [read_file]    #rdi points to where the path will be stored (after ,POST ,

find_body:
        lodsb                   #load a single byte from [rsi] to al, increment rsi
        cmp al, 0x0D		#compare al with \r
        jne find_body

	lodsb
	cmp al, 0x0A		#compare al with \n
	jne find_body

        lodsb
        cmp al, 0x0D            #compare al with \r
        jne find_body

        lodsb
        cmp al, 0x0A            #compare al with \n
        jne find_body

	mov rcx, 0		#clear rcx to count length
copy_body:
 	lodsb			#load single byte from [RSI] to al
	cmp al, 0
	je write_it
        stosb                   #store the byte from al into [RDI], read_file
        inc rcx
	jmp copy_body

	#write(r11)
write_it:
        mov rdi, r11		#file descriptor of the opened file
        lea rsi, [read_file]
        mov rdx, rcx
        mov rax, 1
        syscall

	#close(r11)
	mov rdi, r11
	mov rax, 3
	syscall

	#write(4)
	mov rdi, 4
	lea rsi, [msg]
	mov rdx, 19
	mov rax, 1
	syscall

	#close(4)
	mov rdi, 4
	mov rax, 3
	syscall

	#exit
	mov rdi, 0
	mov rax, 60
	syscall

	jmp exit_call

get_implementation:
	#point rsi to the buffer and add 4 to it to ignore ,GET ,
	lea rsi, [buffer+4]

	#null-terminate the path
	lea rdi, [open_path] 	#rdi points to where the path will be stored (after ,GET ,

copying_path:
	lodsb 			#load a single byte from [rsi] to al, increment rsi
	cmp al, ' '
	je done_copy
	stosb			#store the path from al into [RDI], open_path
	jmp copying_path

done_copy:
	xor al, al
	stosb

	#open
	lea rdi, [open_path]
	mov rsi, 0x0
	mov rax, 2
	syscall
	mov r11, rax

	#read(r11)
	mov rdi, r11
	lea rsi, [read_file]
	lea rdx, [read_file_count]
	mov rax, 0
	syscall
	mov rbx, rax

	#close(r11)
	mov rdi, r11
	mov rax, 3
	syscall

	#write(4)
	mov rdi, 4
	lea rsi, [msg]
	mov rdx, 19
	mov rax, 1
	syscall

	#write(4)
	mov rdi, 4
        lea rsi, [read_file]
        mov rdx, rbx
        mov rax, 1
        syscall

	#close(4)
	mov rdi, 4
	mov rax, 3
	syscall

	#exit
	mov rdi, 0
	mov rax, 60
	syscall

exit_call:
	#close accept connection
	mov rdi, r12
	mov rax, 3
	syscall

	jmp processing_requests

	#close(r10)
	mov rdi, r10
	mov rax, 3
	syscall

	#exit
	mov rdi, 0
	mov rax, 60
	syscall

