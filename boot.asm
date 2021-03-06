; CpS 230 Team Project: Andrew Carter & Cesar Whatley
;---------------------------------------------------
; Bootloader that loads/runs a payload
; program from the boot disk.
;---------------------------------------------------
bits 16

; Our bootloader is 512 raw bytes: we treat it all as code, although
; it has data mixed into it, too.
section	.text

; The BIOS will load us into memory at 0000:7C00h; NASM needs
; to know this so it can generate correct absolute data references.
org	0x7C00

; First instruction: jump over initial data and start executing code
start:	jmp	main

; Embedded data
boot_msg	db	"CpS 230 Bootloader", 13, 10
		db	"by Julio Whatley and Andrew Carter", 13, 10, 0
boot_disk	db	0		; Variable to store the number of the disk we boot from
retry_msg	db	"Error reading payload from disk; retrying...", 13, 10, 0

;Gets the pressed key 
GetPressedKey:
    mov ah, 0
    int 0x16  ;BIOS Keyboard Service 
    ret 

main:
	; Set DS == CS (so data addressing is normal/easy)
	mov ax, cs
	mov ds, ax

	; Set SS == 0x0800 (which will be the segment we load everything into later)
	mov ax, 0x0800
	mov ss, ax
	; Set SP == 0x0000 (stack pointer starts at the TOP of segment; first push decrements by 2, to 0xFFFE)
	; mov sp, 0x0000
	xor	sp, sp
	
	; Save the boot disk number (we get it in register DL)
	mov byte[boot_disk], dl
	
	; Print the boot message/banner
	mov	    dx, boot_msg
	call	puts
	
	call 	GetPressedKey
	
	; use BIOS raw disk I/O to load sector 2 from disk number <boot_disk> into memory at 0800:0000h (retry on failure)
	mov ah, 02h
	mov al, 30 ;sectors to read
	mov ch, 0  ;track
	mov cl, 2  ;sector id
	mov dh, 0  ;head
	mov dl, byte[boot_disk]
	mov bx, 0x0800
	mov es, bx
	mov bx, 0
	int    0x13
	
	;compare carry flag to 0 for success or failure
	jnc .success
	mov dx, retry_msg
	call puts
	ret
    
.success:
	; Finally, jump to address 0800h:0000h (sets CS == 0x0800 and IP == 0x0000)
	jmp	0x0800:0x0000

; print NUL-terminated string from DS:DX to screen using BIOS (INT 10h)
; takes NUL-terminated string pointed to by DS:DX
; clobbers nothing
; returns nothing
puts:
	push	ax
	push	cx
	push	si
	
	mov	ah, 0x0e
	mov	cx, 1		; no repetition of chars
	
	mov	si, dx
.loop:	mov	al, [si]
	inc	si
	cmp	al, 0
	jz	.end
	int	0x10
	jmp	.loop
.end:
	pop	si
	pop	cx
	pop	ax
	ret

; NASM mumbo-jumbo to make sure the boot sector signature starts 510 bytes from our origin
; (logic: subtract the START_ADDRESS_OF_OUR_SECTION [$$] from the CURRENT_ADDRESS [$],
;	yielding the number of bytes of code/data in the section SO FAR; then subtract
;	this size from 510 to give us BYTES_OF_PADDING_NEEDED; finally, emit
;	BYTES_OF_PADDING_NEEDED zeros to pad out the section to 510 bytes)
	times	510 - ($ - $$)	db	0

; MAGIC BOOT SECTOR SIGNATURE (*must* be the last 2 bytes of the 512 byte boot sector)
	dw	0xaa55