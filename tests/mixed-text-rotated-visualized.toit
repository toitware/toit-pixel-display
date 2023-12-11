// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Element-based text is rotated and positioned.
// Uses a rotated frame (portrait mode).

import bitmap show *
import expect show *
import font show *
import pixel-display show *
import pixel-display.element show *
import pixel-display.style show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 160 96 args[0] --outline=SEVERAL-WHITE
  display := PixelDisplay.several-color driver --portrait
  display.background = SEVERAL-DARK-GRAY

  sans10 := Font.get "sans10"

  // Element-based text.
  element-text := Label --x=10 --y=30 --color=SEVERAL-GREEN --font=sans10 --label="Element 1"
  element-text-2 := Label --x=10 --y=110 --color=SEVERAL-GREEN --font=sans10 --label="Element 2"
  display.add element-text
  display.add element-text-2
  display.draw

  element-text.move-to 20 30
  display.draw

  display.draw

  element-text-2.move-to 20 110
  display.draw

  element-text.alignment = ALIGN-RIGHT
  display.draw

  element-text.orientation = ORIENTATION-90
  element-text-2.orientation = ORIENTATION-90
  display.draw

  element-text.orientation = ORIENTATION-180
  element-text-2.orientation = ORIENTATION-180
  display.draw

  element-text.orientation = ORIENTATION-270
  element-text-2.orientation = ORIENTATION-270
  display.draw

  driver.write-png
