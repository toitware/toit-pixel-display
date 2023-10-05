// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Mixes texture-based and element-based text on the same display to test
// that they are positioned in the same way and the redraw boxes are right.

import bitmap show *
import expect show *
import font show *
import pixel_display show *
import pixel_display.texture show *
import .png_visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 192 96 args[0] --outline=SEVERAL_WHITE
  display := SeveralColorPixelDisplay driver
  display.background = SEVERAL_DARK_GRAY

  sans10 := Font.get "sans10"

  ctx := display.context --landscape --color=SEVERAL_ORANGE --font=sans10

  // Texture-based text.
  texture_text := display.text (ctx.with --color=SEVERAL_BLUE) 30 20 "Texture"
  texture_text_2 := display.text (ctx.with --color=SEVERAL_BLUE) 80 20 "Texture"
  // Element-based rectangles.
  element_text := TextElement --x=30 --y=30 --color=SEVERAL_ORANGE --text="joo%" --font=sans10
  element_text_2 := TextElement --x=130 --y=20 --color=SEVERAL_ORANGE --text="joo%" --font=sans10
  display.add element_text
  display.add element_text_2
  display.draw

  texture_text.move_to 30 30
  element_text.move_to 31 40
  display.draw

  texture_text_2.move_to 80 30
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

  element_text.alignment = TEXT_TEXTURE_ALIGN_CENTER
  display.draw

  element_text.alignment = TEXT_TEXTURE_ALIGN_RIGHT
  display.draw

  element_text.orientation = ORIENTATION_90
  display.draw

  element_text.orientation = ORIENTATION_180
  display.draw

  element_text.orientation = ORIENTATION_270
  display.draw

  driver.write_png
