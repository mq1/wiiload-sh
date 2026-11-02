# wiiload.sh

A simple and portable wiiload implementation in POSIX sh.
Automatically compresses .dol and .elf files.

## Usage

```sh
# with netcat (any unix shell)
./wiiload.sh <input file> | nc <host> 4299

# alternatively in bash
./wiiload.sh <input file> > /dev/tcp/<host>/4299
```

