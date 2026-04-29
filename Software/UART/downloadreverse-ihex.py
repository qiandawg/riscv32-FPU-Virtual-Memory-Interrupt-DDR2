#!/usr/bin/env python3

__author__ = "Christopher Parish"
__version__ = "0.1"
__license__ = "MIT"

import argparse
from intelhex import IntelHex
import serial

class downloadihex:
    def __init__(self):
        self.ser = None
        self.accAddr = None
        self.accData = [None, None, None, None]

    def sendUart(self, s):
        self.ser.flushInput()
        self.ser.write(f"{s}\n".encode())
        print(s)
        rsp = self.ser.readline()
        if not rsp.decode().startswith("OK"):
            print(f"ERROR: Expected OK from debug UART, got {rsp}")
            if rsp == b'':
                print("Is the UART unplugged/FPGA unprogrammed?")
            exit(1)

    def flushAcc(self):
        addr = f"a {self.accAddr:08x}"
        self.sendUart(addr)

        if self.accData[0] is None and self.accData[1] is None and self.accData[2] is None and self.accData[3] is None:
            print("accData is all None, probably a bug")
            exit(1)
        elif self.accData[1] is None and self.accData[2] is None and self.accData[3] is None:
            data = f"w 000000{self.accData[0]:02x}"
            self.sendUart(data)
        elif self.accData[2] is None and self.accData[3] is None:
            data = f"w 0000{self.accData[0]:02x}{self.accData[1]:02x}"
            self.sendUart(data)
        elif self.accData[3] is None:
            data = f"w 00{self.accData[0]:02x}{self.accData[1]:02x}{self.accData[2]:02x}"
            self.sendUart(data)
        else:
            # Here is the modification for reverse endian
            reversed_data = self.accData[::-1]  # Reverse the list
            data = f"w {reversed_data[0]:02x}{reversed_data[1]:02x}{reversed_data[2]:02x}{reversed_data[3]:02x}"
            self.sendUart(data)

        self.accData = [None, None, None, None]

    def program(self, f):
        ih = IntelHex(f)

        self.accAddr = ih.addresses()[0]
        self.accData = [ih[self.accAddr], None, None, None]
        accCtr = 1
        lastAddr = self.accAddr

        for i in ih.addresses():
            # Skip duplicated Addresses / the first address
            if i == self.accAddr:
                continue

            # If we have a discontinuous address jump
            if i != lastAddr + 1:
                self.flushAcc()
                self.accAddr = i
                accCtr = 0
            # Or we have a full accumulator
            elif accCtr == 4:
                self.flushAcc()
                self.accAddr = i
                accCtr = 0

            self.accData[accCtr] = ih[self.accAddr + accCtr]
            accCtr += 1
            lastAddr = i

        self.flushAcc()
        accCtr = 0

    def main(self, args):
        self.ser = serial.Serial(args.device, args.baud, timeout=1)

        self.ser.write("\n".encode())
        self.ser.readline()

        self.sendUart("h")

        self.sendUart("i")

        self.program(args.file)

        if args.dmemfile is not None:
            self.sendUart("d")
            self.program(args.dmemfile)

        self.sendUart("e")

        self.sendUart("g")

        self.ser.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("device", help="Device (e.g. /dev/ttyUSB0)")
    parser.add_argument("file", help="Unified/IMEM IHEX file")
    parser.add_argument("dmemfile", nargs="?", help="DMEM IHEX file")

    parser.add_argument("-b", "--baud", action="store", default=115200)

    # Optional verbosity counter (e.g., -v, -vv, -vvv, etc.)
    parser.add_argument(
        "-v",
        "--verbose",
        action="count",
        default=0,
        help="Verbosity (-v, -vv, etc)")

    # Specify output of "--version"
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s (version {version})".format(version=__version__))

    args = parser.parse_args()

    dlhex = downloadihex()
    dlhex.main(args)