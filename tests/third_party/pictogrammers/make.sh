#!bin/sh

set -e

# Input, heater.png is a three-color icon made with GIMP and crushed with
# pngout.  It is stored as 8 bit indexed color.

pngquant 16 --force --nofs -o heater-4-bit.png heater.png

pngquant 3 --force --nofs -o heater-2-bit.png heater.png

# Make the transparent pixels black and make all pixels either
# completely transparent or completely opaque.  Also uncompresses.
pngunzip --override-chunk "PLTE=#[0, 0, 0, 0, 0, 0, 0xff, 0, 0]" --override-chunk "tRNS=#[0, 0xff, 0xff]" -o heater-2-bit.png heater-2-bit.png

# Remake the compressed version with the new palette and transparency.
pngout -y heater-2-bit.png heater-2-bit.png

# Make a 2-color version with transparency.
pngunzip --override-chunk "PLTE=#[0xff, 0xff, 0xff, 0, 0, 0, 0, 0, 0]" --override-chunk "tRNS=#[0, 0xff, 0xff]" -o heater-bw.png heater-2-bit.png

# The 2-color version still has 3 palette entries, but pngquant can fix that.
pngquant 2 --force --nofs -o heater-bw.png heater-bw.png

# Strangely it makes all the transparent pixels gray, so we fix that.
pngunzip --override-chunk "PLTE=#[0, 0, 0, 0, 0, 0]" -o heater-bw.png heater-bw.png

# Make a version with a white non-transparent background.
pngunzip --override-chunk "PLTE=#[0xff, 0xff, 0xff, 0, 0, 0]" --override-chunk "tRNS=#[0xff, 0xff]" -o heater-white-bg.png heater-bw.png

# Make a version with a partially transparent foreground and background.
pngunzip --override-chunk "PLTE=#[0xff, 0x0, 0, 0x80, 0x80, 0xff]" --override-chunk "tRNS=#[0x30, 0x80]" -o heater-translucent.png heater-bw.png

# Make a red 1-bit version.
pngunzip --override-chunk "PLTE=#[0xff, 0xff, 0xff, 0xff, 0, 0]" --override-chunk "tRNS=#[0]" -o heater-red.png heater-bw.png

# Crush the files.
pngout -y heater-bw.png heater-bw.png
pngout -y heater-white-bg.png heater-white-bg.png
pngout -y heater-4-bit.png heater-4-bit.png
pngout -y heater-translucent.png heater-translucent.png
pngout -y heater-red.png heater-red.png

# Make uncompressed versions.
# Be sure to test images that take more than one literal section.
PNGUNZIP_OPT=--max-literal-section=500
pngunzip $PNGUNZIP_OPT -o heater-2-bit-uncompressed.png heater-2-bit.png
pngunzip $PNGUNZIP_OPT -o heater-bw-uncompressed.png heater-bw.png
pngunzip $PNGUNZIP_OPT -o heater-white-bg-uncompressed.png heater-white-bg.png
pngunzip $PNGUNZIP_OPT -o heater-translucent-uncompressed.png heater-translucent.png
pngunzip $PNGUNZIP_OPT -o heater-red-uncompressed.png heater-red.png
pngunzip $PNGUNZIP_OPT -o heater-4-bit-uncompressed.png heater-4-bit.png
pngunzip $PNGUNZIP_OPT -o heater-uncompressed.png heater.png
