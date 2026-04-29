#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

uint32_t reverse_endian(uint32_t value) {
    return ((value >> 24) & 0x000000FF) |
           ((value >>  8) & 0x0000FF00) |
           ((value <<  8) & 0x00FF0000) |
           ((value << 24) & 0xFF000000);
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <input file> <output file>\n", argv[0]);
        return 1;
    }

    FILE *input = fopen(argv[1], "r");
    if (!input) {
        perror("Error opening input file");
        return 1;
    }

    FILE *output = fopen(argv[2], "w");
    if (!output) {
        perror("Error opening output file");
        fclose(input);
        return 1;
    }

    char line[16];  // Extra space to handle potential newline characters
    uint32_t value;

    while (fgets(line, sizeof(line), input)) {
        // Remove newline character if present
        line[strcspn(line, "\r\n")] = '\0';

        // Check if the line is empty (to prevent extra 00000000 lines)
        if (strlen(line) == 0) continue;

        // Convert ASCII hex to integer
        value = (uint32_t)strtoul(line, NULL, 16);

        // Reverse endian
        value = reverse_endian(value);

        // Print reversed hex value (one per line)
        fprintf(output, "%08X\n", value);
    }

    fclose(input);
    fclose(output);

    return 0;
}
