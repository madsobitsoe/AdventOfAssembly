global _start

BITS 64
_start:
        mov r9, 1
        pop rdi               ; put no. of arguments in rdi
        cmp rdi, r9           ; Were there 1 argument only, i.e. the program name?
        je exitSuccess               ; if there were no args, exit
        pop rax               ; else pop arg-pointer into rax
        pop rax               ; twice so we get to the actual file supplied
        ;; Attempt to open the supplied file
        call openFile
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
        pop rax                 ;get fd
        push rcx                ;store num on stack for later
        push rax                ;store the fd on stack for later
        call readFileIntoMemory
        cmp rax, 0
        jl exitError            ;exit if error reading file
        mov [fileContentsAddr], rax ; store the address in .bss
        pop rax                 ; get fd
        call closeFile         ;; close the file

        mov rax, [fileContentsAddr]
        ;; call parseField
        ;; call matchField
lpre:
        call lengthOfEntry
lpost:
        test rax,rax
        js exitError

        call parseAndValidatePassport
        call printResult

        mov rax, [fileContentsAddr]
        pop rcx                 ; num of bytes
        call unmapMem
        call exitSuccess

lengthOfEntry:
        ;; an entry is of varying length, but ends with \n\n (0x0a0a)
        ;; Find the length of an entry
        ;; preconds: addr of start of entry in rax
        ;; postconds: none
        ;; returns length in rax
        push 0                  ; counter
lengthOfEntryLoop:
        push rax                ;store addr
        mov rcx, newline         ; search for a newline
        mov rdi, 1              ; one char to compare with (0x0a)
        call readUntil
        test rax,rax            ; err?
        js lengthOfEntryErr     ; then errExit
        add [rsp+8], rax
        xchg rax,rdx            ; len of string in rdx
        pop rax                 ; get orig addr
        add rax,rdx             ; update offset
        inc rax                 ; skip the read newline
        inc byte [rsp]               ;and update the count accordingly
lmid:
        cmp byte [rax],0xa           ;is the next char a newline?
        je lengthOfEntryDone
        jmp lengthOfEntryLoop
lengthOfEntryErr:
        add rsp,16
        mov rax, -1
        ret
lengthOfEntryDone:
        pop rax
        ret


parseAndValidatePassport:
        ;; preconds:
        ;; addr of start of passport in rax
        ;; postconds
        ;; returns number of bytes read in rax
        ;; updates [validPassports] if passport is valid

        ;; parse the first field
        push rax                ; save addr
        call parseField
        pop rax                 ; restore addr
        push rax                ; put back on stack
        mov rcx, spaceAndNewLine
        mov rdi, 2
        call readUntil
        test rax,rax            ; if rax is -1 we have an error
        js exitError            ; so exit (TODO: EXIT NICELY)
        inc rax                 ; add one to offset the space
        ;; for now, just return to test it all
        add rsp,8
        ret

;;; Needed fields:
;; byr (Birth Year) - 1
;; iyr (Issue Year) - 2
;; eyr (Expiration Year) - 4
;; hgt (Height) - 8
;; hcl (Hair Color) - 16
;; ecl (Eye Color) - 32
;; pid (Passport ID) - 64
;; cid (Country ID)  - 128       OPTIONAL
        ;; So each of the is a bit, and I or them together as I detect them
        ;; If result is ge 127, it's valid

        ;; Format for field is
        ;; xyz:whatevs
parseField:
        ;; preconds:
        ;; addr of start of field in rax
        ;; must point to first "char" of field
        ;; postConds:
        ;; updates [currentField]
        ;; Remarks:
        ;; Right now, just copies 4 bytes - part2 might need more complicated parsing
        mov ecx, [rax]
        mov dword [currentField], ecx
        ret

matchField:
        ;; preconds:
        ;; field to match has been read into [currentField]
        ;; postconds:
        ;; if a match was found, the associated bit in [validPassport] is set
        mov eax, [byr]
        cmp dword [currentField], eax
        jne matchFieldIyr
        or dword [validPassport], byrID
        ret
matchFieldIyr:
        mov eax, [iyr]
        cmp dword [currentField], eax
        jne matchFieldEyr
        or dword [validPassport], iyrID
        ret
matchFieldEyr:
        mov eax, [eyr]
        cmp dword [currentField], eax
        jne matchFieldHgt
        or dword [validPassport], eyrID
        ret
matchFieldHgt:
        mov eax, [hgt]
        cmp dword [currentField], eax
        jne matchFieldHcl
        or dword [validPassport], hgtID
        ret
matchFieldHcl:
        mov eax, [hcl]
        cmp dword [currentField], eax
        jne matchFieldEcl
        or dword [validPassport], hclID
        ret
matchFieldEcl:
        mov eax, [ecl]
        cmp dword [currentField], eax
        jne matchFieldPid
        or dword [validPassport], eclID
        ret
matchFieldPid:
        mov eax, [pid]
        cmp dword [currentField], eax
        jne matchFieldCid
        or dword [validPassport], pidID
        ret
matchFieldCid:
        mov eax, [cid]
        cmp dword [currentField], eax
        jne matchFieldNoMatch
        or dword [validPassport], cidID
        ret
matchFieldNoMatch:
        ret
        ;;         ;; Remarks:
;;         push 0                  ; make space on stack to store no. of bytes read
;;         push rax                ; store address of line-beginning on stack
;;         ;; read number until '-' encountered
;;         mov cl, 0x2d            ;; '-' has ascii value 0x2d / 45 decimal
;;         call readUntil
;;         pop rcx                 ; addr
;;         xchg rax,rcx            ; addr in rax, bytes read in rcx
;;         ;; add rax,rcx             ; increment rax (addr) with num of bytes read
;;         push rax                ;store new address on stack
;;         add [rsp], rcx          ; incr. addr with number of bytes read
;;         add [rsp+8], rcx        ; incr. no. of bytes read with number of bytes read
;;         call asciiToInt
;;         cmp rax, 0
;;         jl exitError            ; if -1 just exit :(
;;         pop rcx                 ; put addr in rcx
;;         xchg rax,rcx            ; addr in rax, result of int in rcx
;;         mov [ruleMem],cl        ; store result
;;         inc rax                 ; skip the '-' byte
;;         inc byte [rsp]        ; incr. no. of bytes read with number of bytes read
;;         push rax                ; store (new) addr
;;         ;; read number until ' ' encountered:
;;         mov cl, 0x20            ; ' ' has ascii value 0x20 / 32 decimal
;;         call readUntil
;;         pop rcx                 ; addr
;;         xchg rax,rcx            ; addr in rax, bytes read in rcx
;;         push rax                ;store address on stack (again)
;;         add [rsp], rcx            ;inc addr with no. of bytes read
;;         add [rsp+8], rcx         ; incr. no. of bytes read with number of bytes read
;;         call asciiToInt
;;         cmp rax, 0
;;         jl exitError            ; if -1 just exit :(
;;         pop rcx                 ; put addr in rcx
;;         xchg rax,rcx            ; addr in rax, result of int in rcx
;;         mov [ruleMem+1],cl        ; store result
;;         inc rax                 ; skip the ' ' byte
;;         inc byte [rsp]        ; incr. no. of bytes read with number of bytes read
;;         mov cl, [rax]         ;; Read a single byte - the char of the pw rule
;;         mov byte [ruleMem+2], cl ; store it
;;         add rax,3               ; skip until the pw starts
;;         add byte [rsp], 3
;;         mov [ruleMem+4], rax    ; store addr of where the pw-string starts
;;         mov cl, 10              ; read until a newline is encountered
;;         call readUntil
;;         ;; How long was the string? Store that, and the address somewhere
;;         mov byte [ruleMem+3], al
;;         add byte [rsp], al
;;         inc byte [rsp]
;;         ;; If the string is less than first num, pw is invalid
;;         ;; mov rax, ruleMem
;;         pop rax                 ; return no. of bytes read
;;         ret

        ;; I NEED TO HAVE MULTIPLE CONDITIONS - both newline and space should be registered
readUntil:
        ;; preconds:
        ;; addr of bytes to read in rax
        ;; address of stop-bytes in rcx
        ;; number of stop-bytes in rdi
        ;; postconds:
        ;; On success:
        ;; returns bytes read in rax
        ;; On error: -1
        cmp rdi,1               ; we need at least one byte to compare with
        jl readUntilErr
readUntilSetup:
        push rax                ; store orig. addr on stack
        push 0                  ; count of bytes read
        xchg rax,rdx
readUntilLoop:
        mov byte al,[rdx]       ; byte to compare with
        mov rdi, 2              ;number of stop-bytes
        call cmpBytes
        test rax, rax           ;is rax -1, i.e. err?
        js readUntilErr         ; if so, exit with err.
        jz readUntilDone        ; if rax=0, we are done
        inc rdx                 ; else, inc rdx so we can compare next byte
        inc byte [rsp]          ; inc read count
        jmp readUntilLoop
readUntilErr:
        add rsp,16              ; restore rsp before returning
        mov rax, -1
        ret
readUntilDone:
        cmp byte [rsp], 0
        jle readUntilErr
        pop rax                 ;no of bytes read, returned in rax
        mov qword [rsp], 0
        add rsp,8               ;realign stack before return
        ret

cmpBytes:
        ;; preconds:
        ;; byte to compare in rax
        ;; address of stop-bytes in rcx
        ;; number of stop-bytes in rdi
        ;; postconds:
        ;; On successful match:
        ;; returns 0 in rax
        ;; on no-match:
        ;; returns 1  in rax
        ;; On error:
        ;; return -1 in rax
        cmp rdi, 1              ; we need at least one byte to compare with
        jl cmpBytesErr
        dec rdi                 ;decr. to use as index
cmpBytesLoop:
        cmp rdi,0               ; are we done?
        jl cmpBytesNoMatch
        cmp byte al,[rcx+rdi]
        je cmpBytesMatch
        dec rdi
        jmp cmpBytesLoop
cmpBytesMatch:
        mov rax, 0
        jmp cmpBytesDone
cmpBytesNoMatch:
        mov rax, 1
        jmp cmpBytesDone
cmpBytesErr:
        mov rax,-1
cmpBytesDone:
        ret

;; parseAndValidatePassports:
;;         ;;  Here, start parsing the file
;;         ;;  So we can validate passwords
;;         ;; returns num of valid password in rax
;;         ;; (but that is also stored at [validPasswords])
;;         push 20694                  ; total amount of bytes to read
;;         mov rax, [fileContentsAddr]  ;addr in rax
;;         push rax                     ; put addr on stack, so we can update it as we go
;; parseAndValidatePassportsLoop:
;;         cmp word [rsp+8], 0
;;         jle parseAndValidatePassportsDone
;;         mov rax, [rsp]          ;addr in rax
;;         call parseLine
;;         sub [rsp+8], rax          ; decrement count of bytes we need to read
;;         add [rsp], rax            ; update address
;;         call validatePassword
;;         jmp parseAndValidatePassportsLoop
;; parseAndValidatePassportsDone:
;;         pop rax                 ;clean up stack so we can return. Don't care about result
;;         pop rax
;;         xor eax,eax             ; 0 out rax
;;         mov ax,[validPassports] ; get num of valid passwords
;;         ret


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
        mov rax, [validPassports]
        sub rsp, 32 ; make space on stack for string
        ;; We have to add the char-bytes "backwards"
        ;; Add "Result: " and clean up stack
        mov dword [rsp], 0x75736552 ; "useR"
        mov dword [rsp+4], 0x203a746c ; " :tl"
        mov dword [rsp+8], 0
        mov qword [rsp+16], 0
        mov qword [rsp+24], 0
        xor rcx,rcx             ; use rcx for counting length of string
        mov rsi, 10             ; needed for division
intToAsciiLoop:
        xor rdx,rdx             ; clear before divide
        div rsi                 ; divide rdx:rax by 10. quotient updated in rax, remainder in rdx
        add edx, 48             ; convert remainder to ascii-digit
        inc ecx                 ; inc how many digits we've converted
        mov edi, 31             ; calculate offset for digit in string
        sub rdi, rcx            ; calculate offset for digit in string
        mov byte [rsp+rdi], dl  ; write digit to stack (from "behind")
        test rax,rax            ; are we done?
        jnz intToAsciiLoop      ; if not, get next digit
intToAsciiDone:
        mov byte [rsp+31], 10   ; add newline at end of string
        mov rax, 1              ; syscall for write
        mov rdi, 1              ; stdout
        mov rsi,rsp             ; print from stack
        mov rdx, 32             ; 32 bytes
        syscall                 ; WRITE
        add rsp, 32             ; restore stackpointer
        ret                     ; return





;; validatePassword:
;;         ;; Preconds
;;         ;; rule and Password must be parsed and written to [ruleMem]
;;         ;; postConds:
;;         ;; increment [validPasswords] if password in [ruleMem] is valid
;;         ;; Remarks:
;;         ;; No input or return value
;;         ;; overwrites rax, rcx, rdx
;;         xor rax,rax
;;         mov al, [ruleMem]       ; load minNum
;;         cmp al, [ruleMem+3]     ; if password is shorter than minNum, it is invalid
;;         jg validatePasswordExit
;;         dec al                  ; 0-index minNum
;;         mov cl, [ruleMem+2]     ; char to check for
;;         mov rdi, [ruleMem+4]    ; load password addr
;;         xor rsi,rsi	        ; use rsi for "count of matches"
;; validatePasswordCheckFirst:
;;         cmp cl, [rdi + rax]
;;         jne validatePasswordCheckSecond
;;         inc rsi
;; validatePasswordCheckSecond:
;;         mov al, [ruleMem+1]     ; load maxNum
;;         cmp al, [ruleMem+3]     ; if maxNum is outside of password, don't check
;;         jg validatePasswordFinalCheck
;;         dec al                  ; 0-index it
;;         cmp cl, [rdi + rax]
;;         jne validatePasswordFinalCheck
;;         inc rsi
;; validatePasswordFinalCheck:
;;         cmp rsi, 1
;;         jne validatePasswordExit
;;         inc word [validPasswords] ; valid password, increment count
;; validatePasswordExit:
;;         ret


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


        section .data
byrID equ 1
iyrID equ 2
eyrID equ 4
hgtID equ 8
hclID equ 16
eclID equ 32
pidID equ 64
cidID equ 128
byr:    db "byr:"
iyr:    db "iyr:"
eyr:    db "eyr:"
hgt:    db "hgt:"
hcl:    db "hcl:"
ecl:    db "ecl:"
pid:    db "pid:"
cid:    db "cid:"
spaceAndNewLine:                ;for use in parsing, when getting length of field
space:  db 0x20                 ;space
newline db 0x0A                 ;newline
section .bss
        ;; reserve 8 bytes for the memory address of the file we read
fileContentsAddr:       resb 8
        ;; Reserve 12 bytes in .bss
        ;; 1 byte for min-num,
        ;; 1 byte for max-num
        ;; 1 byte for the char (byte) to count in pw
        ;; 1 byte for length of password string
        ;; 8 bytes for address of password string
;; ruleMem:        resb 12


currentField:   resb 4
validPassport:  resb 1
        ;; Reserve 2 bytes for counting valid passports
validPassports: resb 2
