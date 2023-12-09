// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Element-based text is rotated and positioned.

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
  driver := SeveralColorPngVisualizer 192 96 args[0] --outline=SEVERAL-WHITE
  display := PixelDisplay.several-color driver
  display.background = SEVERAL-DARK-GRAY

  sans10 := Font.get "sans10"

  // Element-based rectangles.
  element-text := Label --x=30 --y=30 --color=SEVERAL-ORANGE --label="joo%" --font=sans10
  element-text-2 := Label --x=130 --y=20 --color=SEVERAL-ORANGE --label="joo%" --font=sans10
  display.add element-text
  display.add element-text-2
  display.draw

  element-text.move-to 31 40
  display.draw

  display.draw

  element-text-2.move-to 130 30
  display.draw

  element-text.orientation = ORIENTATION-90
  display.draw

  element-text.orientation = ORIENTATION-180
  display.draw

  element-text.orientation = ORIENTATION-270
  display.draw

  element-text.orientation = ORIENTATION-0
  display.draw

  element-text.alignment = ALIGN-CENTER
  display.draw

  element-text.alignment = ALIGN-RIGHT
  display.draw

  element-text.orientation = ORIENTATION-90
  display.draw

  element-text.orientation = ORIENTATION-180
  display.draw

  element-text.orientation = ORIENTATION-270
  display.draw

  driver.write-png
