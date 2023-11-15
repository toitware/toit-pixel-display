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
import pixel_display.four_gray show WHITE LIGHT_GRAY
import .png_visualizer

SANS := font.Font.get "sans10"

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1

  basename := args[0]

  driver := FourGrayPngVisualizer 440 240 basename --outline=WHITE
  display := FourGrayPixelDisplay driver
  display.background = LIGHT_GRAY

  heater-red := file.read_content "tests/third_party/pictogrammers/heater-red.png"
  heater-red-uncompressed := file.read_content "tests/third_party/pictogrammers/heater-red-uncompressed.png"
  heater-2-bit := file.read_content "tests/third_party/pictogrammers/heater-2-bit.png"
  heater-2-bit-uncompressed := file.read_content "tests/third_party/pictogrammers/heater-2-bit-uncompressed.png"
  heater-bw := file.read_content "tests/third_party/pictogrammers/heater-bw.png"
  heater-bw-uncompressed := file.read_content "tests/third_party/pictogrammers/heater-bw-uncompressed.png"
  heater-white-bg := file.read_content "tests/third_party/pictogrammers/heater-white-bg.png"
  heater-white-bg-uncompressed := file.read_content "tests/third_party/pictogrammers/heater-white-bg-uncompressed.png"

  display.add (PngElement --x=100 --y=32 heater-red)
  display.add (PngElement --x=184 --y=32 heater-2-bit)
  display.add (PngElement --x=268 --y=32 heater-bw)
  display.add (PngElement --x=352 --y=32 heater-white-bg)

  display.add (PngElement --x=100 --y=120 heater-red-uncompressed)
  //display.add (PngElement --x=184 --y=120 heater-2-bit-uncompressed)
  display.add (PngElement --x=268 --y=120 heater-bw-uncompressed)
  display.add (PngElement --x=352 --y=120 heater-white-bg-uncompressed)

  display.draw

  driver.write_png
