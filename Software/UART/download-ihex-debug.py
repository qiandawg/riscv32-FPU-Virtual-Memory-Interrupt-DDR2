#!/usr/bin/env python3
#run it using the command: python download-ihex.py COM3 prog.hex --crlf -v
__author__ = "Christopher Parish"
__version__ = "0.1"
__license__ = "MIT"

import argparse
from intelhex import IntelHex
import serial
import sys

class downloadihex:
    def __init__(self, use_crlf=False):
        self.ser = None
        self.accAddr = None
        self.accData = [None, None, None, None]
        self.use_crlf = use_crlf

    def sendUart(self, s):
        newline = "\r\n" if self.use_crlf else "\n"
        try:
            self.ser.reset_input_buffer()
            print(f"[UART SEND] {s}")
            self.ser.write(f"{s}{newline}".encode())
            rsp = self.ser.readline()
            decoded = rsp.decode(errors='ignore').strip()
            print(f"[UART RECV] {decoded}")

            if not decoded.startswith("OK"):
                print(f"[ERROR] Expected 'OK' but got: {decoded}")
                if rsp == b'':
                    print("[WARNING] Empty response. UART might be unplugged or FPGA unprogrammed.")
                sys.exit(1)
        except Exception as e:
            print(f"[EXCEPTION] UART send failed: {e}")
            sys.exit(1)

    def flushAcc(self):
        addr = f"a {self.accAddr:08x}"
        self.sendUart(addr)
        
        if all(d is None for d in self.accData):
            print("[BUG] accData is all None")
            sys.exit(1)

        valid_bytes = [b for b in self.accData if b is not None]
        hex_str = ''.join(f"{b:02x}" for b in valid_bytes).rjust(8, '0')
        data = f"w {hex_str}"
        self.sendUart(data)

        self.accData = [None, None, None, None]

    def program(self, f):
        ih = IntelHex(f)
        addresses = ih.addresses()
        if not addresses:
            print(f"[ERROR] No data in IHEX file: {f}")
            sys.exit(1)

        self.accAddr = addresses[0]
        self.accData[0] = ih[self.accAddr]
        accCtr = 1
        lastAddr = self.accAddr

        for i in addresses:
            if i == self.accAddr:
                continue
            if i != lastAddr + 1 or accCtr == 4:
                self.flushAcc()
                self.accAddr = i
                accCtr = 0
            self.accData[accCtr] = ih[self.accAddr + accCtr]
            accCtr += 1
            lastAddr = i

        self.flushAcc()

    def main(self, args):
        try:
            self.ser = serial.Serial(args.device, args.baud, timeout=2)
        except serial.SerialException as e:
            print(f"[ERROR] Could not open UART device {args.device}: {e}")
            print("👉 Try checking device name or re-installing USB/UART drivers.")
            sys.exit(1)

        self.ser.write("\n".encode())
        self.ser.readline()

        self.sendUart("h")
        self.sendUart("i")
        self.program(args.file)

        if args.dmemfile:
            self.sendUart("d")
            self.program(args.dmemfile)

        self.sendUart("e")
        self.sendUart("g")
        self.ser.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="MIPS FPGA IHEX Loader")

    parser.add_argument("device", help="Serial device (e.g., COM3 or /dev/ttyUSB0)")
    parser.add_argument("file", help="IMEM IHEX file")
    parser.add_argument("dmemfile", nargs="?", help="Optional DMEM IHEX file")
    parser.add_argument("-b", "--baud", type=int, default=115200, help="Baud rate (default: 115200)")
    parser.add_argument("--crlf", action="store_true", help="Use CRLF (\\r\\n) for UART newline (Windows 11 fix?)")
    parser.add_argument("-v", "--verbose", action="count", default=0, help="Verbose output")
    parser.add_argument("--version", action="version", version=f"%(prog)s v{__version__}")

    args = parser.parse_args()

    dlhex = downloadihex(use_crlf=args.crlf)
    dlhex.main(args)