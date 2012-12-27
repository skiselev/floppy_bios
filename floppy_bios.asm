;=========================================================================
; floppy_main.asm - Floppy BIOS main file
;-------------------------------------------------------------------------
;
; Compiles with NASM 2.07, might work with other versions
;
; Copyright (C) 2011 Sergey Kiselev.
; Provided for hobbyist use on the Sergey's XT board.
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
;=========================================================================

	cpu	8086

%imacro setloc  1.nolist
 times   (%1-($-$$)) db 0FFh
%endm

;========================================================================
; Some constants
;------------------------------------------------------------------------
; I/O ports
pic1_reg0	equ	20h
port_b_reg	equ	61h
refresh_flag	equ	10h	; refresh flag, toggles every 15us

;------------------------------------------------------------------------
; Interrupt vectors

vect_int_0E	equ	(0Eh*4)
vect_int_13	equ	(13h*4)
vect_int_1E	equ	(1Eh*4)
vect_int_40	equ	(40h*4)

;------------------------------------------------------------------------
; BIOS data area variables
biosdseg	equ	0040h
equipment_list	equ	10h	; word - equpment list
equip_floppies	equ	0000000000000001b	; floppy drivers installed
equip_floppy2	equ	0000000001000000b	; 2nd floppy drive installed
;			        ||     `-- floppy drives installed
;			        `---- number of floppy drives - 1

fdc_calib_state	equ	3Eh	; byte - floppy drive recalibration status
fdc_motor_state	equ	3Fh	; byte - floppy drive motor status
fdc_motor_tout	equ	40h	; byte - floppy drive motor off timeout (ticks)
fdc_last_error	equ	41h	; byte - status of last diskette operation
fdc_ctrl_status	equ	42h	; byte[7] - FDC status bytes
fdc_last_rate	equ	8Bh	; byte - last data rate / step rate
fdc_info	equ	8Fh	; byte - floppy dist drive information
fdc_media_state	equ	90h	; byte[4] - drive media state (drives 0 - 3)
fdc_cylinder	equ	94h	; byte[2] - current cylinder (drives 0 - 1)

;=========================================================================
; Extension BIOS ROM header
;-------------------------------------------------------------------------
signature	dw	0AA55h	; Extension ROM signature
				; ROM size in 512 byte blocks
rom_size	db	(rom_end-signature-1)/512+1
init_entry	jmp	init
checksum_fix	db	0	; checksum correction byte

;=========================================================================
; Configuration
;-------------------------------------------------------------------------
drive_type	db	cmos_1440 << 4 | cmos_1200
;drive_type	db	cmos_2880 << 4 | cmos_no_floppy
config_flags	db	0

;=========================================================================
; Initialization code
;-------------------------------------------------------------------------
init:
	push	ax			; save registers
	push	bx
	push	cx
	push	dx
	push	si
	push	ds

;-------------------------------------------------------------------------
; set DS to interrupt table / BIOS data area

	xor	ax,ax			; DS = 0
	mov	ds,ax

;-------------------------------------------------------------------------
; print the copyright message

	mov	si,msg_copyright
	call	print

;-------------------------------------------------------------------------
; set equipment bits

set_equipment:
    cs	mov	al,byte [drive_type]
	mov	ah,byte [equipment_list+(biosdseg<<4)]
	and	ah,03Eh			; mask floppy bits

	test	al,70h
	jz	.second_floppy		; jump if first floppy is not installed
	or	ah,01h			; first floppy is installed

.second_floppy:
	test	al,07h
	jz	.save_equipment		; jump if second floppy is not installed
	or	ah,41h			; indicate two floppies
					; (even if the first one is missing)

.save_equipment:
	mov	byte [equipment_list+(biosdseg<<4)],ah

;-------------------------------------------------------------------------
; print floppy drive types

	call	print_floppy		; print floppy drive types

;-------------------------------------------------------------------------
; set interrupt vectors

	cli
	mov	ax,cs
	mov	word [vect_int_0E],int_0E
	mov	word [vect_int_0E+2],ax
	mov	word [vect_int_1E],int_1E
	mov	word [vect_int_1E+2],ax
	mov	bx,vect_int_13
	mov	si,msg_int13
	cmp	word [bx],0EC59h	; BIOS INT 13h entry point
	je	.set_floppy_isr
	mov	bx,vect_int_40		; looks like INT 13h was changed
	mov	si,msg_int40
.set_floppy_isr:
	mov	word [bx],int_13
	mov	word [bx+2],ax
	sti
	call	print

;-------------------------------------------------------------------------
; end of initialization code

	pop	ds
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	retf

;=========================================================================
; Includes
;-------------------------------------------------------------------------
%include	"floppy1.inc"		; floppy services
%include	"floppy2.inc"
%include	"messages.inc"		; messages

;=========================================================================
; delay_15us - delay for multiplies of 15 microseconds
; Input:
;	CX = time to delay (in 15 microsecond units)
; Notes:
;	1.  Actual delay will be between (CX - 1) * 15us and CX * 15us
;	2.  This relies on the "refresh" bit of port 61h and therefore on
;	    timer channel 1. Will not function properly if timer gets
;	    reprogrammed by an application or if it was not initialized yet
;-------------------------------------------------------------------------
%ifdef	AT
delay_15us:
	push	ax
	push	cx
.zero:
	in	al,port_b_reg
	test	al,refresh_flag
	jz	.zero
	dec	cx
	jz	.exit
.one:
	in	al,port_b_reg
	test	al,refresh_flag
	jnz	.one
	dec	cx
	jnz	.zero
.exit:
	pop	cx
	pop	ax
	ret
%else
delay_15us:
	push	ax
	push	cx
.1:
	mov	al,10
.2:
	dec	al
	jnz	.2
	loop	.1
	pop	cx
	pop	ax
	ret
%endif	; AT

;=========================================================================
; print - print ASCIIZ string to the console
; Input:
;	CS:SI - pointer to string to print
; Output:
;	none
;-------------------------------------------------------------------------
print:
	pushf
	push	ax
	push	bx
	push	si
	push	ds
	push	cs
	pop	ds
	cld
.1:
	lodsb
	or	al,al
	jz	.exit
	mov	ah,0Eh
	mov	bl,0Fh
	int	10h
	jmp	.1
.exit:
	pop	ds
	pop	si
	pop	bx
	pop	ax
	popf
	ret

;=========================================================================
; print_hex - print 16-bit number in hexadecimal
; Input:
;	AX - number to print
; Output:
;	none
;-------------------------------------------------------------------------
print_hex:
	push	cx
	push	ax
	mov	cl,12
	shr	ax,cl
	call	print_digit
	pop	ax
	push	ax
	mov	cl,8
	shr	ax,cl
	call	print_digit
	pop	ax
	push	ax
	mov	cl,4
	shr	ax,cl
	call	print_digit
	pop	ax
	push	ax
	call	print_digit
	pop	ax
	pop	cx
	ret

;=========================================================================
; print_dec - print 16-bit number in decimal
; Input:
;	AX - number to print
; Output:
;	none
;-------------------------------------------------------------------------
print_dec:
	push	ax
	push	cx
	push	dx
	mov	cx,10		; base = 10
	call	.print_rec
	pop	dx
	pop	cx
	pop	ax
	ret

.print_rec:			; print all digits recursively
	push	dx
	xor	dx,dx		; DX = 0
	div	cx		; AX = DX:AX / 10, DX = DX:AX % 10
	cmp	ax,0
	je	.below10
	call	.print_rec	; print number / 10 recursively
.below10:
	mov	ax,dx		; reminder is in DX
	call	print_digit	; print reminder
	pop	dx
	ret

;=========================================================================
; print_digit - print hexadecimal digit
; Input:
;	AL - bits 3...0 - digit to print (0...F)
; Output:
;	none
;-------------------------------------------------------------------------
print_digit:
	push	ax
	push	bx
	and	al,0Fh
	add	al,'0'			; convert to ASCII
	cmp	al,'9'			; less or equal 9?
	jna	.1
	add	al,'A'-'9'-1		; a hex digit
.1:
	mov	ah,0Eh			; Int 10 function 0Eh - teletype output
	mov	bl,07h			; just in case we're in graphic mode
	int	10h
	pop	bx
	pop	ax
	ret

;=========================================================================
; end of the ROM
;-------------------------------------------------------------------------
rom_end	equ	$
	setloc	2000h			; The ROM size is 8 KiB
