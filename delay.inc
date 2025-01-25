;=========================================================================
; delay.inc - Delay functions
;-------------------------------------------------------------------------
; Copyright (C) 2010 - 2025 Sergey Kiselev.
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
; delay_50us - delay for multiplies of 50 microseconds using PIT
; Input:
;	CX = delay in 50 microsecond units
;
; Algorithm:
; - Calculate the total number of PIT ticks necessary
;   - Mode 3 (Square Wave) decrements the readable counter by 2, so the
;     effective frequency of the counter is actually 2386360 Hz
;   - Each 50 us is: 
;	2 * 1193182 Hz / 0.000005 s  = ~ 119 ticks
;   - Multiply 119 by CX
; - Latch the PIT and read the initial counter
; - Repeat latching the PIT and reading the counter, subtracting the delta
;   from the total number of ticks
; - Exit when countdown underflows
;
; Contributed by @640-KB (under GPL-3.0 license)
; Based on contribution by @Raffzahn (under CC BY-SA 4.0):
; https://retrocomputing.stackexchange.com/a/24874/21323
;-------------------------------------------------------------------------
delay_50us:
	push	ax
	push	bx
	push	cx
	push	dx
	mov	ax,2*50*pit_freq/10000000	; ~ 119 ticks/50 us
	mul	cx		; DX:AX = number of PIT ticks to wait
	mov	bx,ax		; DX:BX = countdown of PIT ticks to wait
	call	io_wait_latch	; AX = initial PIT channel 0 counter value
	mov	cx,ax		; CX = last read PIT channel 0 counter value
.tick_loop:
	call	io_wait_latch	; AX = current PIT channel 0 counter reading
	sub	cx,ax		; CX = # of ticks elapsed since last reading
	sub	bx,cx		; Subtract change in ticks from countdown
	mov	cx,ax		; CX = save the last read
	sbb	dx,0		; Borrow out of high word (if necessary)
	jae	.tick_loop	; Loop while countdown >= 0
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
	mov	bx,0		; DX:BX = countdown of pit ticks to wait
	mov	dx,36		; approximately 2 seconds
	call	io_wait_latch	; AX = initial PIT channel 0 counter value
	mov	cx,ax		; CX = last read PIT channel 0 counter value
.tick_loop:
	test	byte [fdc_calib_state],fdc_irq_flag
	jnz	.exit
	call	io_wait_latch	; AX = current PIT channel 0 counter reading
	sub	cx,ax		; CX = # of ticks elapsed since last reading
	sub	bx,cx		; Subtract change in ticks from countdown
	mov	cx,ax		; CX = save the last read
	sbb	dx,0		; Borrow out of high word (if necessary)
	jae	.tick_loop	; Loop while countdown >= 0
				; note CF = 1 here (underflow at SBB)
	mov	ah,fdc_e_timeout
	pop	dx
	pop	cx
	ret

.exit:
	and	byte [fdc_calib_state],~fdc_irq_flag	; clear IRQ flag
	xor	ah,ah		; AH = 0, CF = 0 - no error
	pop	dx
	pop	cx
	ret
