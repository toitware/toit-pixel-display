// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests writing PNGs to a black and white display.

import bitmap show *
import expect show *
import font

import host.file
import pixel-display show *
import pixel-display.element show *
import pixel-display.png show Png
import pixel-display.two-color show WHITE BLACK
import .png-visualizer

SANS := font.Font.get "sans10"

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1

  basename := args[0]

  driver := TwoColorPngVisualizer 440 240 basename --outline=BLACK
  display := PixelDisplay.two-color driver
  display.background = WHITE

  heater-red := file.read-content "tests/third_party/pictogrammers/heater-red.png"
  heater-red-uncompressed := file.read-content "tests/third_party/pictogrammers/heater-red-uncompressed.png"
  heater-2-bit := file.read-content "tests/third_party/pictogrammers/heater-2-bit.png"
  heater-2-bit-uncompressed := file.read-content "tests/third_party/pictogrammers/heater-2-bit-uncompressed.png"
  heater-bw := file.read-content "tests/third_party/pictogrammers/heater-bw.png"
  heater-bw-uncompressed := file.read-content "tests/third_party/pictogrammers/heater-bw-uncompressed.png"
  heater-white-bg := file.read-content "tests/third_party/pictogrammers/heater-white-bg.png"
  heater-white-bg-uncompressed := file.read-content "tests/third_party/pictogrammers/heater-white-bg-uncompressed.png"

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
