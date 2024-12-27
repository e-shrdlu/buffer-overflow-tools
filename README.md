# Buffer Overflow Tools
The two scripts in here, egg_cannon.bash and hen.py work together to help automate the exploitation of a buffer overflow.
`hen.py` creates an egg (because hens lay eggs, get it?), based on paremeters like size of the buffer, return address, etc.
`egg_cannon.bash` (because it shoots out a lot of eggs and sounds fun) takes parameters like the stack size and location, then calls `hen.py` with many different return addresses, and on success, creates a new user with sudo permissions (assuming exploitable service has authority to do that), as well as outputting which parameters were successful.

I've had to change and move things around, but I've been able to use this script to exploit a buffer overflow on an ASLR-enabled target, once with a very small buffer (about 8 bytes), 64-bit and 32-bit targetes, and others.

## Usage
you're going to need to modify the settings in both `hen.py` and `egg_cannon.bash`. Settings in `hen.py` deal with like, the shellcode, the architecture, the actual exploitation of the buffer overflow. You could just use `hen.py` and do the rest manually if you want.

`egg_cannon.bash` is more of a tool that will automatically try using `hen.py` a bunch of different ways. Really, its a just few for-loops. But the settings in there are going to be like, which stack addresses to try, as well as what parameters to pass to `hen.py`, which you can use to deal with stuff like, a small buffer meaning you need to re-arrange your egg, among other things.

But, overall, just remember this is a starting point. It's not going to do the exploit for you. You're going to need to mess around with the script and settings, move things around, and shape it to fit your specific use-case
