; nasm -f bin -o exe-name filename.asm
global _start

BITS 64
_start:
        mov r9, 1
        pop rdi               ; put no. of arguments in rdi
        cmp rdi, r9           ; Were there 1 argument only, i.e. the program name?
        je exitSuccess               ; if there were no args, exit
        pop rax               ; else pop arg-pointer into rax
        pop rax               ; twice so we get to the actual file supplied
        ;; mov r10, rsp          ; store stack pointer
        ;; Attempt to open the supplied file
        call openFile
        ;; Read it into memory
        ;; TODO use fstat(2) to find size of file
        push rax                ; store fd on stack
        mov rdi, 5              ;fstat syscall
        xchg rdi,rax            ;syscall goes in rax, fd goes in rdi
        sub rsp, 0x100             ; make space for stat struct
        mov rsi, rsp            ; buf to read fstat-struct into (use stack)
        syscall
        cmp rax, 0
        jl exitError
        mov rcx, [rsp+48]       ; filesize returned from fstat-syscall
        add rsp, 0x100           ; get rsp back to before the stat-struct was written
        ;; mov rcx, 20694          ;no. of bytes needed
        pop rax                 ;get fd
        push rcx                ;store num on stack for later
        push rax                ;store the fd on stack for later
        call readFileIntoMemory
        cmp rax, 0
        jl exitError            ;exit if error reading file
        mov [fileContentsAddr], rax ; store the address in .bss
        ;; mov r11, rax            ; safety store of addr
        pop rax                 ; get fd
        ;; xchg rax, rcx           ; move addr into rcx, fd to rax
        ;; push rcx         ;; Store addr on stack
        call closeFile         ;; close the file

        call parseAndValidatePasswords
        call printResult

        mov rax, [fileContentsAddr]
        pop rcx                 ; num of bytes
        call unmapMem
        call exitSuccess


parseAndValidatePasswords:
        ;;  Here, start parsing the file
        ;;  So we can validate passwords
        ;; returns num of valid password in rax
        ;; (but that is also stored at [validPasswords])
        push 20694                  ; total amount of bytes to read
        mov rax, [fileContentsAddr]  ;addr in rax
        push rax                     ; put addr on stack, so we can update it as we go
parseAndValidatePasswordsLoop:
        cmp word [rsp+8], 0
        jle parseAndValidatePasswordsDone
        mov rax, [rsp]          ;addr in rax
        call parseLine
        sub [rsp+8], rax          ; decrement count of bytes we need to read
        add [rsp], rax            ; update address
        call validatePassword
        jmp parseAndValidatePasswordsLoop
parseAndValidatePasswordsDone:
        pop rax                 ;clean up stack so we can return. Don't care about result
        pop rax
        xor eax,eax             ; 0 out rax
        mov ax,[validPasswords] ; get num of valid passwords
        ret


unmapMem:
        ;; precond for unmapMem
        ;; address should be in rax
        ;; length/space of memory should be in rcx
        ;; Postcond: on success, mem is unmapped
        ;; on error, exits with errno from syscall
        ;; Remarks - uses syscall, so rax, rdi, rsi, r8, r9, r10 might be overwritten
        mov rdi, 11             ;syscall no for munmap
        xchg rax,rdi            ; *addr in rdi,syscall no. in rax
        mov rsi,rcx             ; num of bytes to unmap
        syscall                 ; unmap the mem-location
        cmp rax, 0              ; Error checking
        jne exitError
        ret                     ; Return from routine



openFile:
        ;; Precond for openfile
        ;; pointer to filename should be in rax
        ;; Postcond: Filedescriptor will be returned in rax
        ;; Remarks
        ;; Only readonly flag is set (NO WRITING YET!)
        ;; No mode is set (I don't need that yet)
        ;; Uses syscall, so rax, rsi, rdi, r8, r9, r10 might be overwritten
        mov rdi, rax            ; pointer to filename goes in rdi
        mov rax, 2              ; syscall for open
        xor rsi,rsi             ; Set Readonly-mode-flag
        xor rdx,rdx             ; Cancel the mode
        syscall
        ;; Handle errors!
        cmp rax, 0
        jl exitError           ;Something went wrong. Exit gracefully with errno
        ret                     ; return to calling function (lol, label). fd is in rax



readFileIntoMemory:
        ;; Preconds
        ;; fd to open should be in rax
        ;; no. of bytes to allocate should be in rcx
        ;; postconds
        ;; On success, address is returned in rax
        ;; on error, exits with errno from syscall
        ;; remarks:
        ;; Overwrites rax,rdi,rdx, r8,r9,r10
        ;; Reserves memory in readonly mode
        ;; Mem is backed by a file
        mov r8, 9               ;syscall for mmap
        xchg rax, r8            ;put fd in r8, syscall num in rax
        mov rsi, rcx            ; no. of bytes needed
        xor rdi,rdi             ;we don't care where the memory is. let the kernel decide
        ;; mov rsi, 20694          ;We need 20694 bytes to store the file
        mov rdx, 1              ; PROT_READ  - no need to overwrite the file
        mov r10, 2              ; MAP_PRIVATE
        xor r9, r9              ; no offset!
        syscall                 ; map the file and pray!
        cmp rax, 0              ; check for errors
        jl exitError            ; exit with errno from syscal
        ret



closeFile:
        ;; Preconds:
        ;; fd should be in rax
        ;; postcond:
        ;; fd is closed
        ;; remarks:
        ;; Potentially overwrites rax,rdi,rdx,r8,r9,r10
        mov rdi, 3              ;syscall for close
        xchg rax,rdi            ; put fd in rdi, syscall no. in rax
        syscall
        cmp rax,0               ;Check for errors
        jl exitError            ;exit with errno from syscall if error
        ret                     ; else, return


asciiToInt:
        ;; Preconds:
        ;; Addr of ascii-string in rax
        ;; length of ascii-string in rcx
        ;; postconds:
        ;; On success, result will be in rax
        ;; On error: returns -1 in rax
        ;; remarks: Overwrites rax,rcx,rdx,rsi,rdi

        ;; Use the stack for different vars
        ;; addr, bytes left
        push 0                  ; zero out new stackspace
        mov [rsp],cl          ; put bytes-to-read on stack
        mov rcx,rax            ; put addr in rcx
        xor rax,rax              ; rax is acc, 0 it out
        xor rsi,rsi              ; ensure rsi is 0'ed out
        mov rdi, 10              ; 10 for multiplying
        cmp byte [rsp], 0               ; assert length is longer than 0
        je asciiToIntError       ;if not positive length, return with error
asciiToIntLoopCheck:
        cmp byte [rsp], 0
        jg asciiToIntLoop
        add rsp,8              ;restore rsp
        ret                     ;If done, return
asciiToIntLoop:
        mul rdi             ; multiply acc by 10 (prepare for adding next digit)
        xor rsi, rsi            ; ensure rsi is all zeroes
        mov sil, [rcx]           ; read next byte
        cmp sil, 48              ; ensure gte '0' in ascii
        jl asciiToIntError
        cmp sil, 57              ; ensure lte '9' in ascii
        jg asciiToIntError
        sub sil, 48              ;convert to "int"
        add rax, rsi             ; add the read digit to rax
        dec byte [rsp]           ; decrement count of bytes left
        lea rcx, [rcx+1]          ; increment pointer to next byte
        jmp asciiToIntLoopCheck

asciiToIntError:
        mov rax, -1
        add rsp, 8             ;restore rsp
        ret


printResult:
        ;; Prints the result stored at [validPasswords]
        ;; Preconds:
        ;; result has been computed
        mov rax, [validPasswords]
        sub rsp, 32             ; make space on stack for string
        mov dword [rsp], 0x75736552
        mov dword [rsp+4], 0x203a746c
        xor rcx,rcx             ; use rcx for counting length of string
        mov rcx, 8
        mov rsi, 10             ; needed for division
intToAsciiLoop:
        xor rdx,rdx             ; clear before divide
        div rsi
        add edx, 48
        mov byte [rsp+rcx], dl
        inc ecx
        test rax,rax
        jnz intToAsciiLoop
intToAsciiDone:
        mov byte [rsp+rcx], 10       ; add newline
        mov rax, 1              ;syscall for write
        mov rdi, 1              ;stdout
        mov rsi,rsp             ; print from stack
        inc rcx
        mov rdx, rcx
        syscall
        add rsp, 32
        ret



        ;; Format is
        ;; 7-9 l: vslmtglbc
parseLine:
        ;; preconds:
        ;; addr of string in rax
        ;; postConds:
        ;; returns no. of bytes read (incl. newline at end of line)
        ;; will write results to the label ruleMem (bss-section)
        ;; ruleMem = minNum (1 byte)
        ;; ruleMem+1 = maxNum (1 byte)
        ;; ruleMem+2 = char (1 byte)
        ;; ruleMem+3 = length of pw-string (1 byte)
        ;; ruleMem+4 = addr of pw-string (8 bytes)
        ;; Remarks:
        push 0                  ; make space on stack to store no. of bytes read
        push rax                ; store address of line-beginning on stack
        ;; read number until '-' encountered
        mov cl, 0x2d            ;; '-' has ascii value 0x2d / 45 decimal
        call readUntil
        pop rcx                 ; addr
        xchg rax,rcx            ; addr in rax, bytes read in rcx
        ;; add rax,rcx             ; increment rax (addr) with num of bytes read
        push rax                ;store new address on stack
        add [rsp], rcx          ; incr. addr with number of bytes read
        add [rsp+8], rcx        ; incr. no. of bytes read with number of bytes read
        call asciiToInt
        cmp rax, 0
        jl exitError            ; if -1 just exit :(
        pop rcx                 ; put addr in rcx
        xchg rax,rcx            ; addr in rax, result of int in rcx
        mov [ruleMem],cl        ; store result
        inc rax                 ; skip the '-' byte
        inc byte [rsp]        ; incr. no. of bytes read with number of bytes read
        push rax                ; store (new) addr
        ;; read number until ' ' encountered:
        mov cl, 0x20            ; ' ' has ascii value 0x20 / 32 decimal
        call readUntil
        pop rcx                 ; addr
        xchg rax,rcx            ; addr in rax, bytes read in rcx
        push rax                ;store address on stack (again)
        add [rsp], rcx            ;inc addr with no. of bytes read
        add [rsp+8], rcx         ; incr. no. of bytes read with number of bytes read
        call asciiToInt
        cmp rax, 0
        jl exitError            ; if -1 just exit :(
        pop rcx                 ; put addr in rcx
        xchg rax,rcx            ; addr in rax, result of int in rcx
        mov [ruleMem+1],cl        ; store result
        inc rax                 ; skip the ' ' byte
        inc byte [rsp]        ; incr. no. of bytes read with number of bytes read
        mov cl, [rax]         ;; Read a single byte - the char of the pw rule
        mov byte [ruleMem+2], cl ; store it
        add rax,3               ; skip until the pw starts
        add byte [rsp], 3
        mov [ruleMem+4], rax    ; store addr of where the pw-string starts
        mov cl, 10              ; read until a newline is encountered
        call readUntil
        ;; How long was the string? Store that, and the address somewhere
        mov byte [ruleMem+3], al
        add byte [rsp], al
        inc byte [rsp]
        ;; If the string is less than first num, pw is invalid
        ;; mov rax, ruleMem
        pop rax                 ; return no. of bytes read
        ret


readUntil:
        ;; preconds:
        ;; addr of bytes to read in rax
        ;; stop-byte in rcx (well, cl)
        ;; postconds:
        ;; On success:
        ;; returns bytes read in rax
        ;; On error: -1
        push 0                  ; count of bytes read
readUntilLoop:
        cmp byte [rax],cl
        je readUntilDone
        inc byte [rsp]               ; inc read count
        inc rax             ; point to next byte
        jmp readUntilLoop
readUntilErr:
        mov rax, -1
        ret
readUntilDone:
        pop rax                 ;no of bytes read, returned in rax
        cmp rax, 0
        jle readUntilErr
        ret


validatePassword:
        ;; Preconds
        ;; rule and Password must be parsed and written to [ruleMem]
        ;; postConds:
        ;; increment [validPasswords] if password in [ruleMem] is valid
        ;; Remarks:
        ;; No input or return value
        ;; overwrites rax, rcx, rdx
        mov al, [ruleMem]       ; load minNum
        cmp al, [ruleMem+3]     ; if password is shorter than minNum, it is invalid
        jg validatePasswordExit
        xor eax,eax             ; zero out rax, use for counting
        mov cl, [ruleMem+2]     ; char to count for
        mov rdx, [ruleMem+4]    ; address of password-string start
validatePasswordLoopBody:
        cmp cl, [rdx]
        jne validatePasswordLoopCond
validatePasswordLoopCharMatch:
        inc eax                 ; match found, incr. count
validatePasswordLoopCond:
        inc rdx                 ; incr. pointer in pw-string
        dec byte [ruleMem+3]    ; one less byte to read
        cmp byte [ruleMem+3], 0      ; check if done
        jg validatePasswordLoopBody
validatePasswordFinish:
        cmp al, [ruleMem]
        jl validatePasswordExit ; not valid, not enough of char
        cmp al, [ruleMem+1]
        jg validatePasswordExit ; not valid, too many of char
        inc word [validPasswords] ; valid password, increment count
validatePasswordExit:
        ret


exitError:
        mov rdi, rax            ;errno is in rax
        neg rdi                 ;negate it to get an actual errcode
        and rdi,4096            ;and it with 4096 to get proper errcode
        mov rdi,42
        jmp exit

exitSuccess:
        mov rdi,0; return value for exit syscall
exit:
        mov     rax, 60         ; syscall for exit
        syscall                 ; exit successfully

        section .bss
        ;; reserve 8 bytes for the memory address of the file we read
fileContentsAddr:       resb 8
        ;; Reserve 12 bytes in .bss
        ;; 1 byte for min-num,
        ;; 1 byte for max-num
        ;; 1 byte for the char (byte) to count in pw
        ;; 1 byte for length of password string
        ;; 8 bytes for address of password string
ruleMem:        resb 12
        ;; Reserve 2 bytes for counting valid passwords
validPasswords: resb 2
