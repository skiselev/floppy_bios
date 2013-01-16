;=========================================================================
; floppy_main.asm - Floppy BIOS main file
;-------------------------------------------------------------------------
;
; Copyright (C) 2011 - 2013 Sergey Kiselev.
; Provided for hobbyist use on the
;       ISA Floppy Disk and Serial Controller and XT-FDC cards.
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

%include	"config.inc"
%include	"macro.inc"
	org	START

;========================================================================
; Some constants
;------------------------------------------------------------------------
; I/O ports
fdc2_addr	equ	370h	; base address for the secondary FDC
pic1_reg0	equ	20h
pic1_reg1	equ	21h
port_b_reg	equ	61h
refresh_flag	equ	10h	; refresh flag, toggles every 15us

;------------------------------------------------------------------------
; Interrupt vectors

vect_int_08	equ	(08h*4)
vect_int_13	equ	(13h*4)
vect_int_1E	equ	(1Eh*4)
vect_int_40	equ	(40h*4)

;------------------------------------------------------------------------
; BIOS data area variables
biosdseg	equ	0040h

; equipment list
equipment_list	equ	10h	; word - equpment list
equip_floppies	equ	0000000000000001b	; floppy drivers installed
equip_floppy_num equ	0000000011000000b	; 2nd floppy drive installed
;			        ||     `-- floppy drives installed
;			        `---- number of floppy drives - 1

; floppy drives calibration status
; bit 7:	FDC IRQ had occurred. Set by FDC ISR (usually IRQ6) to indicate
;		completion of an I/O operation
; bits 6 - 4:	unused
; bits 3 - 0:	drive's calibration status for drives 0..3 (1 = calibrated)
fdc_calib_state	equ	3Eh	; byte - floppy drive calibration status
fdc_irq_flag	equ	80h	; FDC IRQ had occurred.

fdc_motor_state	equ	3Fh	; byte - floppy drive motor status
fdc_motor_tout	equ	40h	; byte - floppy drive motor off timeout (ticks)
fdc_last_error	equ	41h	; byte - status of last diskette operation
fdc_ctrl_status	equ	42h	; byte[7] - FDC status bytes
ticks_lo	equ	6Ch	; word - timer ticks - low word
fdc_last_rate	equ	8Bh	; byte - last data rate / step rate
fdc_info	equ	8Fh	; byte - floppy dist drive information
fdc_media_state	equ	90h	; byte[4] - drive media state (drives 0 - 3)
fdc_cylinder	equ	94h	; byte[2] - current cylinder (drives 0 - 1)

;-------------------------------------------------------------------------
; temporary area (07C0:0000) for configuration utility
temp_segment	equ	07C0h
eeprom_write	equ	0	; EEPROM write routine
temp_config	equ	100h	; configuration storage for configuration

;=========================================================================
; Extension BIOS ROM header
;-------------------------------------------------------------------------
signature	dw	0AA55h	; Extension ROM signature
				; ROM size in 512 byte blocks
rom_size	db	0Fh	; 8 KiB - 512 bytes (for configuration)
init_entry	jmp	init

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
; print floppy controllers and drives configuration

	push	es
	mov	bx,cs
	mov	es,bx
	mov	bx,drive_config
	call	print_config		; print the current configuration
	pop	es

;-------------------------------------------------------------------------
; prompt for the configuration utility
	mov	si,msg_config
	call	print
    cs	mov	cx,word [config_delay]

.config_loop:
	mov	ah,01h
	int	16h
	jz	.config_no_key
	mov	ah,00h
	int	16h			; read the keystroke
	cmp	ax,3C00h		; F2?
	jne	.config_no_key
	mov	si,msg_crlf
	call	print
	call	config_util		; F2 pressed, run the configuration

	jc	.config_done		; configuration didn't change

	push	es			; configuration had changed, print
	mov	bx,cs
	mov	es,bx
	mov	bx,drive_config
	call	print_config		; print floppy drive types
	pop	es

	jmp	.config_done

.config_no_key:

; this code waits approximately 18.2 ms
	mov	dx,word [ticks_lo+(biosdseg<<4)]

.wait:
	cmp	dx,word [ticks_lo+(biosdseg<<4)]
	je	.wait
	loop	.config_loop

	mov	si,msg_crlf
	call	print

.config_done:

;-------------------------------------------------------------------------
; set equipment bits

set_equipment:
	mov	dl,0			; first floppy drive to check

.count_drives_loop:
	call	get_drive_type
	jc	.count_drives_done	; no floppy drive
	inc	dl
	cmp	dl,4
	jb	.count_drives_loop	; repeat for the next drive number

.count_drives_done:
	mov	al,byte [equipment_list+(biosdseg<<4)]
					; set all floppy bits to 0
	and	al,~(equip_floppies|equip_floppy_num)
	cmp	dl,0
	jz	.exit			; no floppies configured
	
	or	al,equip_floppies	; at least one floppy
	dec	dl
	mov	cl,6			; position in equipment word
	shl	dl,cl
	or	al,dl			; set number of floppies

.exit:
	mov	byte [equipment_list+(biosdseg<<4)],al

;-------------------------------------------------------------------------
; clear the data areas used for > 2 drive support

	push	ds
    cs  lds	bx,[fdc_media_state_addr]
	mov	word [bx],0		; clear 4 bytes
	mov	word [bx+2],0
    cs  lds	bx,[fdc_cylinder_addr]
	mov	word [bx],0		; clear 6 bytes
	mov	word [bx+2],0
	mov	word [bx+4],0
    cs  lds	bx,[fdc_motor_state_addr]
	mov	word [bx],0		; clear 2 bytes
	pop	ds

;-------------------------------------------------------------------------
; set interrupt vectors and unmask interrupts on PIC

	cli

; set interrupt vector for the primary FDC

    cs	mov	bl,byte [fdc_config+2]	; IRQ number for the primary FDC
	mov	cl,bl			; CL = IRQ number for the primary FDC
	mov	bh,0
	add	bx,8			; IRQ mapping starts form INT 8
	shl	bx,1			; each interrupt vector takes 4 bytes
	shl	bx,1			; multiply by 4
	mov	word [bx],int_fdc
	mov	word [bx+2],cs

; unmask primary FDC interrupt on PIC

	in	al,pic1_reg1		; AL = interrupt mask
	mov	ch,0FEh			; CH, bit 0 = 0, all other bits = 1
	rol	ch,cl			; shift 0 bit to IRQ position
	and	al,ch			; unmask the IRQ
	out	pic1_reg1,al

; check if there is a secondary FDC

    cs  cmp	word [fdc_config+4],0	; secondary FDC configured?
	je	.no_fdc2		; no secondary FDC, skip interrupt
					; initialization for it

; set interrupt vector for the secondary FDC

    cs	mov	bl,byte [fdc_config+6]	; IRQ number for the secondary FDC
	mov	cl,bl			; CL = IRQ number for the secondary FDC
	mov	bh,0
	add	bx,8			; IRQ mapping starts form INT 8
	shl	bx,1			; each interrupt vector takes 4 bytes
	shl	bx,1			; multiply by 4
	mov	word [bx],int_fdc
	mov	word [bx+2],cs

; unmask secondary FDC interrupt on PIC

	in	al,pic1_reg1		; AL = interrupt mask
	mov	ch,0FEh			; CH, bit 0 = 0, all other bits = 1
	rol	ch,cl			; shift 0 bit to IRQ position
	and	al,ch			; unmask the IRQ
	out	pic1_reg1,al

; relocate timer interrupt vector

    cs	mov	bl,byte [timer_relocate] ; interrupt number for INT 8 relocation
	mov	bh,0
	shl	bx,1			; each interrupt vector takes 4 bytes
	shl	bx,1			; multiply by 4
	mov	si,word [vect_int_08]	; get INT 08h offset
	mov	word [bx],si		; store it to the relocated interrupt
	mov	si,word [vect_int_08+2]	; get INT 08h segment
	mov	word [bx+2],si		; store it to the relocated interrupt

	mov	word [vect_int_08],int_timer
	mov	word [vect_int_08+2],cs

.no_fdc2:

; set INT 1Eh vector to disk parameters table

	mov	word [vect_int_1E],int_1E
	mov	word [vect_int_1E+2],cs
	mov	bx,vect_int_40
	mov	si,msg_int40

; check if the original INT 13h points to the INT 13h entry point
; (this means that no hard drive BIOS was installed)
; FIXME: need better check, e.g. call INT 13h AH=15

	cmp	word [vect_int_13],0EC59h ; BIOS INT 13h entry point (offset)
	jne	.set_floppy_isr		; looks like INT 13h was changed
	cmp	word [vect_int_13+2],0F000h ; BIOS INT 13h entry point (segment)
	jne	.set_floppy_isr		; looks like INT 13h was changed
	mov	bx,vect_int_13
	mov	si,msg_int13

.set_floppy_isr:
	mov	word [bx],int_13
	mov	word [bx+2],cs
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
; config_util - Floppy BIOS EEPROM configuration utility
; Input:
;	none
; Output:
;	CF = 0 - configuration changed
;	CF = 1 - configuration didn't change or failed to save configuration
;	(modifies configuration in EEPROM)
;-------------------------------------------------------------------------
config_util:
	mov	si,msg_cfg_welcome
	call	print

	push	di
	push	ds
	push	es
	mov	ax,cs
	mov	ds,ax			; DS = CS
	mov	ax,temp_segment
	mov	es,ax			; ES = temp storage

	mov	si,eeprom_write_code
	mov	di,eeprom_write
	mov	cx,eeprom_write_size
	cld
    rep	movsb				; copy the eeprom_write code

	mov	si,drive_config
	mov	di,temp_config
	mov	cx,config_size		; number of configuration bytes
	cld
    rep	movsb				; copy the configuration data

	mov	ax,es
	mov	ds,ax			; DS = temp storage

.cfg_loop:
	mov	si,msg_cfg_prompt
	call	print

;-------------------------------------------------------------------------
; read keystroke, and make sure it is a vaild command

.key_loop:
	mov	ah,00h
	int	16h			; wait for a keystroke
	or	al,20h			; convert letters to the lower case
	cmp	al,'a'
	je	.valid_cmd
	cmp	al,'d'
	je	.valid_cmd
	cmp	al,'e'
	je	.valid_cmd
	cmp	al,'f'
	je	.valid_cmd
	cmp	al,'p'
	je	.valid_cmd
	cmp	al,'w'
	je	.valid_cmd
	cmp	al,'q'
	je	.valid_cmd
	cmp	al,'h'
	je	.valid_cmd
	jmp	.key_loop

;-------------------------------------------------------------------------
; dispatch

.valid_cmd:
	mov	ah,0Eh			; INT 10 function 0Eh - teletype output
	mov	bx,0007h		; page number + color (for graphic mode)
	int	10h			; print the character
	cmp	al,'a'
	je	.add_drive
	cmp	al,'d'
	je	.del_drive
	cmp	al,'e'
	je	.ena_fdc2
	cmp	al,'f'
	je	.del_fdc2
	cmp	al,'p'
	je	.print_cfg
	cmp	al,'w'
	je	.write_cfg
	cmp	al,'q'
	je	.exit_no_save
	cmp	al,'h'
	je	.help
	jmp	.key_loop

;-------------------------------------------------------------------------
; print the current configuration from temporary area

.print_cfg:
	mov	si,msg_crlf
	call	print
	mov	bx,temp_config
	call	print_config		; print the current configuration
	jmp	.cfg_loop

;-------------------------------------------------------------------------
; print the help

.help:
	mov	si,msg_cfg_help
	call	print
	jmp	.cfg_loop

;-------------------------------------------------------------------------
; exit without saving configuration

.exit_no_save:
	mov	si,msg_cfg_exit
	call	print
	stc				; configuration didn't change
	jmp	.exit

;-------------------------------------------------------------------------
; write configuration and exit

.write_cfg:
	mov	si,msg_cfg_save
	call	print
	push	ds
	push	es
	mov	cx,config_size		; number of bytes to write
	mov	ax,temp_segment
	mov	ds,ax			; DS = source segment
	mov	ax,cs
	mov	es,ax			; ES = destination segment
	mov	si,temp_config		; SI = source offset
	mov	di,drive_config		; DI = destination offset
	call	temp_segment:eeprom_write
	pop	es
	pop	ds
	jc	.write_failed
	mov	si,msg_cfg_saved
	call	print
	clc				; configuration changed
	jmp	.exit

; save failed - print the message and dump the configuration data

.write_failed:
	mov	si,msg_cfg_failed
	call	print
	mov	bx,temp_config
	mov	cx,config_size
	mov	dx,0

.print_dump:
	mov	si,msg_crlf
	call	print
	mov	ax,dx
	add	ax,drive_config		; AX = config data address in EEPROM
	call	print_hex
	mov	si,msg_double_space
	call	print

.print_dump_inner:
	mov	al,byte [bx]
	call	print_hex_byte

	mov	si,msg_space
	call	print

	inc	bx
	inc	dx
	dec	cx
	jz	.print_dump_done
	test	dx,000Fh
	jz	.print_dump		; print next 16 bytes
	jmp	.print_dump_inner	; print the next byte


.print_dump_done:
	mov	si,msg_crlf
	call	print
	stc				; failed to save configuraion
	jmp	.exit

;-------------------------------------------------------------------------
; add a drive

; - check that there is a slot available ( < 4 drives with one FDC or < 8 with two FDCs
;   - if not, print error message, exit
; - ask for logical drive number, check that it is <= (current number of drives + 1)
;   - if not, print error message, ask again.
; - check what FDCs have available physical drive numbers
;   - if both FDCs have - ask FDC number, otherwise use one with available numbers, and notify user
; - check for available physical drive numbers on selected FDC
;   - if several numbers are available - ask drive number, otherwise use one that is available
; - ask user for the drive type
;
; - insert new drive into the configuration, shift down drives if needed

.add_drive:
	call	.count_drives
	mov	ch,dl
	add	ch,dh			; CH = total number of drives

	mov	bx,word [temp_config+(fdc_config-config)+4]
					; BX = secondary FDC address
	or	bx,bx
	jz	.add_drive_no_fdc2

	cmp	ch,8			; two FDCs, 8 drives?
	je	.add_drive_too_many	; there are 8 drives already configured

	mov	bh,0			; BH = 0 - add drive on primary FDC
	cmp	dh,4
	je	.add_drive_skip_fdc	; ask physical drive number

	mov	bh,1			; BH = 1 - add drive on secondary FDC
	cmp	dl,4
	je	.add_drive_skip_fdc	; ask physical drive number

; ask FDC number
	mov	si,msg_cfg_fdc_num
	call	print

.add_drive_fdc_key_loop:
	mov	ah,00h
	int	16h			; wait for a keystroke
	cmp	al,'1'
	jb	.add_drive_fdc_key_loop
	cmp	al,'2'
	ja	.add_drive_fdc_key_loop
	mov	ah,0Eh			; INT 10 function 0Eh - teletype output
	mov	bx,0007h		; page number + color (for graphic mode)
	int	10h			; print the character
	sub	al,'1'			; convert from ASCII
	mov	bh,al			; BH = FDC number to add drive on

	jmp	.add_drive_phys_drv	; ask physical drive number

.add_drive_too_many:
	mov	si,msg_cfg_drv_many
	call	print
	jmp	.cfg_loop

.add_drive_no_fdc2:
	cmp	dl,4			; one FDC, 4 drives?
	je	.add_drive_too_many

; ask physical drive number
; FIXME - if only one physical drive is availabe - use it (don't ask)

.add_drive_skip_fdc:
	mov	si,msg_cfg_fdc_add
	call	print
	mov	si,msg_cfg_fdc_pri
	cmp	dh,0
	je	.add_drive_print_fdc
	mov	si,msg_cfg_fdc_sec

.add_drive_print_fdc:
	call	print

.add_drive_phys_drv:
	mov	si,msg_cfg_phys_num
	call	print

.add_drive_phys_key_loop:
	mov	ah,00h
	int	16h
	cmp	al,'0'
	jb	.add_drive_phys_key_loop
	cmp	al,'3'
	ja	.add_drive_phys_key_loop
	mov	ah,0Eh			; INT 10 function 0Eh - teletype output
	push	bx
	mov	bx,0007h		; page number + color (for graphic mode)
	int	10h			; print the character
	pop	bx
	sub	al,'0'

	mov	si,temp_config+(drive_config-config)
	mov	cl,NUM_DRIVES

.add_drive_phys_check_num:
	cmp	byte [si],type_none
	je	.add_drive_phys_done	; last drive reached, no conflict
	cmp	byte [si+1],bh		; does it match the FDC number?
	jne	.add_drive_phys_next	; doesn't match, continue
	cmp	byte [si+2],al		; does it match the physical drive num?
	jne	.add_drive_phys_next	; doesn't match, continue
	mov	si,msg_cfg_phys_alr
	call	print
	jmp	.add_drive_phys_drv

.add_drive_phys_next:
	add	si,4
	dec	cl
	jnz	.add_drive_phys_check_num

.add_drive_phys_done:
	mov	bl,al			; BL = physical drive number

; ask logical drive number

	mov	si,msg_cfg_log_num
	call	print
	mov	al,ch			; CH = number of drives
					; also the next available drive
	call	print_digit
	mov	si,msg_close_bracket
	call	print
	add	ch,'0'			; convert to ASCII

.add_drive_log_key_loop:
	mov	ah,00h
	int	16h
	cmp	al,'0'
	jb	.add_drive_log_key_loop
	cmp	al,ch
	ja	.add_drive_log_key_loop
	mov	ah,0Eh			; INT 10 function 0Eh - teletype output
	push	bx
	mov	bx,0007h		; page number + color (for graphic mode)
	int	10h			; print the character
	pop	bx
	sub	al,'0'
	mov	dl,al			; DL = logical drive number

; ask drive type

	mov	si,msg_cfg_type
	call	print

.add_drive_type_loop:
	mov	ah,00h
	int	16h
	cmp	al,'1'
	jb	.add_drive_type_loop
	cmp	al,'6'
	ja	.add_drive_type_loop
	cmp	al,'5'
	je	.add_drive_type_loop
	mov	ah,0Eh			; INT 10 function 0Eh - teletype output
	push	bx
	mov	bx,0007h		; page number + color (for graphic mode)
	int	10h			; print the character
	pop	bx
	sub	al,'0'
	mov	ah,al			; AH = drive type

	call	add_drive		; add the drive
	jmp	.cfg_loop

;-------------------------------------------------------------------------
; delete a drive

.del_drive:
	call	.count_drives
	add	dl,dh			; DL = total number of drives
	cmp	dl,1
	jb	.del_drive_no_drives
	ja	.del_drive_prompt	; more than one drive, ask user
	mov	dl,0			; single drive, delete it
	jmp	.del_drive_delete

.del_drive_prompt:
	mov	si,msg_cfg_drv_del
	call	print
	mov	al,dl
	dec	al			; AL = number of the last drive
	call	print_digit
	mov	si,msg_close_bracket
	call	print

	mov	dh,dl
	add	dh,'0'-1		; DH = maximal drive number in ASCII

.del_drive_key_loop:
	mov	ah,00h
	int	16h			; wait for a keystroke
	cmp	al,'0'
	jb	.ena_fdc2_dma_key_loop
	cmp	al,dh
	ja	.ena_fdc2_dma_key_loop
	mov	ah,0Eh			; INT 10 function 0Eh - teletype output
	mov	bx,0007h		; page number + color (for graphic mode)
	int	10h			; print the character
	sub	al,'0'			; convert from ASCII
	mov	dl,al			; DL = drive to delete

.del_drive_delete:
	call	del_drive
	jmp	.cfg_loop

.del_drive_no_drives:
	mov	si,msg_cfg_no_drv
	call	print
	jmp	.cfg_loop

;-------------------------------------------------------------------------
; enable and configure secondary FDC

.ena_fdc2:
	mov	word [temp_config+(fdc_config-config)+4],fdc2_addr
	mov	si,msg_cfg_fdc_irq
	call	print

.ena_fdc2_irq_key_loop:
	mov	ah,00h
	int	16h			; wait for a keystroke
	cmp	al,'2'
	jb	.ena_fdc2_irq_key_loop
	cmp	al,'7'
	ja	.ena_fdc2_irq_key_loop
	mov	ah,0Eh			; INT 10 function 0Eh - teletype output
	mov	bx,0007h		; page number + color (for graphic mode)
	int	10h			; print the character
	sub	al,'0'			; convert from ASCII
	mov	byte [temp_config+(fdc_config-config)+6],al
					; store into configuration arae

	mov	si,msg_cfg_fdc_dma
	call	print

.ena_fdc2_dma_key_loop:
	mov	ah,00h
	int	16h			; wait for a keystroke
	cmp	al,'1'
	jb	.ena_fdc2_dma_key_loop
	cmp	al,'3'
	ja	.ena_fdc2_dma_key_loop
	mov	ah,0Eh			; INT 10 function 0Eh - teletype output
	mov	bx,0007h		; page number + color (for graphic mode)
	int	10h			; print the character
	sub	al,'0'			; convert from ASCII
	mov	byte [temp_config+(fdc_config-config)+7],al
					; store into configuration area

	jmp	.cfg_loop		; back to main configuration loop

;-------------------------------------------------------------------------
; disable secondary FDC

.del_fdc2:
	cmp	word [temp_config+(fdc_config-config)+4],0000h
					; the secondary FDC is already disabled?
	jz	.del_fdc2_already

	mov	si,msg_cfg_fdc_del
	call	print

.dev_fdc2_key_loop:
	mov	ah,00h
	int	16h			; wait for a keystroke
	or	al,20h			; convert letters to the lower case
	cmp	al,'y'
	je	.dev_fdc2_key_yes
	cmp	al,'n'
	je	.dev_fdc2_key_no
	jmp	.dev_fdc2_key_loop

.dev_fdc2_key_no:
	mov	ah,0Eh			; INT 10 function 0Eh - teletype output
	mov	bx,0007h		; page number + color (for graphic mode)
	int	10h			; print the character
	jmp	.cfg_loop

.dev_fdc2_key_yes:
	mov	ah,0Eh			; INT 10 function 0Eh - teletype output
	mov	bx,0007h		; page number + color (for graphic mode)
	int	10h			; print the character

	mov	bx,temp_config+(drive_config-config)
					; BX = drives configuration area
	mov	dl,0

.dec_fdc2_drv_del_loop:
	cmp	byte [bx],type_none
	je	.dec_fdc2_drv_del_done
	cmp	byte [bx+1],1		; drive is on FDC2?
	jne	.dec_fdc2_drv_del_not_fdc2
	call	del_drive
	jmp	.dec_fdc2_drv_del_loop

.dec_fdc2_drv_del_not_fdc2:
	add	bx,4			; point to the next drive
	inc	dl
	cmp	dl,NUM_DRIVES
	jne	.dec_fdc2_drv_del_loop

.dec_fdc2_drv_del_done:
	mov	word [temp_config+(fdc_config-config)+4],0000h
					; disable FDC
	jmp	.cfg_loop
	

.del_fdc2_already:
	mov	si,msg_cfg_fdc_alr
	call	print
	jmp	.cfg_loop		; back to main configuration loop

;-------------------------------------------------------------------------
; return to the BIOS extension initialization code

.exit:
	pop	es
	pop	ds
	pop	di
	ret

;-------------------------------------------------------------------------
; .count_drives - Count drives in the temp_config area
; Input:
;	drives data (temp_config)
; Output:
;	DL = number of drives on the primary FDC
;	DH = number of drives on the secondary FDC
;-------------------------------------------------------------------------
.count_drives:
	mov	cx,NUM_DRIVES
	xor	dx,dx			; reset counters
	mov	bx,temp_config+(drive_config-config)

.count_loop:
	cmp	byte [bx],type_none	; last drive?
	je	.count_done
	cmp	byte [bx+1],0		; drive is on the primary FDC?
	je	.count_primary
	inc	dh			; increment secondary FDC drives counter
	jmp	.count_next

.count_primary:
	inc	dl			; increment primary FDC drives counter

.count_next:
	add	bx,4			; move pointer to the next drive
	loop	.count_loop

.count_done:
	ret

;=========================================================================
; del_drive - Delete a drive from the configuration
; Input:
;	DL = drive number
;	ES:temp_config - configuration data
; Output:
;	none (drive is deleted)
;-------------------------------------------------------------------------
del_drive:
	push	cx
	push	si
	push	di
	push	ds
	mov	cx,es
	mov	ds,cx			; DS = ES
	mov	cl,dl
	mov	ch,0			; CX = number of drive to delete
	shl	cx,1
	shl	cx,1
	add	cx,temp_config+(drive_config-config)
	mov	di,cx			; DI = destination address
	mov	si,cx
	add	si,4			; SI = source address
	mov	cx,NUM_DRIVES-1
	sub	cl,dl			; CX = number of drives to move up
	shl	cx,1			; 4 bytes per drive entry
	shl	cx,1			; CX = number of bytes to move
	cld				; forward direction
    rep	movsb				; shift it
	mov	al,0
	mov	cx,4
    rep	stosb				; fill the last entry with zeros
	pop	ds
	pop	di
	pop	si
	pop	cx
	ret

;=========================================================================
; add_drive - Add a drive to the configuration
; Input:
;	AH = drive type
;	BH = FDC number (0 or 1)
;	BL = physical drive number (0 to 3)
;	DL = drive number
;	ES:temp_config - configuration data
; Output:
;	none (drive is deleted)
;-------------------------------------------------------------------------
add_drive:
	push	cx
	push	si
	push	di
	push	ds
	mov	cx,es
	mov	ds,cx			; DS = ES
	mov	si,temp_config+(drive_config-config)+NUM_DRIVES*4-5
					; SI = source address
	mov	di,temp_config+(drive_config-config)+NUM_DRIVES*4-1
					; DI = destination address
	mov	cx,NUM_DRIVES-1
	sub	cl,dl			; CX = number of drives to move down
	shl	cx,1			; 4 bytes per drive entry
	shl	cx,1			; CX = number of bytes to move
	std				; backward direction
    rep	movsb				; shift it
	mov	al,0
    	stosb				; fill in the padding byte with 0
	mov	al,bl
	stosb				; store physical drive number
	mov	al,bh
	stosb				; store FDC number
	mov	al,ah
	stosb				; store drive type
	pop	ds
	pop	di
	pop	si
	pop	cx
	ret

;=========================================================================
; get_media_state - Get drive's media state from the data area
; Input:
;	[BP+phys_drive] = physical drive number
;	[BP+fdc_num] = FDC number
; Output:
;	BL = drive's media state
;	BH = 0 (destroyed)
;-------------------------------------------------------------------------
get_media_state:
	mov	bl,byte [bp+phys_drive]
	mov	bh,0			; BX = physical drive number
	cmp	byte [bp+fdc_num],1	; drive is on the secondary FDC?
	jae	.fdc2
	mov	bl,byte [fdc_media_state+bx]
	ret

.fdc2:
	push	si
	push	ds
    cs	lds	si,[fdc_media_state_addr]
	add	si,bx
	mov	bl,byte [si]
	pop	ds
	pop	si
	ret

;=========================================================================
; set_media_state - Store drive's media state in the data area
; Input:
;	AL = media state
;	[BP+phys_drive] = physical drive number
;	[BP+fdc_num] = FDC number
; Output:
;	none
;-------------------------------------------------------------------------
set_media_state:
	push	bx
	mov	bl,byte [bp+phys_drive]
	mov	bh,0			; BX = physical drive number
	cmp	byte [bp+fdc_num],1	; drive is on the secondary FDC?
	jae	.fdc2
	mov	byte [fdc_media_state+bx],al
	jmp	.exit

.fdc2:
	push	si
	push	ds
    cs	lds	si,[fdc_media_state_addr] ; DS:SI = address of media state area
	add	si,bx
	mov	byte [si],al
	pop	ds
	pop	si

.exit:
	pop	bx
	ret

;=========================================================================
; get_last_rate - Get last FDC rate from the BIOS data area
; Input:
;	[BP+fdc_num] = FDC number
; Output:
;	AL = FDC rate (bits 7 - 6), other bits set to 0
;-------------------------------------------------------------------------
get_last_rate:
	mov	al,byte [fdc_last_rate]
	cmp	byte [bp+fdc_num],0	; drive is on the primary FDC?
	je	.fdc1
	shl	al,1			; move rate bits to bits 7 - 6
	shl	al,1			; for the secondary FDC
.fdc1:
	and	al,0C0h			; clear non data rate bits
	ret
	
;=========================================================================
; set_last_rate - Store last FDC rate in the BIOS data area
; Input:
;	AL = FDC rate (bits 7 - 6)
;	[BP+fdc_num] = FDC number
; Output:
;	none
;-------------------------------------------------------------------------
set_last_rate:
	push	ax
	and	al,0C0h			; get the data rate bits only
	mov	ah,3Fh			; AND mask for data rate bits
	cmp	byte [bp+fdc_num],0	; drive is on the primary FDC?
	je	.fdc1
	shr	al,1			; move rate bits to 5 - 4
	shr	al,1			; for the secondary FDC
	mov	ah,0CFh			; mask bits 5 - 4
.fdc1:
	and	byte [fdc_last_rate],ah	; clear rate bits
	or	byte [fdc_last_rate],al	; set new bits
	pop	ax
	ret

;=========================================================================
; check_cylinder - Compare specified cylinder with value in the BIOS data area
; Input:
;	CH = current cylinder
;	[BP+phys_drive] = physical drive number
;	[BP+fdc_num] = FDC number
; Output:
;	ZF = 1 - cylinder matches
;-------------------------------------------------------------------------
check_cylinder:
	push	bx
	mov	bl,byte [bp+phys_drive]
	mov	bh,0			; BX = physical drive number
	cmp	byte [bp+fdc_num],1	; drive is on the secondary FDC?
	jae	.fdc2
	cmp	bl,2			; drive number below 2 (0 or 1)?
	jae	.fdc1_drive23
	cmp	byte [fdc_cylinder+bx],ch
	jmp	.exit

.fdc1_drive23:
	inc	bx			; drives 2 and 3 on the primary FDC
	inc 	bx			; are stored after secondary FDC drives

.fdc2:
	push	si
	push	ds
    cs	lds	si,[fdc_cylinder_addr]	; DS:SI = address of cylinder area
	add	si,bx
	cmp	byte [si],ch
	pop	ds
	pop	si

.exit:
	pop	bx
	ret

;=========================================================================
; set_cylinder - Store drive's current cylinder into the BIOS data area
; Input:
;	CH = current cylinder
;	[BP+phys_drive] = physical drive number
;	[BP+fdc_num] = FDC number
; Output:
;	none
;-------------------------------------------------------------------------
set_cylinder:
	push	bx
	mov	bl,byte [bp+phys_drive]
	mov	bh,0			; BX = physical drive number
	cmp	byte [bp+fdc_num],1	; drive is on the secondary FDC?
	jae	.fdc2
	cmp	bl,2			; drive number below 2 (0 or 1)?
	jae	.fdc1_drive23
	mov	byte [fdc_cylinder+bx],ch
	jmp	.exit

.fdc1_drive23:
	inc	bx			; drives 2 and 3 on the primary FDC
	inc 	bx			; are stored after secondary FDC drives

.fdc2:
	push	si
	push	ds
    cs	lds	si,[fdc_cylinder_addr]	; DS:SI = address of cylinder area
	add	si,bx
	mov	byte [si],ch
	pop	ds
	pop	si

.exit:
	pop	bx
	ret

;=========================================================================
; check_drive_calibrated - Check if the drive calibrated bit is set
;			   in the BIOS data area
; Input:
;	[BP+phys_drive] = physical drive number
;	[BP+fdc_num] = FDC number
; Output:
;	CF = 1 - bit set (drive calibrated)
;-------------------------------------------------------------------------
check_drive_calibrated:
	push	cx
	mov	ch,byte [fdc_calib_state] ; calibration state for primary FDC
	mov	cl,byte [bp+phys_drive]	; CL = physical drive number
	inc	cl
	cmp	byte [bp+fdc_num],0	; drive is on the primary FDC?
	je	.fdc1
	mov	ch,byte [fdc_last_rate]	; calibration state for secodary FDC

.fdc1:
	shr	ch,cl			; set CF if drive is calibrated
	pop	cx
	ret

;=========================================================================
; set_drive_calibrated - Set drive calibrated bit in the BIOS data area
; Input:
;	[BP+phys_drive] = physical drive number
;	[BP+fdc_num] = FDC number
; Output:
;	none
;-------------------------------------------------------------------------
set_drive_calibrated:
	push	cx
	mov	cl,byte [bp+phys_drive]	; CL = physical drive number
	mov	ch,1			; bit 0 set
	shl	ch,cl			; move it into the right position
	cmp	byte [bp+fdc_num],0	; drive is on the primary FDC?
	je	.fdc1
	or	byte [fdc_last_rate],ch	; set the bit for the secodary FDC
	jmp	.exit

.fdc1:
	or	byte [fdc_calib_state],ch ; set the bit for the primary FDC

.exit:
	pop	cx
	ret

;=========================================================================
; reset_calib_state - Reset calibration state for all drives on an FDC
; Input:
;	[BP+fdc_num] = FDC number
; Output:
;	none
;-------------------------------------------------------------------------
reset_calib_state:
	cmp	byte [bp+fdc_num],0	; drive is on the primary FDC?
	je	.fdc1
	and	byte [fdc_last_rate],0F0h ; clear calibration for secodary FDC
	ret

.fdc1:
	and	byte [fdc_calib_state],0F0h ; clear calibration for primary FDC
	ret

;=========================================================================
; get_motor_state - Return motor state byte from the BIOS data area
; Input:
;	[BP+fdc_num] = FDC number
; Output:
;	AL = motor state
;-------------------------------------------------------------------------
get_motor_state:
	cmp	byte [bp+fdc_num],1	; drive is on the secondary FDC?
	jae	.fdc2
	mov	al,byte [fdc_motor_state] ; AL = motor state byte
					; for the primary FDC
	ret

.fdc2:
	push	bx
	push	ds
    cs	lds	bx,[fdc_motor_state_addr] ; DS:BX = address of fdc_motor_state
					; for the secondary FDC
	mov	al,byte [bx]		; motor state byte for the secondary FDC
	pop	ds
	pop	bx
	ret

;=========================================================================
; check_motor_state_write - Check write mode bit in the motor state byte
;			in the BIOS data area
; Input:
;	[BP+fdc_num] = FDC number
; Output:
;	ZF = 1 - write mode
;-------------------------------------------------------------------------
check_motor_state_write:
	cmp	byte [bp+fdc_num],1	; drive is on the secondary FDC?
	jae	.fdc2
	test	byte [fdc_motor_state],fdc_write_flag ; test the write bit
					; in the byte for the primary FDC
	ret

.fdc2:
	push	bx
	push	ds
    cs	lds	bx,[fdc_motor_state_addr] ; DS:BX = address of fdc_motor_state
					; for the secondary FDC
	test	byte [bx],fdc_write_flag ; test the write bit 
					; in byte for the secondary FDC
	pop	ds
	pop	bx
	ret

;=========================================================================
; set_motor_state - Set motor state byte in the BIOS data area
; Input:
;	AL = new motor state
;	[BP+fdc_num] = FDC number
; Output:
;	none
;-------------------------------------------------------------------------
set_motor_state:
	cmp	byte [bp+fdc_num],1	; drive is on the secondary FDC?
	jae	.fdc2
	mov	byte [fdc_motor_state],al ; set the byte for the primary FDC
	ret

.fdc2:
	push	bx
	push	ds
    cs	lds	bx,[fdc_motor_state_addr] ; DS:BX = address of fdc_motor_state
					; for the secondary FDC
	mov	byte [bx],al		; set the byte for the secondary FDC
	pop	ds
	pop	bx
	ret

;=========================================================================
; set_motor_state_read - Clear write mode bit in the motor state byte
;			in the BIOS data area
; Input:
;	[BP+fdc_num] = FDC number
; Output:
;	none
;-------------------------------------------------------------------------
set_motor_state_read:
	cmp	byte [bp+fdc_num],1	; drive is on the secondary FDC?
	jae	.fdc2
	and	byte [fdc_motor_state],~fdc_write_flag ; clear the write bit
					; in the byte for the primary FDC
	ret

.fdc2:
	push	bx
	push	ds
    cs	lds	bx,[fdc_motor_state_addr] ; DS:BX = address of fdc_motor_state
					; for the secondary FDC
	and	byte [bx],~fdc_write_flag ; clear the write bit
					; in the byte for the secondary FDC
	pop	ds
	pop	bx
	ret

;=========================================================================
; set_motor_state_write - Set write mode bit in the motor state byte
;			in the BIOS data area
; Input:
;	[BP+fdc_num] = FDC number
; Output:
;	none
;-------------------------------------------------------------------------
set_motor_state_write:
	cmp	byte [bp+fdc_num],1	; drive is on the secondary FDC?
	jae	.fdc2
	or	byte [fdc_motor_state],fdc_write_flag ; set the write bit
					; in the byte for the primary FDC
	ret

.fdc2:
	push	bx
	push	ds
    cs	lds	bx,[fdc_motor_state_addr] ; DS:BX = address of fdc_motor_state
					; for the secondary FDC
	or	byte [bx],fdc_write_flag ; set the write bit 
					; in byte for the secondary FDC
	pop	ds
	pop	bx
	ret

;=========================================================================
; get_drive_type - Read drive type from configuration bytes
; Input:
;	DL = drive number (0 to 7)
; Output:
;	CF clear if successful
;		AL = drive type
;	CF set on error (invalid drive type)
;=========================================================================
get_drive_type:
	cmp	dl,(NUM_DRIVES-1)	; drive number should be <= 7
	ja	.error

	push	bx
	mov	bh,0
	mov	bl,dl			; drive number to BX
	shl	bx,1
	shl	bx,1			; multiply by 4 (4 bytes per entry)
    cs	mov	al,byte [drive_config+bx] ; drive type to AL
	pop	bx
	cmp	al,type_none
	je	.error
	cmp	al,5			; invalid value
	je	.error
	cmp	al,type_2880
	ja	.error
	clc
	ret

.error:
	stc
	ret

;=========================================================================
; print_config - Print floppy configuration
; Input:
;	ES:BX	- configuration space
; Ouput:
;	none
;-------------------------------------------------------------------------
print_config:
	push	ax
	push	cx
	push	dx
	push	si

;-------------------------------------------------------------------------
; print FDC configuration

	push	bx
	add	bx,(fdc_config-drive_config) ; BX = FDC configuration table
	xor	cx,cx			; CX = current FDC

.print_fdcs:
    es	cmp	word [bx],0		; FDC I/O address == 0?
	jz	.print_fdcs_done	; no FDC

	or	cx,cx			; CX == 0?
	jz	.print_fdcs_1		; CX == 0, no need to print semicolon

	mov	si,msg_semicolon	; print semicolon after the first FDC
	call	print

.print_fdcs_1:
	mov	si,msg_fdc
	call	print
	mov	al,cl			; AL = FDC number
	inc	al
	call	print_digit		; print FDC number (1 or 2)
	mov	si,msg_at
	call	print
    es	mov	ax,word[bx]		; FDC I/O address
	call	print_hex		; print FDC I/O address
	mov	si,msg_irq
	call	print
    es	mov	al,byte[bx+2]		; FDC IEQ
	mov	ah,0
	call	print_dec		; print FDC IRQ
	mov	si,msg_drq
	call	print
    es	mov	al,byte[bx+3]		; FDC DRQ
	call	print_digit		; print FDC IRQ - a single digit number
	inc	cx
	cmp	cx,2
	je	.print_fdcs_done
	add	bx,4			; move pointer to the next FDC
	jmp	.print_fdcs

.print_fdcs_done:
	pop	bx

;-------------------------------------------------------------------------
; print floppy drives configuration

	push	bx
	xor	cx,cx			; CX = current drive

.print_drives:
    es	cmp	byte [bx],type_none	; no drive?
	jz	.print_drives_done

	mov	si,msg_crlf		; print CR/LF before even
					; numbered drives
	test	cx,1			; CX is even?
	jz	.print_drives_1

	mov	si,msg_semicolon	; print a semicolon before odd
					; numbered drives

.print_drives_1:
	call	print
	mov	si,msg_drive
	call	print
	mov	al,cl			; AL = drive number
	call	print_digit
	mov	si,msg_colon
	call	print
    es	mov	al,byte [bx]		; AL = drive type
	mov	ah,0
	mov	si,ax
	and	si,0007h		; make sure it doesn't overflow
	shl	si,1
    cs	mov	si,word [tbl_floppy+si]
	call	print
	mov	si,msg_comma_hash
	call	print
    es	mov	al,byte [bx+2]		; AL = physical drive number
	call	print_digit
	mov	si,msg_on_fdc
	call	print
    es	mov	al,byte [bx+1]		; AL = FDC number
	inc	al
	call	print_digit
	inc	cx
	cmp	cx,8			; up to 8 drives
	je	.print_drives_done
	add	bx,4
	jmp	.print_drives

.print_drives_done:
	pop	bx
	mov	si,msg_crlf
	call	print

	pop	si
	pop	dx
	pop	cx
	pop	ax
	ret

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
	mov	ah,0Eh			; INT 10 function 0Eh - teletype output
	mov	bx,0007h		; page number + color (for graphic mode)
	cld
.1:
	lodsb
	or	al,al
	jz	.exit
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
	xchg	al,ah			; get higher byte in AL, lower in AH
	call	print_hex_byte		; print the higher byte
	xchg	al,ah			; get lower byte in AL, higher in AH
	call	print_hex_byte		; print the lower byte
	ret

;=========================================================================
; print_hex_byte - print 8-bit number in hexadecimal
; Input:
;	AL - number to print
; Output:
;	none
;-------------------------------------------------------------------------
print_hex_byte:
	push	ax
	mov	ah,al			; save AL to AH
	shr	al,1			; get higher 4 bits
	shr	al,1
	shr	al,1
	shr	al,1
	call	print_digit		; print them
	mov	al,ah			; restore original AL
	and	al,0Fh			; get lower 4 bits
	call	print_digit		; print them
	pop	ax
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
	mov	ah,0Eh			; INT 10 function 0Eh - teletype output
	mov	bx,0007h		; page number + color (for graphic mode)
	int	10h
	pop	bx
	pop	ax
	ret

;=========================================================================
; int_timer - IRQ0 ISR, called approximately every 55ms
;-------------------------------------------------------------------------
int_timer:
	push	ax
	push	bx
	push	dx
	push	ds
	mov	ax,biosdseg
	mov	ds,ax
	cmp	byte [fdc_motor_tout],1
	jne	.exit

    cs	lds	bx,[fdc_motor_state_addr] ; DS:BX = address of fdc_motor_state
					; for the secondary FDC
	and	byte [bx],0F0h		; motors on secondary FDC are off

    cs	mov	dx,word [fdc_config+4]	; get base address for the secondary FDC
	or	dx,dx
	jz	.exit			; no secondary FDC, done
	add	dx,fdc_dor_reg		; DX = Digital Output register
	mov	al,0Ch			; turn off motors, enable DMA + IRQ
	out	dx,al

.exit:
	pop	ds
	pop	dx
	pop	bx
	pop	ax
	jmp	orig_timer_isr

;=========================================================================
; Includes
;-------------------------------------------------------------------------
%include	"floppy1.inc"		; floppy services
%include	"floppy2.inc"
%include	"messages.inc"		; messages

;=========================================================================
; eprom_write - Write data to the EEPROM
; Input:
;	CX - number of bytes to copy
;	DS:SI - data source (in temporary space)
;	ES:DI - data destination (in EEPROM)
; Output:
;	CF = 0 - success
;		DL = 00h - EEPROM without software data protection (SDP)
;		DL = 01h - EEPROM with software data protection
;	CF = 1 - write failed
;	AX, BL, CX, DX, SI, DI - trashed
; Note: This function cannot run from the EEPROM that is being written.
;	It needs to be copied to the RAM first.
;-------------------------------------------------------------------------
eeprom_write_code:
	mov	bx,0007h		; page number + color (for graphic mode)
					; for INT 10 function 0Eh
	mov	dl,0			; DL = 0 - no SDP
	cld				; increment SI and DI

.write_loop:
	mov	dh,byte [si]		; DH = DS:[SI]
    es	cmp	byte [di],dh		; byte changed?
	je	.write_skip

	or	dl,dl			; SDP is enabled?
	jz	.write_data		; SDP is not enabled, just write data

.write_sdp:
	mov	ax,((0Eh << 8) + 'p')	; INT 10 function 0Eh - teletype output
	int	10h
	cli				; in case INT 10 enabled interrupts
    es  mov	byte [1555h],0AAh	; software data protection sequence
    es	mov	byte [0AAAh],55h
    es	mov	byte [1555h],0A0h

.write_data:
    es	mov	byte [di],dh		; ES:[DI] = AL (write to EEPROM)

	xor	ax,ax			; counter for the delay

.write_wait:
    es	cmp	byte [di],dh		; ES:[DI] == AL?
	je	.write_ok		; write operation is successful
	dec	ax
	jnz	.write_wait		; poll again
	or	dl,dl			; SDP is enabled?
	jnz	.failed			; write failed, even with SDP enabled
	mov	dl,1			; enable SDP (DL = 1)
	jmp	.write_sdp		; re-try using SDP sequence

.write_ok:
	mov	ax,((0Eh << 8) + 'w')	; INT 10 function 0Eh - teletype output
	int	10h
	jmp	.write_next

.write_skip:
	mov	ax,((0Eh << 8) + 's')
	int	10h

.write_next:
	inc	si
	inc	di
	loop	.write_loop		; write the next byte

.failed:
	mov	ax,((0Eh << 8) + 'E')	; INT 10 function 0Eh - teletype output
	int	10h
	stc				; failed to write EEPROM
	jmp	.exit

.done:
	clc				; completed successfully

.exit:
	sti
	retf

eeprom_write_size	equ	($-eeprom_write_code)

%if eeprom_write_size > temp_config
%error "eeprom_write code is too big - try increasing temp_config"
%endif

;=========================================================================
; checksum correction byte - changed by fix_checksum so that
; the checksum of the code portion of the BIOS extension ROM equals 0
;-------------------------------------------------------------------------
	setloc	1DFFh

correction_byte	db	0	; checksum correction byte

;=========================================================================
; configuration space
;-------------------------------------------------------------------------
	setloc	1E00h			; Configuration is at the last 512
					; bytes of the 8 KiB ROM

config:
;-------------------------------------------------------------------------
; floppy drives configuration - 8 entries of 4 bytes each.
; Entry format: <CMOS drive type>, <FDC number>, <physical drive number>, 00
drive_config:
.drive0	db	type_2880, 00h, 00h, 00h; 1.44MB, primary controller, drive #0
.drive1	db	type_1440, 01h, 00h, 00h; 1.44MB, primary controller, drive #0
.drive2	db	type_1440, 01h, 01h, 00h; 1.44MB, primary controller, drive #0
.drive3	db	type_none, 01h, 03h, 00h; no drive
.drive4	db	type_none, 01h, 03h, 00h; no drive
;.drive1	db	type_1200, 00h, 01h, 00h; 1.2MB, primary controller, drive #1
;.drive2	db	type_360,  01h, 00h, 00h; 360KB, secondary controller, drive #0
;.drive3	db	type_720,  01h, 01h, 00h; 720KB, secondary controller, drive #1
;.drive4	db	type_2880, 01h, 02h, 00h; 2.88MB, secondary controller, drive #2
.drive5	db	type_none, 01h, 03h, 00h; no drive
.drive6	db	type_none, 00h, 02h, 00h; no drive
.drive7	db	type_none, 00h, 03h, 00h; no drive

;-------------------------------------------------------------------------
; floppy disk controllers configuration - 2 entries of 4 bytes each.
; Entry format: dw <FDC base address>, db <FDC IRQ>, db <FDC DMA channel>
fdc_config:
.fdc0	dw	03F0h			; Primary FDC address
	db	06h			; Primary FDC IRQ
	db	02h			; Primary FDC DMA channel
.fdc1	dw	0370h			; Secondary FDC address
	db	07h			; Secondary FDC IRQ
	db	03h			; Secondary FDC DMA channel

; pointers to the data structures other than standard BIOS data area
; by default - use interrupt vectors 0B0h - 0B2h to store this data

; floppy drive media state for drives 4-7: 4 bytes
fdc_media_state_addr:
		dw	(0B0h * 4)	; offset
		dw	0		; segment

; current cylinder for drives 2-7: 6 bytes
fdc_cylinder_addr:
		dw	(0B1h * 4)	; offset
		dw	0		; segment

; mode, motor state, and selected drive for the secondary FDC: 1 byte
fdc_motor_state_addr:
		dw	(0B2h * 4 + 2)	; offset
		dw	0		; segment

; configuration prompt delay in 55 ms units
config_delay	dw	36		; approximately 2 seconds

; call the original timer interrupt service routine
orig_timer_isr:
		db	0CDh		; INT opcode
timer_relocate	db	0AFh		; relocated timer (IRQ8) vector
		iret

config_size	equ	($-config)

;=========================================================================
; end of the ROM
;-------------------------------------------------------------------------
	setloc	2000h			; The ROM size is 8 KiB
