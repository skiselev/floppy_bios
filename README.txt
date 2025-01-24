README file for Multi-Floppy BIOS Extension
*******************************************

General Information
===================

The Multi-Floppy BIOS Extension provides support for up to 8 floppy
drives connected to two floppy disk controllers (FDCs). It supports any
combination of standard IBM PC/XT/AT and PS/2 floppy drives, with disk sizes
from 160 KB to 2.88 MB.

Configuration Utility
---------------------

The BIOS extension includes a built-in configuration utility that can be
invoked by pressing F2 during the boot (BIOS POST). The utility allows setting
up the floppy drives and FDCs configuration, and saving it to the EEPROM
(provided that the BIOS extension is stored in an EEPROM and the write is
enabled). If the ROM is cannot be programmed in system (e.g. write protected,
or an EPROM chip is used instead of EEPROM), the configuration utility provides
a dump of the configuration data, so the user can program it manually.
Please refer to the Implementation Notes section for detailed information on
the configuration data structure.

Release Notes
=============

Version 2.7
-----------
- Implement delay subroutines that work on both AT and PC/XT systems using
  the PIT counter, eliminating the need for separate AT and XT routines

Version 2.6
-----------
- Fix performance issue when reading consecutive sectors
- Simply access to the secondary FDC variables, use DS=0000h

Version 2.5
-----------
- Automatically detect if the system supports AT delays
- Enable IRQ and DMA channel sharing between primary and secondary FDCs
- Return to configuration utility main menu when ESC key is pressed

Version 2.4
-----------
- Add IPL method and delays type configuration options in configuration utility

Version 2.3
-----------
- Add support for storing configuration in 128 KiB Flash ROMs
- Run configuration utility from RAM

Version 2.2
-----------
- Fix garbage output on CGA displays with IBM BIOS
- Make BIOS extension code size equal 8 KiB, including the configuration area.
  This mitigates issues with original IBM BIOS and XT BIOS by Anonymous, that
  expect BIOS extension size to be a multiply of 2 KiB.
- Reinstall interrupt vectors on INT 19h.

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
offset 1FC0h.

Here is the location and the purpose of the configuration data:

Offset 1FC0h, size 1 bytes:
Checksum correction byte. Value of this byte is negative of the sum of the
rest of bytes in 1F81h - 1FFFh range, so that the sum of the 1F80h - 1FFFh
range equals zero.

Offset 1FC1h, size 32 bytes:
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

Offset 1FE1h, size 8 bytes:
FDC configuration, 2 entries (primary FDC and secondary FDC), 4 bytes each:
	word 0 - FDC base address.
		Normally 3F0h for the primary FDC and 370h for the secondary FDC
	byte 2 - FDC interrupt (IRQ) number.
		Normally 6 for the primary FDC
	byte 3 - FDC DMA channel number.
		Normally 2 for the primary FDC

Offset 1FE9, size 2 bytes:
Configuration prompt (Press F2...) delay in 55 ms units
	word - default: 55 (approximately 3 seconds)

Offset 1FEB, size 1 byte:
Configuration flags
	bit 0 - 1: Enable IRQ and DMA sharing; 0: Disable IRQ and DMA sharing
		Set automatically when configuring the secondary FDC
	bit 1 - Display configuration prompt during extension ROM initialization
		default: 0 - Don't display
	bit 2 - Display configuration prompt on boot (INT 19h)
		default: 1 - Display
	bit 3 - Use built-in Floppy BIOS IPL functionality
		default: 0 - Don't use built-in IPL, use System BIOS IPL
	bits 4 - 7 - Reserved, set to 0
		
Offset 1FEC, size 3 bytes:
Code to run relocated timer (IRQ0) handler. The second byte is also used to
determine what interrupt number the default INT 08h handler should be
relocated to. This is only used in configurations with two FDCs.
	byte 0 - default: 0CDh (INT opcode)
	byte 1 - default: 0AFh (interrupt 0AFh)
	byte 2 - default: 0CFh (IRET opcode)

Offset 1FEF, size 3 bytes;
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

- Make the ROM PnP specs compliant?
