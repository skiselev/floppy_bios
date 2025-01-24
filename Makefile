# Makefile - GNU Makefile
# 
# Copyright (C) 2010 - 2025 Sergey Kiselev.
# Provided for hobbyist use on the Sergey's XT board.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY# without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

SOURCES=floppy_bios.asm floppy1.inc floppy2.inc flash.inc messages.inc config.inc

all:	floppy_bios.bin

floppy_bios.bin: $(SOURCES) fix_checksum
	nasm -O9 -f bin -o floppy_bios.bin -l floppy_bios.lst floppy_bios.asm
	./fix_checksum floppy_bios.bin floppy_bios.bin 0 1FBF 1FBF 1FC0 1FFF 1FC0

fix_checksum:	fix_checksum.c
	gcc -O0 -g -o fix_checksum fix_checksum.c

clean:
	rm -f floppy_bios.bin
