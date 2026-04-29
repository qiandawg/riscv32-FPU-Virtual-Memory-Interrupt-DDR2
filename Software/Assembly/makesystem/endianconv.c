#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void swap_endian(char *hex) {
    char temp[9];  // 8 hex digits + null terminator
    temp[8] = '\0';

    // Swap bytes: AABBCCDD -> DDCCBBAA
    temp[0] = hex[6]; temp[1] = hex[7];  // Byte 4
    temp[2] = hex[4]; temp[3] = hex[5];  // Byte 3
    temp[4] = hex[2]; temp[5] = hex[3];  // Byte 2
    temp[6] = hex[0]; temp[7] = hex[1];  // Byte 1

    strcpy(hex, temp);  // Copy back
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Usage: %s input.txt output.txt\n", argv[0]);
        return 1;
    }

    FILE *fin = fopen(argv[1], "r");
    FILE *fout = fopen(argv[2], "w");

    if (!fin || !fout) {
        printf("Error opening file.\n");
        return 1;
    }

    char line[16];  // Max length for 32-bit hex word + newline

    while (fgets(line, sizeof(line), fin)) {
        if (strlen(line) < 8) continue;  // Ignore short lines

        line[8] = '\0';  // Trim any newline
        swap_endian(line);  
        fprintf(fout, "%s\n", line);
    }

    fclose(fin);
    fclose(fout);

    printf("Conversion complete!\n");
    return 0;
}
