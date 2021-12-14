; Usage: Press key 0 or 1 to write or read a file, respectively.

bits 16
org 0x7C00

%define NEWLINE 0xA
%define CARRIAGE_RETURN 0xD

%macro read_char_mode 0
    xor ah, ah
%endmacro

%macro read_char_to_al 0
    int 0x16
%endmacro

%macro write_char_mode 0
    mov ah, 0xE
%endmacro

%macro write_char_of_al 0
    int 0x10
%endmacro

%macro newline 0
    mov al, NEWLINE ; Move cursor down
    write_char_of_al
    mov al, CARRIAGE_RETURN ; Move cursor to start of line
    write_char_of_al
%endmacro

start:
    write_char_mode
    mov al, 'B' ; boot
    write_char_of_al
    mov al, 'F' ; file
    write_char_of_al
    mov al, 'S' ; system
    write_char_of_al

menu:
    write_char_mode
    newline

    mov al, '0'
    write_char_of_al
    mov al, 'W'
    write_char_of_al
    mov al, '1'
    write_char_of_al
    mov al, 'R'
    write_char_of_al

    write_char_mode
    newline

    read_char_mode
    read_char_to_al

    cmp al, '0'
    jz write_new_file

    cmp al, '1'
    jz read_file

    jmp menu

write_new_file:
    xor bx, bx ; Empty bx, our index
find_unallocated_spot:
    mov al, byte [memory + bx]
    cmp al, 0
    jz write_name

    inc bx
    ; no out of bounds check

    jmp find_unallocated_spot

write_name:
    write_char_mode
    mov al, 'N'
    write_char_of_al
    mov al, ':'
    write_char_of_al

    mov [memory+bx], byte 1 ; Name start is marked with 1
    inc bx
read_name_char:
    read_char_mode
    read_char_to_al

    cmp al, CARRIAGE_RETURN
    jz terminate_name
    ; or al, al
    ; ; somehow the user wrote a 0 which would mess up the filesystem
    ; jz halt

    mov [memory+bx], al
    inc bx
    write_char_mode
    write_char_of_al
    jmp read_name_char
terminate_name:
    ; Don't increase BX in order to overwrite the carriage return
    mov [memory+bx], byte 2 ; Name end is terminated with 2
    inc bx

    write_char_mode
    mov al, 'C'
    write_char_of_al
    mov al, ':'
    write_char_of_al
write_file_content:
    read_char_mode
    read_char_to_al

    ; We have finished writing the file
    cmp al, CARRIAGE_RETURN ; the carriage return is also a content terminator
    jz success

    mov [memory+bx], al
    inc bx
    write_char_mode
    write_char_of_al
    jmp write_file_content
success:
    write_char_mode
    newline
    mov al, 'S'
    write_char_of_al
    jmp menu

;
; READING
;

read_file:
read_file_name:
    write_char_mode
    mov al, 'N'
    write_char_of_al
    mov al, ':'
    write_char_of_al

    ; Name to search for is saved at 5000
    mov bx, 5000
read_search_name_char:
    read_char_mode
    read_char_to_al

    cmp al, CARRIAGE_RETURN
    jz find_name_start

    mov [memory+bx], al
    inc bx
    write_char_mode
    write_char_of_al
    jmp read_search_name_char
find_name_start:
    ; Here `al` contains a carriage return.
    ; We will use it as the terminating character.
    mov [memory+bx], al

    ; The file name of the file we want to read is now at
    ; 5000, terminated with a carriage return.

    ; Now we need to find the start of a file name
    ; File names start with '1'
    xor bx, bx ; Empty bx, our index through the memory
find_name_start_loop:
    mov al, byte [memory + bx] ; memory + bx?

    cmp al, 1
    jz compare_name
    cmp al, 0 ; If this happens, no files have been written yet
    jz no_match

    inc bx
    ; no out of bounds check

    jmp find_name_start_loop

compare_name:
    inc bx
    mov si, bx
    ;push bx ; Push it so we can continue if this doesn't match

    ;mov si, memory ; move memory into si
    mov cx, 5000

    ; Now BX is the index for the file name in memory
    ; and CX is the index to the file name we entered (at 5000)
compare_name_loop:
    mov al, byte [memory + bx]
    cmp al, 2 ; The name end
    jz match

    ; Now we need to get the char at the index CX and BX
    mov dl, byte [memory + bx]

    ; We can only index with BX
    push bx
    mov bx, cx
    mov dh, [memory + bx] ; mov [memory+bx] into dh
    pop bx

    cmp dh, dl
    jnz no_match

    inc cx ; increase index of search name in memory
    inc bx ; increase index of data index
    jmp compare_name_loop

match:
    write_char_mode
    mov al, NEWLINE
    write_char_of_al
    mov al, CARRIAGE_RETURN
    write_char_of_al
read_file_content:
    inc bx ; Skip the name-terminating 2
    write_char_mode
read_file_content_loop:
    mov al, byte [memory + bx]

    write_char_of_al

    ;mov al, byte [si + bx]
    ;cmp al, CARRIAGE_RETURN
    cmp al, 0
    jz menu

    inc bx

    jmp read_file_content_loop
no_match:
    write_char_mode
    newline
    mov al, 'X'
    write_char_of_al
    jmp menu

times 510 - ($-$$) db 0
dw 0xAA55

memory:
    times 100000 db 0
