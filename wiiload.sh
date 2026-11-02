#!/bin/sh
set -eu

# Compress file with zlib -9 using either perl or python
compress_zlib() {
    if command -v perl >/dev/null 2>&1 && perl -MCompress::Zlib -e 1 >/dev/null 2>&1; then
        perl -MCompress::Zlib -e 'undef $/; print compress(<>, 9)'
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import sys, zlib; sys.stdout.buffer.write(zlib.compress(sys.stdin.buffer.read(), 9))"
    else
        return 1
    fi
}

check_input() {
    if [ ! -f "$1" ]; then
        echo "File not found: $1" >&2
        exit 1
    fi

    if [ ! -r "$1" ]; then
        echo "File is not readable: $1" >&2
        exit 1
    fi

    case "$1" in
    *.zip | *.ZIP | *.dol | *.DOL | *.elf | *.ELF)
        ;;
    *)
        echo "Unsupported file type: $1" >&2
        exit 1
        ;;
    esac

    if [ ! -s "$1" ]; then
        echo "File is empty: $1" >&2
        exit 1
    fi
}

filename="${1:-}"

# Print help
if [ -z "$filename" ] || [ "$filename" = "--help" ] || [ "$filename" = "-h" ]; then
    echo "Usage: $0 <filename> | nc <host> 4299" >&2
    exit 1
fi

check_input "$filename"
basename=$(basename "$filename")

# Get file size (gnu stat with bsd stat fallback with wc fallback)
compressed_size=$(stat -c %s "$filename" 2>/dev/null || stat -f %z "$filename" 2>/dev/null || wc -c <"$filename")
uncompressed_size=0

# Compress ELF and DOL files (where possible)
case "$1" in
*.dol | *.DOL | *.elf | *.ELF)
    if tmpfile=$(mktemp) 2>/dev/null; then
        trap 'rm -f "$tmpfile"' EXIT INT TERM HUP

        if compress_zlib <"$filename" >"$tmpfile" 2>/dev/null; then
            uncompressed_size="$compressed_size"
            compressed_size=$(wc -c <"$tmpfile")
            filename="$tmpfile"
        fi
    fi
    ;;
esac

# filename length (including null terminator)
filename_len=$(printf '%s\000' "$basename" | wc -c)

# Wiiload 16-byte header:
# 4 bytes: magic
# 2 bytes: wiiload version (0.5)
# 2 bytes: filename length + 1
# 4 bytes: compressed size (or uncompressed size if compression not used)
# 4 bytes: uncompressed size (0 if compression not used)
header_fmt="$(printf 'HAXX\\000\\005\\%03o\\%03o\\%03o\\%03o\\%03o\\%03o\\%03o\\%03o\\%03o\\%03o' \
    $((filename_len >> 8)) \
    $((filename_len & 0xff)) \
    $((compressed_size >> 24 & 0xff)) \
    $((compressed_size >> 16 & 0xff)) \
    $((compressed_size >> 8 & 0xff)) \
    $((compressed_size & 0xff)) \
    $((uncompressed_size >> 24 & 0xff)) \
    $((uncompressed_size >> 16 & 0xff)) \
    $((uncompressed_size >> 8 & 0xff)) \
    $((uncompressed_size & 0xff)))"

printf '%b' "$header_fmt"   # header as bytes
cat "$filename"             # file contents
printf '%s\000' "$basename" # file name with null terminator
