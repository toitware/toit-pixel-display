// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Mixes texture-based and element-based text on the same display to test
// that they are positioned in the same way and the redraw boxes are right.
// Uses a rotated frame (portrait mode).

import bitmap show *
import expect show *
import font show *
import pixel_display show *
import pixel_display.element show *
import pixel_display.texture show *
import .png_visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 160 96 args[0] --outline=SEVERAL_WHITE
  display := SeveralColorPixelDisplay driver --portrait
  display.background = SEVERAL_DARK_GRAY

  sans10 := Font.get "sans10"

  ctx := display.context --landscape=false --color=SEVERAL_ORANGE --font=sans10

  // Texture-based text.
  texture_text := display.text (ctx.with --color=SEVERAL_BLUE) 10 20 "Texture 1"
  texture_text_2 := display.text (ctx.with --color=SEVERAL_BLUE) 10 65 "Texture 2"
  // Element-based text.
  element_text := Label --x=10 --y=30 --color=SEVERAL_GREEN --font=sans10 --label="Element 1"
  element_text_2 := Label --x=10 --y=110 --color=SEVERAL_GREEN --font=sans10 --label="Element 2"
  display.add element_text
  display.add element_text_2
  display.draw

  texture_text.move_to 20 20
  element_text.move_to 20 30
  display.draw

  texture_text_2.move_to 20 65
  display.draw

  element_text_2.move_to 20 110
  display.draw

  element_text.alignment = TEXT_TEXTURE_ALIGN_RIGHT
  display.draw

  element_text.orientation = ORIENTATION_90
  element_text_2.orientation = ORIENTATION_90
  display.draw

  element_text.orientation = ORIENTATION_180
  element_text_2.orientation = ORIENTATION_180
  display.draw

  element_text.orientation = ORIENTATION_270
  element_text_2.orientation = ORIENTATION_270
  display.draw

  driver.write_png
