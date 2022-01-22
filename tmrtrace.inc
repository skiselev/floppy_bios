;=========================================================================
; trace data structure:
; trace_ptr	dw	?		; pointer to the next record
; trace_end	dw	?		; pointer to the end of the buffer
; trace_buf	dw	<trace_len>	; trace buffer
;-------------------------------------------------------------------------

;-------------------------------------------------------------------------
; trace events
trace_enter		equ	1
trace_motor_on		equ	2
trace_disk_change	equ	3
trace_set_rate		equ	4
trace_detect_media	equ	5
trace_send_specify	equ	6
trace_configure_dma	equ	7
trace_seek		equ	8
trace_read_write	equ	9
trace_wait_irq		equ	0Ah
trace_get_results	equ	0Bh
trace_return		equ	0Ch

;-------------------------------------------------------------------------
; use INT 0B3h vector to store pointer to the trace buffer
trace_buf_addr:
	dw	(0B3h * 4)		; offset
	dw	0			; segment

;=========================================================================
; trace_init - Initialize tracing data structure
; Input:
;	AX:DX - Pointer to the trace buffer
;		AX = 0000h - disable tracing
;	BX:DX - Pointer to the end of the trace buffer
;	CS:trace_buf_addr - pointer to the pointer to trace data structure
;-------------------------------------------------------------------------
trace_init:
	push	ax
	push	di
	push	es
	cld
    cs	les	di,[trace_buf_addr]	; ES:DI <- pointer to trace data stucture
	stosw				; initialize trace buffer offset
	xchg	ax,dx
	stosw				; initialize trace buffer segment
	mov	es,ax			; ES <- trace buffer segment
	mov	di,dx			; DI <- trace buffer offset
	xchg	ax,dx
	cmp	ax,0			; offset is zero?
	jz	.exit			; disable tracing
	add	ax,4			; AX <- pointer to the first record
	stosw				; save pointer to the first record
	mov	ax,bx			; AX <- pointer to the end of the buffer
	stosw				; save pointer to the end of the buffer
.exit:
	pop	es
	pop	di
	pop	ax
	ret

;=========================================================================
; trace_record - Create a trace record
; Input:
;	AX - Record ID
;	CS:trace_buf_addr - pointer to the pointer to trace data structure
; Output:
;	AX - timestamp
;-------------------------------------------------------------------------
trace_record:
	push	bx
	push	di
	push	es
	cld
    cs	les	di,[trace_buf_addr]	; ES:DI <- pointer to trace data structure
    es  les	bx,[di]			; ES:BX <- trace data structure
    	cmp	bx,0			; offset is zero
	jz	.exit			; tracing is disabled - exit
    es	mov	di,[bx]			; DI <- pointer to the next record
	stosw				; store record ID to buffer
	mov	al,00h			; PIT latch command, counter 0
	out	43h,al			; write to PIT control word register
	in	al,40h			; read counter 0 least significant byte
	mov	ah,al			; store it to AH
	in	al,40h			; read counter 0 most significant byte
	xchg	al,ah			; swap AL and AH to get proper byte order in AX
	stosw				; store timestamp to buffer
    es  cmp	di,[bx+2]		; compare the next record with the end of buffer
    	jne	.no_rollover		; not at the end yet
	mov	di,bx			; reset the pointer to the beginning of
	add	di,4			; the trace buffer

.no_rollover:
    es  mov	[bx],di			; store new pointer to the next record

.exit:
    	pop	es
	pop	di
	pop	bx
	ret
