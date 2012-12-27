/* fix_checksum.c - Fix extension ROM checksum */

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#define CORRECTION_BYTE 5

int main(int argc, char *argv[])
{
	struct stat *st;
	char *rom_buf;
	int file_size, rom_size, i, in, out;
	unsigned char checksum;

	if (argc != 3) {
		fprintf(stderr, "Usage: %s <input_file> <output_file>\n", argv[0]);
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

	checksum = 0;
	for (i = 0; i < rom_size; i++) {
		if (i != CORRECTION_BYTE) checksum += rom_buf[i];
	}

	printf("DEBUG: Original checksum: 0x%02X\n", checksum);

	rom_buf[CORRECTION_BYTE] = -checksum;

	checksum = 0;
	for (i = 0; i < rom_size; i++) checksum += rom_buf[i];

	printf("DEBUG: Fixed checksum: 0x%02X\n", checksum);

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
