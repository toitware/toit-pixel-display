// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Element-based text is rotated and positioned.

import bitmap show *
import expect show *
import font show *
import pixel_display show *
import pixel_display.element show *
import pixel_display.style show *
import .png_visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 192 96 args[0] --outline=SEVERAL_WHITE
  display := PixelDisplay.several_color driver
  display.background = SEVERAL_DARK_GRAY

  sans10 := Font.get "sans10"

  // Element-based rectangles.
  element_text := Label --x=30 --y=30 --color=SEVERAL_ORANGE --label="joo%" --font=sans10
  element_text_2 := Label --x=130 --y=20 --color=SEVERAL_ORANGE --label="joo%" --font=sans10
  display.add element_text
  display.add element_text_2
  display.draw

  element_text.move_to 31 40
  display.draw

  display.draw

  element_text_2.move_to 130 30
  display.draw

  element_text.orientation = ORIENTATION_90
  display.draw

  element_text.orientation = ORIENTATION_180
  display.draw

  element_text.orientation = ORIENTATION_270
  display.draw

  element_text.orientation = ORIENTATION_0
  display.draw

  element_text.alignment = ALIGN_CENTER
  display.draw

  element_text.alignment = ALIGN_RIGHT
  display.draw

  element_text.orientation = ORIENTATION_90
  display.draw

  element_text.orientation = ORIENTATION_180
  display.draw

  element_text.orientation = ORIENTATION_270
  display.draw

  driver.write_png
