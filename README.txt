
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

Additional storage required
---------------------------

fdc_media_state_addr:
	4 bytes:	media state for 4 drives on the secondary FDC

fdc_cylinder_addr:
	6 bytes:	current cylinder for 4 drives on the secondary FDC
			followed by 2 drives (2 and 3) on the primary FDC

fdc_last_rate:
	bits 7 - 6:	last data rate set for the primary FDC (AT compatible)
	bits 5 - 4:	last data rate set for the secondary FDC (ext. specific)
	bits 3 - 0:	calibrated bits for the 4 drives on the secondary FDC

TODO
====

- XI 8088 bios - modify print* procedures (copy from floppy BIOS: for INT 10/fn0E BH needs to be set to 0 - page number)

- debug format issue

- test with checkit

- Detect / Initialize FDCs during BIOS initialization
	- initialize FDC controllers on initialization (display a warning message on timeout/controller not present)

- Make the ROM PnP specs compliant?
