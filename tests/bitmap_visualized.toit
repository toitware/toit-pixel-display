// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests for Label that the change box is smaller when we only
// change part of the text.

import bitmap show *
import expect show *
import font

import host.file
import pixel_display show *
import pixel_display.element show *
import .png_visualizer

SANS := font.Font.get "sans10"

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1

  do args[0] 340 320
  do "$args[0]-rotated" 320 340

do basename/string w/int h/int:
  driver := TrueColorPngVisualizer w h basename --outline=0xc0c0ff
  display := TrueColorPixelDisplay driver
  display.background = 0x808080

  // A 1-bit PNG file that is uncompressed, so we can use the PngRandomAccess
  // class to display it straight from flash.
  purifier := file.read_content "tests/third_party/pictogrammers/air-purifier-bit-unzip.png"
  // A 1-bit PNG file that is compressed, so it takes less flash, but we have
  // to decompress it to display it.  This file also has an almost-transparent
  // background, so we test the code path where we display a 1-bit image with
  // a real alpha channel (and it has a gray background in the output).
  purifier_compressed := file.read_content "tests/third_party/pictogrammers/air-purifier-bit.png"

  gradient := Gradient --angle=160 --specifiers=[
      GradientSpecifier --color=0xe0e0ff 10,
      GradientSpecifier --color=0x8080c0 90,
      ]
  gradient_element := GradientElement --x=0 --y=0 --w=340 --h=320 --gradient=gradient
  display.add gradient_element

  display.draw

  label := Label --x=44 --y=44 --label="UP ^" --font=SANS --color=0
  display.add label
  png_element := PngElement --x=36 --y=32 purifier
  display.add png_element
  display.draw

  display.remove png_element
  png_element = PngElement --x=36 --y=32 purifier_compressed
  display.add png_element
  display.draw

  driver.write_png
