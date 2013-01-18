README file for Multi-Floppy BIOS Extension
*******************************************

General Information
===================

The Multi-Floppy Floppy BIOS Extension provides support for up to 8 floppy
drives connected to two floppy disk controllers (FDCs). It supports any
combination of standard IBM PC/XT/AT and PS/2 floppy drives, with disk sizes
from 180 KB to 2.88 MB.

Configuration Utility
---------------------

The BIOS extension has a built-in configuration utility that could be
invoked by pressing F2 during the boot (BIOS POST). The utility allows setting
up the floppy drives and FDCs configuration, and saving it to the EEPROM
(provided that the BIOS extension is in an EEPROM and the write is enabled).
The ROM is cannot be programmed in system (e.g. write protected, or an EPROM
chip is used instead of EEPROM), the configuration utility provides a dump
of the configuration data, so the user can program it manually.
Please refer to the Implementation Notes section for detailed information on
the configuration data structure.

Secondary FDC Configuration
---------------------------

Currently the BIOS extension does not support DMA channel and IRQ sharing with
the primary FDC. Therefore the secondary FDC must not use DMA channel 2 and
IRQ 6. 


Release Notes
=============

Version 2.0
-----------

- Support for two FDCs with up to 8 drives
- Built-in EEPROM configuration utility

Version 1.0b1
-------------

- Mostly a straight forward copy of the floppy functions from Xi 8088 BIOS


Implementation Notes
====================

Additional storage for 8 drives support
---------------------------------------

The Multi-Floppy BIOS extension uses 11 bytes in addition to standard BIOS
data area variables for storing status information for the secondary FDC and
drives from 3 to 8.

Here is the list of these variables and their default location:

fdc_media_state_addr:
- Purpose:		media state for 4 drives on the secondary FDC
- Size:			4 bytes
- Default location:	0000:02C0 (interrupt vector 0B0h)

fdc_cylinder_addr:
- Purpose:		current cylinder for 4 drives on the secondary FDC
			followed by 2 drives (2 and 3) on the primary FDC
- Size:			6 bytes
- Default location:	0000:02C4 (interrupt vectors 0B1h and 0B2h)

fdc_motor_state_addr:
- Purpose:		mode (read/write), motor state, and selected drive
			for the secondary FDC
- Size:			1 byte
- Default location:	0000:02CA (interrupt vector 0B2h)

In addition the format of the 'last rate' BIOS variable (0040h:008Bh) is
redifined as follows

bits 7 - 6:	last data rate set for the primary FDC (same as on an AT)
bits 5 - 4:	not used
bits 3 - 0:	calibrated bits for the 4 drives on the secondary FDC


Configuration Data Structure
----------------------------

The configuration data is stored in the extension BIOS ROM starting from
offset 1E00h.

Here is the location and the purpose of the configuration data:

Offset 1E00h, size 32 bytes:
Floppy drive configuration, 8 entries, 4 bytes each:
	byte 0 - drive type:
		0 - drive not present
		1 - 360 KB, 5.25"
		2 - 1.2 MB, 5.25"
		3 - 720 KB, 3.5"
		4 - 1.44 MB, 3.5"
		6 - 2.88 MB, 3.5"
	byte 1 - FDC number: 0 - Primary FDC; 1 - Secondary FDC
	byte 2 - physical drive number, from 0 to 3
	byte 3 - reserved, must be set to 0
Notes:
- Drive entries must be populated consecutively, without any holes (drive not
  present entries)
- When using the standard IBM PC twisted floppy cable, the drive after the
  twist is the physical drive 0, and the drive before the twist is the physical
  drive 1.

Offset 1E20h, size 8 bytes:
FDC configuration, 2 entries (primary FDC and secondary FDC), 4 bytes each:
	word 0 - FDC base address.
		Normally 3F0h for the primary FDC and 370h for the secondary FDC
	byte 2 - FDC interrupt (IRQ) number.
		Normally 6 for the primary FDC
	byte 3 - FDC DMA channel number.
		Normally 2 for the primary FDC

Offset 1E28h, size 4 bytes:
Pointer to floppy drive media state for drives 4-7 variables array.
	word 0 - offset; default: 02C0h
	word 2 - segment; default; 0000h

Offset 1E2Ch, size 4 bytes:
Pointer to current cylinder for drives 2-7 variables array:
	word 0 - offset; default: 02C4h
	word 2 - segment; default: 0000h

Offset 1E30h, size 4 bytes:
Pointer to mode, motor state, and selected drive for the secondary FDC variable:
	word 0 - offset; default: 02CAh
	word 2 - segment; default: 0000h

Offset 1E34, size 2 bytes:
Configuration prompt (Press F2...) delay in 55 ms units
	word - default: 55 (approximately 3 seconds)

Offset 1E36, size 1 byte:
Flag indicating whenever AT delay subroutines should be used. AT delay
subroutines provide much more percise timing, but don't work on PC/XT class
machines.
	byte - default: 0 - use XT delays; 1 - use AT delays

Offset 1E37, size 3 bytes:
Code to run relocated timer (IRQ0) handler. The second byte is also used to
determine what interrupt number the default INT 08h handler should be
relocated to. This is only used in configurations with two FDCs.
	byte 0 - default: 0CDh (INT opcode)
	byte 1 - default: 0AFh (interrupt 0AFh)
	byte 2 - default: 0CFh (IRET opcode)

Offset 1E3A, size 3 bytes;
Code to run relocated INT 19h (boot) handler. The second byte is also used to
determine what interrupt number the default INT 19h handler should be
relocated to.
	byte 0 - default: 0CDh (INT opcode)
	byte 1 - default: 0AEh (interrupt 0AEh)
	byte 2 - default: 0CFh (IRET opcode)


Enabling SDP (Software Data Protection) feature
-----------------------------------------------

Atmel AT28C64B EEPROMs support the SDP feature which allows disabling
EEPROM writes using a special sequence. It is recommended to enable this
feature if you have this EEPROM type, as it will prevent accidential EEPROM
modifications, while allowing the built-in configuration utility to modify
the configuration without changing "EEPROM write protect" switch / jumper
setting.

Here is an example of enabling SDP feature using the DOS DEBUG command. Note
that the first command (mov ax,e000) needs to be updated to reflect the segment
address of the EEPROM, according to the configuration of the ISA FDC card.

C:\>debug
-a
151D:0100 mov ax,e000
151D:0103 mov ds,ax
151D:0105 mov byte [1555],aa
151D:010A mov byte [0aaa],55
151D:010F mov byte [1555],a0
151D:0114 xor cx,cx
151D:0116 loop 116
151D:0118 int 20
-g

Note: This command sequence is only supported on Atmel AT28C64B EEPROM, it
won't work on other EEPROMs and will corrupt the EEPROM content instead.

TODO
====

- Better check for HDD BIOS presence? (e.g. call INT 13h AH=15h)

- Detect and initialize FDC controllers on initialization. Display a warning
  message on timeout/controller not present.

- Implement IRQ/DRQ sharing for primary FDC and secondary FDC.

- Make the ROM PnP specs compliant?
