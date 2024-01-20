#!/usr/bin/python3
import sys
import argparse

parser = argparse.ArgumentParser(prog='gendatainit')
parser.add_argument('in_file',  type=argparse.FileType('rb'))
parser.add_argument('out_file', type=argparse.FileType('w'))
parser.add_argument('--offset', help='prepare \'dat\' file for simulation', action='store_true')
args = parser.parse_args()

n=0
if (args.offset):
    while n<0x800:
        dword00 = '00'
        dword10 = '00'
        dword20 = '00'
        dword30 = '00'
        args.out_file.write(dword30)
        args.out_file.write(dword20)
        args.out_file.write(dword10)
        args.out_file.write(dword00)
        args.out_file.write('\n')
        n = n+4
while True:
    dword0 = args.in_file.read(1)
    dword1 = args.in_file.read(1)
    dword2 = args.in_file.read(1)
    dword3 = args.in_file.read(1)
    if (dword3 == b''):
        break
    else:
        args.out_file.write(dword3.hex())
        args.out_file.write(dword2.hex())
        args.out_file.write(dword1.hex())
        args.out_file.write(dword0.hex())
        args.out_file.write('\n')

args.out_file.close()
args.in_file.close()
