;=========================================================================
; flash.inc - Flash ROM and EEPROM programming functions
;-------------------------------------------------------------------------
;
; Compiles with NASM 2.11.08, might work with other versions
;
; Copyright (C) 2010 - 2021 Sergey Kiselev.
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

;-------------------------------------------------------------------------
; temporary area (07C0:0000) for the configuration utility

config_space	equ	8000h		; offset of the configuration
temp_segment	equ	07C0h		; segment for flash writing code
max_page_size	equ	16384		; maximal flash page size (Am29F010)

ticks_per_sec	equ	1193182		; 8254 PIT ticks per second
identify_delay	equ 	(ticks_per_sec/100)	; flash ID delay is 1/100 = 10 ms
write_delay	equ	(ticks_per_sec/20000)	; write/erase delay is 1/20000 = 50 us
erase_timeout	equ	(ticks_per_sec/10/write_delay)		; page erase timeout is 1/10 = 100 ms
page_write_timeout	equ	(ticks_per_sec/10/write_delay)	; page write timeout is 1/10 = 100 ms
byte_write_timeout	equ	(ticks_per_sec/100/write_delay)	; byte write timeout is 1/100 = 10 ms

;=========================================================================
; flash_write - Write configuration to Flash ROM or EEPROM
;		Must be copied to RAM and run from it
; Input:
;	CX - number of bytes to write
;	DS:BX - Source address of the data to write
;	ES:BX - Destination address in Flash ROM or EEPROM
; Output:
;	CF = 0 - success
;	CF = 1 - write failed
;	AX,CX,DX,DS,SI,DI - trashed
; Notes:
;     -	Cannot be run from Flash ROM/EEPROM that is being programmed -
;	It must be copied to RAM
;     -	The number of bytes to write (CX) input is only used for EEPROMs
;	Entire page is programmed for Flash ROMs. It is assumed that the
;	configuration fits into a page (128 bytes for some Flash ROMs)
;     -	SDP (software data protection) EEPROMs are supported
;     -	Progamming sequence:
;	1. Find first modified byte (that is different between source and ROM)
;	2. Attempt to simply modify byte - that should work for non-SDP EEPROMs
;	3. If (2) succeeds, continue programming the rest of modified bytes
;	4. If (3) fails, try to identify Flash ROM manufacturer/type
;	5. If (4) succeeds, erase and program a page of Flash ROM according to
;	   the algorithm supported by the detected Flash ROM type - either
;          page erase/byte program, or page program (with auto-erase)
;	6. If (4) does not return any value (Flash ID is not working or not
;	   supported), try using SDP sequence for 8K EEPROMs with 1555h/0AAAh
;	   command addresses
;	7. If (6) fails, try using SDP sequence for 32K EEPROMs with 5555h/2AAAh
;	   command addresses
;	8. If (7) fails, exit with error (CF = 1)
;-------------------------------------------------------------------------
flash_write:
	push	bp
	push	ds
	push	es
	pop	ds			; swap DS and ES
	pop	es
	push	es			; save for return from this subroutine
	push	ds

	mov	dl,0			; DL = 0 - no SDP EEPROM

	cli				; no interrupts while writing flash

.eeprom_write_loop:
    es  mov	dh,byte[bx]
    	cmp	byte[bx],dh		; check if the byte has changed
	je	.eeprom_write_next

	or	dl,dl			; SDP required?
	jz	.eeprom_write_data	; no SDP, try to write the byte

.eeprom_write_sdp:
	mov	byte [si],0AAh		; send SDP sequence to EEPROM
	mov	byte [di],55h		; 
	mov	byte [si],0A0h

.eeprom_write_data:
	mov	byte[bx],dh		; try to program the byte
	mov	ax,byte_write_timeout	; FIXME: use CX for the loop?

.eeprom_write_wait:
	cmp	byte[bx],dh		; was it programmed successfully?
	je	.eeprom_write_next
	push	ax
	mov	ax,write_delay
	call	pit_delay
	pop	ax
	dec	ax
	jnz	.eeprom_write_wait
	or	dl,dl			; EEPROM with SDP was attempted?
	jz	.flash_id		; not yet, check for Flash ROM
	cmp	dl,2			; DL == 2, SDP method didn't work, fail
	je	.error

; SDP with 1555h/0AAAh command addresses, didn't work, try 5555h/2AAAh
	inc	dl
	mov	si,5555h		; first command address for 32K EEPROMs
	mov	di,2AAAh		; second command address for 32K EEPROMs
	jmp	.eeprom_write_sdp

.eeprom_write_next:
	inc	bx
	loop	.eeprom_write_loop
	jmp	.exit			; EEPROM programmed successfully

; try to identify Flash ROM

.flash_id:
	mov	ax,word [0]		; get data from first two bytes of flash

; try to identify Flash ROM using 5555h and 2AAAh addresses for commands
	mov	si,5555h
	mov	di,2AAAh

	mov	byte[si],0AAh
	mov	byte[di],55h
	mov	byte[si],0F0h		; exit ID mode, reset the chip
	push	ax
	mov	ax,identify_delay
	call	pit_delay
	pop	ax

	mov	byte [si],0AAh
	mov	byte [di],55h
	mov	byte [si],90h		; enter ID mode command
	push	ax
	mov	ax,identify_delay
	call	pit_delay
	pop	ax

	mov	bp,word [0]		; get device ID
	cmp	bp,ax			; is it really an ID?
	jne	.select_flash		; yes, try to select the flash type

; try to identify Flash ROM using 0555h and 0AAAh addresses for commands
	mov	si,0555h
	mov	di,0AAAh
	mov	byte [si],0AAh
	mov	byte [di],55h
	mov	byte [si],90h		; enter ID mode command
	push	ax
	mov	ax,identify_delay
	call	pit_delay
	pop	ax
	mov	bp,word [0]		; get device ID
	cmp	bp,ax			; is it really an ID?
	jne	.select_flash		; yes, try to select the flash type

; unable to get Flash ROM ID, try EEPROM with SDP
	inc	dl			
	mov	si,1555h		; first command address for 8K EEPROMs
	mov	di,0AAAh		; second command address for 8K EEPROMs
	jmp	.eeprom_write_sdp

; unsupported Flash ROM type
.unsupported_flash:
	mov	si,msg_cfg_unk_id
	call	print
	mov	ax,bp
	call	print_hex

.error:
	stc
	sti
	pop	es
	pop	ds
	pop	bp
	ret

.select_flash:
	mov	byte[si],0AAh
	mov	byte[di],55h
	mov	byte[si],0F0h		; exit ID mode command

.try_at29c010:
	cmp	bp,0D51Fh		; 1F = Atmel, D5 = AT29C010A
	jne	.try_sst29ee010
	mov	cx,128			; sector size is 128 bytes
	and	bx,0FF80h		; round BX down to 128 bytes boundary
	jmp	.write_auto_sector

.try_sst29ee010:
	cmp	bp,07BFh		; BF = SST, 07 = SST29EE010/GLS29EE010
	jne	.try_w29ee011
	mov	cx,128			; sector size is 128 bytes
	and	bx,0FF80h		; round BX down to 128 bytes boundary
	jmp	short .write_auto_sector

.try_w29ee011:
	cmp	bp,0C1DAh		; DA = Winbond, C1 = W29EE011
	jne	.try_sst39sf010
	mov	cx,128			; sector size is 128 bytes
	and	bx,0FF80h		; round BX down to 128 bytes boundary
	jmp	short .write_auto_sector

.try_sst39sf010:
	cmp	bp,0B5BFh		; BF = SST, B5 = SST39SF010
	jne	.try_am29f010
	mov	cx,4096			; sector size is 4 KiB
	and	bx,0F000h		; round BX down to 4 KiB boundary
	jmp	short .write_erase_byte

.try_am29f010:
	cmp	bp,2001h		; 01 = AMD, 20 = Am29F010
	jne	.unsupported_flash
	mov	cx,16384		; sector size is 16 KiB
	and	bx,0C000h		; round BX down to 16 KiB boundary

; write Flash that requires block erase prior to write, and writen byte by byte
	
.write_erase_byte:
	mov	byte [si],0AAh
	mov	byte [di],55h
	mov	byte [si],80h		; erase command
	mov	byte [si],0AAh
	mov	byte [di],055h
	mov	byte [bx],30h		; erase sector command
	mov	dx,cx			; save sector size to DX
	mov	cx,erase_timeout

.write_erase_byte1:
	cmp	byte [bx],0FFh		; is it erased yet?
	je	.write_erase_byte2
	push	ax
	mov	ax,write_delay
	call	pit_delay
	pop	ax
	loop	.write_erase_byte1
	jmp	short .error		; erase timed out

.write_erase_byte2:
	mov	byte [si],0AAh
	mov	byte [di],55h
	mov	byte [si],0A0h		; enter write mode

    es	mov	al,byte [bx]		; read byte to write
	mov	byte [bx],al		; write it to flash
	mov	cx,byte_write_timeout

.write_erase_byte3:
	cmp	al,byte [bx]		; wait for write operation to complete
	je	.write_erase_byte4
	push	ax
	mov	ax,write_delay
	call	pit_delay
	pop	ax
	loop	.write_erase_byte3
	jmp	.error			; write timed out

.write_erase_byte4:
	inc	bx
	dec	dx
	jnz	.write_erase_byte3
	jmp	short .exit

; write Flash that auto erases itself and programmed sector by sector

.write_auto_sector:
	mov	byte [si],0AAh
	mov	byte [di],55h
	mov	byte [si],0A0h		; enter write mode

.write_auto_sector1:
    es	mov	al,byte [bx]		; read byte to write
	mov	byte [bx],al		; write it to flash
	inc	bx
	loop	.write_auto_sector1	; write next byte

	dec	bx
	mov	cx,page_write_timeout

.write_auto_sector2:
	cmp	al,byte [bx]		; wait for write operation to complete
	je	.exit
	push	ax
	mov	ax,write_delay
	call	pit_delay
	pop	ax
	loop	.write_auto_sector2
	jmp	.error			; write timed out

.exit:
	clc
	sti
	pop	es
	pop	ds
	pop	bp
	ret


;=========================================================================
; pit_delay - Wait the indicated number of timer ticks
; Input:
;	AX - number ticks to wait
; Output:
;	none
; Note:
;	One timer tick is 1/1193182 of a second
;-------------------------------------------------------------------------
pit_delay:
	push	bx
	push	ax
	in	al,0x61
	or	al,0x01			; enable 8254 PIT channel 2
	out	0x61,al			; write to 8255 PPI port B
	mov	bl,al			; save written value for XT/AT test
	mov	al,0xB0			; set PIT channel 2 to mode 0
	out	0x43,al			; write control word to PIT
	pop	ax			; restore AX value - number of ticks
	push	ax
	out	0x42,al			; set PIT ch. 2 inital count - low byte
	mov	al,ah
	out	0x42,al			; set PIT ch. 2 inital count - high byte
.delay_loop:
	in	al,0x61			; try reading port B first
	cmp	al,bl
	jne	.delay_test		; port B value had changed,
					; must be Xi 8088 (or an AT)
	in	al,0x62			; read PPI port C
.delay_test:
	test	al,0x20			; check if bit 5 set - PIT ch. 2 output
	jz	.delay_loop		; not set, keep waiting
	pop	ax
	pop	bx
	ret
