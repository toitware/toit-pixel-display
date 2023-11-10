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

# Crush the files.
pngout -y heater-bw.png heater-bw.png
pngout -y heater-white-bg.png heater-white-bg.png
pngout -y heater-4-bit.png heater-4-bit.png

# Make uncompressed versions.
pngunzip -o heater-2-bit-uncompressed.png heater-2-bit.png
pngunzip -o heater-bw-uncompressed.png heater-bw.png
pngunzip -o heater-white-bg-uncompressed.png heater-white-bg.png
pngunzip -o heater-4-bit-uncompressed.png heater-4-bit.png
pngunzip -o heater-uncompressed.png heater.png
