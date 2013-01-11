# Makefile - GNU Makefile
# 
# Copyright (C) 2011 Sergey Kiselev.
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

SOURCES=floppy_bios.asm floppy1.inc floppy2.inc messages.inc config.inc

all:	floppy_bios.bin

floppy_bios.bin: $(SOURCES) fix_checksum
	nasm -O9 -f bin -o floppy_bios.bin -l floppy_bios.lst floppy_bios.asm
	./fix_checksum 1DFF floppy_bios.bin floppy_bios.bin

fix_checksum:	fix_checksum.c
	gcc -o fix_checksum fix_checksum.c

clean:
	rm -f floppy_bios.bin
