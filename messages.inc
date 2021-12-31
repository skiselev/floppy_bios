;=========================================================================
; messages.inc - Messages printed by Multi-Floppy BIOS Extension
;-------------------------------------------------------------------------
;
; Copyright (C) 2011 - 2021 Sergey Kiselev.
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
		db	"Multi-Floppy BIOS, Version "
		db	VERSION
		db	". "
		db	"Copyright (C) 2010 - 2021 Sergey Kiselev", 0Dh, 0Ah
		db	"Distributed under the terms of "
		db	"the GNU General Public License", 0Dh, 0Ah
msg_crlf	db      0Dh, 0Ah, 00h
msg_fdc		db	'FDC ', 00h
msg_drive	db	'Drive ', 00h
msg_irq		db	', IRQ', 00h
msg_drq		db	', DRQ', 00h
msg_at		db	' at ', 00h
msg_on_fdc	db	' on FDC ', 00h
msg_semicolon	db	'; ', 00h
msg_colon	db	': ', 00h
msg_comma_hash	db	', #', 00h
msg_floppy_none	db	'none', 00h
msg_floppy_360	db	'360 KB, 5.25"', 00h
msg_floppy_1200	db	'1.2 MB, 5.25"', 00h
msg_floppy_720	db	'720 KB,  3.5"', 00h
msg_floppy_1440	db	'1.44 MB, 3.5"', 00h
msg_floppy_2880	db	'2.88 MB, 3.5"', 00h
msg_no_drives	db	'No floppy drives configured, BIOS extension is not installed', 0Dh, 0Ah, 00h
msg_int13	db	'BIOS extension is installed on INT 13', 0Dh, 0Ah, 00h
msg_int40	db	'BIOS extension is installed on INT 40', 0Dh, 0Ah, 00h
tbl_floppy	dw	msg_floppy_none
		dw	msg_floppy_360
		dw	msg_floppy_1200
		dw	msg_floppy_720
		dw	msg_floppy_1440
		dw	msg_floppy_none
		dw	msg_floppy_2880
		dw	msg_floppy_none
msg_config	db	'Press F2 to run the Multi-Floppy BIOS configuration utility...', 00h
msg_cfg_welcome	db	'Welcome to the Multi-Floppy BIOS configuration utility.', 00h
msg_cfg_help	db	0Dh, 0Ah, 'Multi-Floppy BIOS configuration help:', 0Dh, 0Ah
		db	'a - Add a floppy drive', 0Dh, 0Ah
		db	'd - Delete a floppy drive', 0Dh, 0Ah
		db	'e - Enable and configure the secondary floppy disk controller', 0Dh, 0Ah
		db	'f - Disable the secondary floppy disk controller', 0Dh, 0Ah
		db	'p - Print current configuration settings', 0Dh, 0Ah
		db	'w - Write setting to the EEPROM and exit', 0Dh, 0Ah
		db	'q - Exit without saving settings', 0Dh, 0Ah
		db	'h - Print this help message', 00h
msg_cfg_prompt	db	0Dh, 0Ah, "Enter command ('h' for help): ", 00h
msg_cfg_drv_many db	0Dh, 0Ah, 'Error: Cannot add a new logical drive, all drive numbers are allocated.', 00h
msg_cfg_drv_del	db	0Dh, 0Ah, 'Enter logical drive number to delete (0-', 00h
msg_cfg_no_drv	db	0Dh, 0Ah, 'Error: No drives, nothing to delete.', 00h
msg_cfg_fdc_irq	db	0Dh, 0Ah, 'Enter IRQ number for the secondary FDC (2-7'
msg_close_bracket db	'): ', 00h
msg_cfg_fdc_dma	db	0Dh, 0Ah, 'Enter DMA channel number for the secondary FDC (1-3): ', 00h
msg_cfg_fdc_del	db	0Dh, 0Ah, 'Warning: Disabling secondary FDC will delete all drives on it. Continue (y/n)? ', 00h
msg_cfg_fdc_alr	db	0Dh, 0Ah, 'Error: The secondary FDC is already disabled.', 00h
msg_cfg_save	db	0Dh, 0Ah, 'Saving the configuration to the EEPROM. '
		db	'Please do not reboot the computer.', 0Dh, 0Ah, 00h
msg_cfg_saved	db	0Dh, 0Ah, 'Configuration saved successfully. The new configuration is:', 0Dh, 0Ah, 00h
msg_cfg_unk_id	db	0Dh, 0Ah, 'Unknown Flash ROM ID: ', 00h
msg_cfg_failed	db	0Dh, 0Ah, 'Failed to write to the EEPROM. '
		db	'Make sure EEPROM write protection is disabled.', 0Dh, 0Ah
		db	'Configuration data dump:', 00h
msg_double_space db	' '
msg_space	db	' ', 00h
msg_cfg_exit	db	0Dh, 0AH, 'Exiting without saving settings.', 0Dh, 0Ah, 00h
msg_cfg_fdc_num	db	0Dh, 0Ah, 'Enter the FDC number (1:Primary FDC, 2:Secondary FDC): ', 00h
msg_cfg_fdc_add	db	0Dh, 0Ah, 'Adding a drive on the ', 00h
msg_cfg_fdc_pri	db	'primary FDC.', 00h
msg_cfg_fdc_sec	db	'secondary FDC.', 00h
msg_cfg_phys_num db	0Dh, 0Ah, 'Enter the physical drive number (0-3): ', 00h
msg_cfg_phys_alr db	0Dh, 0Ah, 'Error: Physical drive already exists.', 00h
msg_cfg_log_num	db	0Dh, 0Ah, 'Enter the logical drive number (0-', 00h
msg_cfg_type	db	0Dh, 0Ah, 'Enter the drive type (1:360 KB, 2:1.2 MB, 3:720 KB, 4:1.44 MB, 6:2.88 MB): ', 00h
msg_boot_failed db	'Boot failed, error ', 00h
msg_boot_retry	db	'. Press F for the original IPL or any key to try again...', 0Dh, 0Ah, 00h
