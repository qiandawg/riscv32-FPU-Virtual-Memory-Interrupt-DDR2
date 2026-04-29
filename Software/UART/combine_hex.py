import sys

def combine_hex_files(file1, file2, output_file):
    with open(file1, 'r') as f1, open(file2, 'r') as f2, open(output_file, 'w') as fout:
        # Define a function to write lines with proper handling of addresses
        def write_hex_lines(f_source):
            for line in f_source:
                # Adjust addresses if needed
                fout.write(line)

        write_hex_lines(f1)
        write_hex_lines(f2)
        fout.write(':00000001FF\n')  # End of file record

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("Usage: python combine_hex.py <file1.hex> <file2.hex> <output.hex>")
    else:
        combine_hex_files(sys.argv[1], sys.argv[2], sys.argv[3])