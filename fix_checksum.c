/*************************************************************************
 * fix_checksum.c - Fix BIOS extension ROM checksum
 *
 * Copyright (C) 2011 - 2013 Sergey Kiselev.
 * Provided for hobbyist use on the
 *	ISA Floppy Disk and Serial Controller and XT-FDC cards.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *************************************************************************/

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
	struct stat *st;
	char *rom_buf;
	int file_size, rom_size, area, area_start, area_end, area_sum, i, in, out;
	unsigned char checksum;

	if (argc < 6 || argc % 3 != 0) {
		fprintf(stderr, "Usage: %s <input_file> <output_file>\n",argv[0]);
		fprintf(stderr, "          <area1_start> <area1_end> <area1_sumaddr>\n");
		fprintf(stderr, "          [<area2_start> <area2_end> <area2_sumaddr>] ..\n\n");
		fprintf(stderr, "<input_file>  - File name of the input image file.\n");
		fprintf(stderr, "<output_file> - File name of the output image file.\n");
		fprintf(stderr, "<areaX_start> - Hexadecimal start address of a ROM area X\n");
		fprintf(stderr, "<areaX_end>   - Hexadecimal end address of a ROM area X\n");
		fprintf(stderr, "<areaX_sum>   - Hexadecimal address of the byte to be changed to\n");
		fprintf(stderr, "                correct the checksum for area X.\n");
		exit(1);
	}

	st = malloc(sizeof(struct stat));
	
	if (stat(argv[1], st) == -1) {
		fprintf(stderr, "Failed to stat '%s'\n", argv[1]);
		exit(2);
	}

	file_size = st->st_size;

	printf("DEBUG: ROM file size is %d\n", file_size);

	if (file_size < 5) {
		fprintf(stderr, "File is too short\n");
		exit(2);
	}

	rom_buf = malloc(file_size);

	if ((in = open(argv[1], O_RDONLY)) == -1) {
		fprintf(stderr, "Failed to open '%s'\n", argv[1]);
		exit(2);
	}

	if (read(in, rom_buf, file_size) != file_size) {
		fprintf(stderr, "Short read\n");
		exit(2);
	}

	close(in);

	rom_size = rom_buf[2] * 512;

	printf("DEBUG: ROM code size is %d\n", rom_size);

	if (rom_size > file_size) {
		fprintf(stderr, "ROM code size is bigger than ROM file size\n");
		exit(2);
	}

	for (area = 1; area < argc / 3; area++) {

		sscanf(argv[area*3], "%x", &area_start);
		sscanf(argv[area*3+1], "%x", &area_end);
		sscanf(argv[area*3+2], "%x", &area_sum);

		if (area_start > area_end) {
			fprintf(stderr, "Area %d start address %04X is bigger than end address %04X\n", area, area_start, area_end);
			exit(1);
		}

		if (area_sum < area_start || area_sum > area_end) {
			fprintf(stderr, "Area %d checksum address %04X is not within the area %04X - %04X\n", area, area_sum, area_start, area_end);
			exit(1);
		}

		checksum = 0;
		for (i = area_start; i <= area_end; i++) {
			if (i != area_sum) checksum += rom_buf[i];
		}

		printf("DEBUG: Area %d: Original checksum: 0x%02X\n", area, checksum);

		rom_buf[area_sum] = -checksum;

		checksum = 0;
		for (i = area_start; i <= area_end; i++) checksum += rom_buf[i];

		printf("DEBUG: Area %d: Fixed checksum: 0x%02X\n", area, checksum);
	}

	if ((out = creat(argv[2], 0777)) == -1) {
		fprintf(stderr, "Failed to open '%s'\n", argv[2]);
		exit(3);
	}
	if (write(out, rom_buf, file_size) != file_size) {
		fprintf(stderr, "Short write\n");
		exit(3);
	}
	close(out);

	return 0;
}
