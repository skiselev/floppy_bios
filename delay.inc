;=========================================================================
; delay.inc - Delay functions
;-------------------------------------------------------------------------
; Copyright (C) 2010 - 2024 Sergey Kiselev.
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

pit_ch0_reg	equ	40h
pit_ctl_reg	equ	43h
pit_freq	equ	1193182	; PIT input frequency - 14318180 MHz / 12

;=========================================================================
; delay_15us - delay for multiplies of 15 microseconds using PIT
; Input:
;	CX = time to delay (in 15 microsecond units)
;
; - Calculate the total number of PIT ticks necessary
;	1,193,182 / 1000 ms / 1000 us / * 15 us * 2 = ~ 36 ticks/us
; - Latch the PIT and draw down the countdown total on each read.
; - Exit when countdown underflows.
;
; Note: Mode 3 (Square Wave) decrements the readable counter by 2, so the
; effective frequency of the counter is actually 2,386,360 Hz.
;
; Contributed by @640-KB (under GPL-3.0 license)
; Based on contribution by @Raffzahn (under CC BY-SA 4.0):
; https://retrocomputing.stackexchange.com/a/24874/21323
;-------------------------------------------------------------------------
delay_15us:
	push	ax
	push	bx
	push	cx
	push	dx
	mov	ax,2*15*pit_freq/1000/1000+1	; ~ 36 ticks/us	
	mul	cx		; dx:ax = countdown of pit ticks to wait
	xchg	ax,bx		; dx:bx = countdown ticks
	call	io_wait_latch	; ax = start read
	mov	cx,ax		; cx = last read
.tick_loop:
	call	io_wait_latch	; ax = current counter reading
	sub	cx,ax		; cx = # of ticks elapsed since last reading
	sub	bx,cx		; subtract change in ticks from countdown
	mov	cx,ax		; cx = save the last read
	sbb	dx,0		; borrow out of high word (if necessary)
	jae	.tick_loop	; loop while countdown >= 0
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret

;=========================================================================
; Latch PIT 0 and read counter
; Output:
;	AX = current counter
;-------------------------------------------------------------------------
io_wait_latch:
	mov	al,0		; counter 0, latch (00b)
	pushf			; save current IF
	cli			; disable interrupts
	out	pit_ctl_reg,al	; write command to ctc
	in	al,pit_ch0_reg	; read low byte of counter 0 latch
	mov	ah,al		; save it
	in	al,pit_ch0_reg	; read high byte of counter 0 latch
	popf			; restore IF state
	xchg	al,ah		; convert endian
	ret

;=========================================================================
; fdc_wait_irq - Wait for FDC interrupt for 2 seconds
; Input:
;	none
; Output:
;	CF clear if interrupt had occurred
;		AH = 00h - successful completion
;	CF set if no interrupt
;		AH = 80h - timeout
;	AL - trashed
;	BX - trashed
;-------------------------------------------------------------------------
fdc_wait_irq:
	push	cx
	push	dx
	mov	bx,6484		; dx:ax = countdown of pit ticks to wait
	mov	dx,1		; 65536 + 6484 = 72020 ticks = 2 seconds
	call	io_wait_latch	; ax = start read
	mov	cx,ax		; cx = last read
.tick_loop:
	test	byte [fdc_calib_state],fdc_irq_flag
	jnz	.exit
	call	io_wait_latch	; ax = current counter reading
	sub	cx,ax		; cx = # of ticks elapsed since last reading
	sub	bx,cx		; subtract change in ticks from countdown
	mov	cx,ax		; cx = save the last read
	sbb	dx,0		; borrow out of high word (if necessary)
	jae	.tick_loop	; loop while countdown >= 0
	mov	ah,fdc_e_timeout
	stc			; CF =1 - error
	pop	dx
	pop	cx
	ret

.exit:
	and	byte [fdc_calib_state],~fdc_irq_flag	; clear IRQ flag
	xor	ah,ah		; AH = 0, CF = 0 - no error
	pop	dx
	pop	cx
	ret
