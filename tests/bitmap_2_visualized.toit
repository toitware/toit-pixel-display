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

  basename := args[0]

  driver := TrueColorPngVisualizer 524 240 basename --outline=0xffffff
  display := TrueColorPixelDisplay driver
  display.background = 0xe0e080

  heater := file.read_content "tests/third_party/pictogrammers/heater.png"
  heater-uncompressed := file.read_content "tests/third_party/pictogrammers/heater-uncompressed.png"
  heater-4-bit := file.read_content "tests/third_party/pictogrammers/heater-4-bit.png"
  heater-4-bit-uncompressed := file.read_content "tests/third_party/pictogrammers/heater-4-bit-uncompressed.png"
  heater-2-bit := file.read_content "tests/third_party/pictogrammers/heater-2-bit.png"
  heater-2-bit-uncompressed := file.read_content "tests/third_party/pictogrammers/heater-2-bit-uncompressed.png"
  heater-bw := file.read_content "tests/third_party/pictogrammers/heater-bw.png"
  heater-bw-uncompressed := file.read_content "tests/third_party/pictogrammers/heater-bw-uncompressed.png"
  heater-white-bg := file.read_content "tests/third_party/pictogrammers/heater-white-bg.png"
  heater-white-bg-uncompressed := file.read_content "tests/third_party/pictogrammers/heater-white-bg-uncompressed.png"
  heater-translucent := file.read_content "tests/third_party/pictogrammers/heater-translucent.png"
  heater-translucent-uncompressed := file.read_content "tests/third_party/pictogrammers/heater-translucent-uncompressed.png"

  display.add (PngElement --x=16 --y=32 heater)
  display.add (PngElement --x=100 --y=32 heater-4-bit)
  display.add (PngElement --x=184 --y=32 heater-2-bit)
  display.add (PngElement --x=268 --y=32 heater-bw)
  display.add (PngElement --x=352 --y=32 heater-white-bg)
  display.add (PngElement --x=436 --y=32 heater-translucent)

  display.add (PngElement --x=16 --y=120 heater-uncompressed)
  display.add (PngElement --x=100 --y=120 heater-4-bit-uncompressed)
  display.add (PngElement --x=184 --y=120 heater-2-bit-uncompressed)
  display.add (PngElement --x=268 --y=120 heater-bw-uncompressed)
  display.add (PngElement --x=352 --y=120 heater-white-bg-uncompressed)
  display.add (PngElement --x=436 --y=120 heater-translucent-uncompressed)

  display.draw

  driver.write_png
