// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests writing PNGs to a true-color display.

import bitmap show *
import expect show *
import font

import host.file
import pixel-display show *
import pixel-display.element show *
import pixel-display.gradient show *
import pixel-display.png show Png
import .png-visualizer

SANS := font.Font.get "sans10"

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1

  do args[0] 340 320
  do "$args[0]-rotated" 320 340

do basename/string w/int h/int:
  driver := TrueColorPngVisualizer w h basename --outline=0xc0c0ff
  display := PixelDisplay.true-color driver
  display.background = 0x808080

  // A 1-bit PNG file that is uncompressed, so we can use the PngRandomAccess
  // class to display it straight from flash.
  purifier := file.read-content "tests/third_party/pictogrammers/air-purifier-bit-unzip.png"
  // A 1-bit PNG file that is compressed, so it takes less flash, but we have
  // to decompress it to display it.  This file also has an almost-transparent
  // background, so we test the code path where we display a 1-bit image with
  // a real alpha channel (and it has a gray background in the output).
  purifier-compressed := file.read-content "tests/third_party/pictogrammers/air-purifier-bit.png"

  gradient := GradientBackground --angle=160 --specifiers=[
      GradientSpecifier --color=0xe0e0ff 10,
      GradientSpecifier --color=0x8080c0 90,
      ]
  gradient-element := Div --x=0 --y=0 --w=340 --h=320 --background=gradient
  display.add gradient-element

  display.draw

  label := Label --x=44 --y=44 --label="UP ^" --font=SANS --color=0
  display.add label
  png-element := Png --x=36 --y=32 --png-file=purifier
  display.add png-element
  display.draw

  display.remove png-element
  png-element = Png --x=36 --y=32 --png-file=purifier-compressed
  display.add png-element
  display.draw

  driver.write-png
