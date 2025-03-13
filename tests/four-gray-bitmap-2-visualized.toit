// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests writing PNGs to a display with four gray levels.

import bitmap show *
import expect show *
import font

import host.file
import pixel-display show *
import pixel-display.four-gray show WHITE LIGHT-GRAY
import pixel-display.png show Png
import .png-visualizer

SANS := font.Font.get "sans10"

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1

  basename := args[0]

  driver := FourGrayPngVisualizer 440 240 basename --outline=WHITE
  display := PixelDisplay.four-gray driver
  display.background = LIGHT-GRAY

  heater-red := file.read-contents "tests/third_party/pictogrammers/heater-red.png"
  heater-red-uncompressed := file.read-contents "tests/third_party/pictogrammers/heater-red-uncompressed.png"
  heater-2-bit := file.read-contents "tests/third_party/pictogrammers/heater-2-bit.png"
  heater-2-bit-uncompressed := file.read-contents "tests/third_party/pictogrammers/heater-2-bit-uncompressed.png"
  heater-bw := file.read-contents "tests/third_party/pictogrammers/heater-bw.png"
  heater-bw-uncompressed := file.read-contents "tests/third_party/pictogrammers/heater-bw-uncompressed.png"
  heater-white-bg := file.read-contents "tests/third_party/pictogrammers/heater-white-bg.png"
  heater-white-bg-uncompressed := file.read-contents "tests/third_party/pictogrammers/heater-white-bg-uncompressed.png"

  display.add (Png --x=100 --y=32 --png-file=heater-red)
  display.add (Png --x=184 --y=32 --png-file=heater-2-bit)
  display.add (Png --x=268 --y=32 --png-file=heater-bw)
  display.add (Png --x=352 --y=32 --png-file=heater-white-bg)

  display.add (Png --x=100 --y=120 --png-file=heater-red-uncompressed)
  display.add (Png --x=184 --y=120 --png-file=heater-2-bit-uncompressed)
  display.add (Png --x=268 --y=120 --png-file=heater-bw-uncompressed)
  display.add (Png --x=352 --y=120 --png-file=heater-white-bg-uncompressed)

  display.draw

  driver.write-png
