import sys

def parse_ihex_line(line):
    if not line.startswith(':'):
        return None
    byte_count = int(line[1:3], 16)
    address = int(line[3:7], 16)
    record_type = int(line[7:9], 16)
    data = line[9:9 + byte_count * 2]
    checksum = int(line[9 + byte_count * 2:11 + byte_count * 2], 16)
    return byte_count, address, record_type, data, checksum

def swap_endian_32bit(data):
    swapped = ''
    for i in range(0, len(data), 8):
        word = data[i:i+8]
        if len(word) == 8:
            swapped += word[6:8] + word[4:6] + word[2:4] + word[0:2]
    return swapped

def calculate_checksum(byte_count, address, record_type, data_bytes):
    total = byte_count + (address >> 8) + (address & 0xFF) + record_type
    total += sum(data_bytes)
    return ((~total + 1) & 0xFF)

def format_ihex_line(byte_count, address, record_type, data):
    data_bytes = [int(data[i:i+2], 16) for i in range(0, len(data), 2)]
    checksum = calculate_checksum(byte_count, address, record_type, data_bytes)
    return f":{byte_count:02X}{address:04X}{record_type:02X}{data}{checksum:02X}"

def convert_ihex_endian(input_file, output_file):
    with open(input_file, 'r') as f:
        lines = f.readlines()

    converted_lines = []
    for line in lines:
        parsed = parse_ihex_line(line.strip())
        if parsed is None:
            continue
        byte_count, address, record_type, data, checksum = parsed
        if record_type == 0:
            swapped_data = swap_endian_32bit(data)
            new_line = format_ihex_line(byte_count, address, record_type, swapped_data)
            converted_lines.append(new_line)
        else:
            converted_lines.append(line.strip())

    with open(output_file, 'w') as f:
        for line in converted_lines:
            f.write(line + '\n')

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_ihex_endian.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    convert_ihex_endian(input_file, output_file)
    print(f"Converted file saved as {output_file}")
