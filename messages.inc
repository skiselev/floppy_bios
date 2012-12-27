;=========================================================================
; messages.inc - Messages printed by BIOS POST (Power On Self Test)
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

msg_copyright	db	0Dh, 0Ah
		db	"Sergey's Floppy BIOS, Version 1.0b1. "
		db	"Copyright (C) 2010 - 2012 Sergey Kiselev", 0Dh, 0Ah
		db	"Distributed under the terms of "
		db	"the GNU General Public License", 0Dh, 0Ah
msg_crlf	db      0Dh, 0Ah, 00h
msg_floppy	db	'Floppy disk drives: Drive 0: ', 00h
msg_floppy_2	db	'; Drive 1: ', 00h
msg_floppy_none	db	'none', 00h
msg_floppy_360	db	'360 KB, 5.25"', 00h
msg_floppy_1200	db	'1.2 MB, 5.25"', 00h
msg_floppy_720	db	'720 KB, 3.5"', 00h
msg_floppy_1440	db	'1.44 MB, 3.5"', 00h
msg_floppy_2880	db	'2.88 MB, 3.5"', 00h
msg_int13	db	'Extension BIOS installed on INT 13h', 0Dh, 0Ah, 00h
msg_int40	db	'Extension BIOS installed on INT 40h', 0Dh, 0Ah, 00h
tbl_floppy	dw	msg_floppy_none
		dw	msg_floppy_360
		dw	msg_floppy_1200
		dw	msg_floppy_720
		dw	msg_floppy_1440
		dw	msg_floppy_none
		dw	msg_floppy_2880
		dw	msg_floppy_none
