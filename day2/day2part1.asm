; nasm -f bin -o exe-name filename.asm
global _start

BITS 64
_start:
        mov r9, 1
        pop rdi               ; put no. of arguments in rdi
        cmp rdi, r9           ; Were there 1 argument only, i.e. the program name?
        je exit               ; if there were no args, exit
        pop rsi               ; else pop arg-pointer into rsi
        pop rsi               ; twice so we get to the actual file supplied
        mov r10, rsp          ; store stack pointer

openfile:
        mov rax, 2              ;syscall for open
        mov rdi, rsi            ; pointer to filename goes in rdi

        xor rsi,rsi             ; Readonly mode

        xor rdx,rdx             ; Cancel the mode
        syscall
        push rax            ; save the filedescriptor

readfile:
                                ; input file is 20694 bytes. Damn, we need more than stackspace :(

        ;; First, mmap at least 20694 bytes to store the file
        xchg rax, r8            ;put fd in r8
        mov rax, 9              ; syscall for mmap
        xor rdi,rdi             ;we don't care where the memory is. let the kernel decide
        mov rsi, 20694          ;We need 20694 bytes to store the file
        mov rdx, 1              ; PROT_READ  - no need to overwrite the file
        mov r10, 2              ; MAP_PRIVATE
        xor r9, r9              ;no offset!
        syscall                 ; map the file and pray!
        mov r12, rax            ;save address of mem-location

closefile:
        mov rax,3               ; syscall for close
        pop rdi            ; fd is in r11, mov into rdi
        syscall

;; convertLines:
;;         mov r13, 10        ;; store a newline for easy comparison (and multiplication)
;;         mov r14, rsp        ;; use r14 for indexing into read bytes from file
;;         mov r15, rsp       ;use r15 for indexing into stackspace where ints will be stored
;;         add r15, 1024      ;offset by 1024 from the start of the bytes we read from the file
;; convertLineToInt:
;;         xor rcx,rcx        ;; clear out rcx
;;         xor rax,rax        ;; clear out rax
;;         mov cl, [r14]        ;; Read one character
;;         inc r14
;;         dec r12                 ; one less byte left to read!
;;         cmp cl, r13b
;;         je convertLineDone         ;; Was it a newline? DONE
;;         sub rcx, 48             ;convert ascii to int
;;         mov rax, rcx            ; use rax for accumulator

;; convertLineLoop:
;;         mov cl, [r14]         ;; Read 1 character
;;         inc r14               ;increment index to next char
;;         dec r12                 ; one less byte left to read!
;;         cmp cl, r13b         ;; Was it a newline? DONE
;;         je convertLineDone         ;; Was it a newline? DONE
;;         sub rcx, 48             ;convert ascii to int
;;         mul r13            ;multiply by 10 (which is saved already because of the newline check!)
;;         add rax, rcx            ; use rax for accumulator
;;         jmp convertLineLoop

;; convertLineDone:
;;         ;; Copy rax to stack - where the ints are stored
;;         mov [r15],ax            ; small numbers, use two bytes for storage
;;         add r15, 2                 ; increment pointer to int-part of stack
;;         test r12,r12            ; Set ZF if we're done
;;         jnz convertLineToInt

;;         ;; Start finding a solution if this is reached.

;; findSolution:
;;         ;; ?? I need to know how many ints there are in total.
;;         mov rbx, r10            ;move original stackpointer into rbx
;;         sub rbx, 1024           ;start of ints
;;         ;; Well, 200, but I want to programmatically find it/store it
;;         ;; Get pointer to end of ints (hinthint - r15 - 2)
;;         sub r15, 2              ;pointer to "end of ints"
;;         ;; We need two pointers
;;         ;; a - r15
;;         ;; b - r8, init at r15-2
;;         ;; xor rax, put both into rax, test, sub2 if not done
;;         mov r8, r15             ;pointer to second number
;; findSolutionLoop1:
;;         xor rax,rax             ;zero out rax
;;         mov ax, [r15]           ;move the first number into rax
;;         sub r8, 2               ; point second number pointer to new second number
;;         mov rcx, r8             ; point third number pointer to new third number

;;         ;; check if we read the second-to-last number
;;         sub r8,2
;;         cmp rbx, r8
;;         je findSolution         ;if it was the last number, increment "first number"-pointer and loop again
;;         add r8,2                ;reset r8 back to "proper" position
;;         ;; jmp findSolutionLoop1
;; findSolutionLoop2:
;;         ;; Need an empty register for number 3 pointer
;;         ;; just use rcx for now, hope it works
;;         sub rcx, 2              ; third number
;;         xor rax,rax
;;         xor r9, r9
;;         mov ax, [r15]           ;first number
;;         mov r9w,[r8]            ;second number
;;         add ax,r9w
;;         xor r9,r9
;;         mov r9w, [rcx]          ;load third number
;;         add ax,r9w              ; add NUMBER 3 to rax
;;         cmp ax,2020            ; check if this is a solution
;;         je multSolution         ; if it is, jump to multiply
;;         ;; check if we read the last number
;;         cmp rbx, rcx
;;         je findSolutionLoop1         ;if it was the last number, increment "first number
;;         jmp findSolutionLoop2
;; multSolution:
;;         ;; do the multiplication if solution was found
;;         xor rax,rax
;;         mov ax, [r15]
;;         xor r9,r9
;;         mov r9w,[r8]
;;         mul r9d
;;         mov r9w,[rcx]
;;         mul r9d
;;         ;; write the solution found!
;;         ;; convert the number to an ascii string
;;         ;; print it with syscall 1, write
;;         push 0                  ;push zero to recognize end of string
;; splitIntToParts:
;;         ;; zero out rdx for use in multiplication
;;         xor rdx,rdx
;;         div r13                 ; unsigned divide by 10
;;         add rdx, 48             ;convert to ascii
;;         push rdx
;;         ;; sub rdx, 48
;;         test rax,rax
;;         jnz splitIntToParts
;; printString:
;;         mov rdi, 1
;;         mov rsi, rsp
;;         mov rdx, 1
;;         mov rax, 1
;;         syscall                 ;print one char - stupidly inefficient
;;         pop rax
;;         test rax,rax
;;         jnz printString
;;         mov rdi, 1
;;         push 10                 ;Push a newline to end it all
;;         mov rsi, rsp
;;         mov rdx, 1
;;         mov rax, 1
;;         syscall

unmapMem:
        mov rax, 11             ; syscall for munmap
        mov rdi, r12            ; address of memory
        mov rsi, 20694          ;We used 20694 bytes to store the file
        syscall                 ;unmap the mem-location
exit:
        mov     rax, 60         ; syscall for exit
        mov     rdi, 0          ; return value
        syscall                 ; exit successfully
