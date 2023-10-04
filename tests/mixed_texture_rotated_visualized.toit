// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Mixes texture-based and element-based rectangles on the same display to test
// that they are positioned in the same way and the redraw boxes are right.
// Uses a rotated frame (portrait mode).

import expect show *
import pixel_display show *
import pixel_display.texture show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 160 64 args[0] --outline=SEVERAL_WHITE
  display := SeveralColorPixelDisplay driver --inverted --portrait
  display.background = SEVERAL_DARK_GRAY

  ctx := display.context --inverted --landscape=false --color=SEVERAL_ORANGE

  // Texture-based rectangle.
  texture_rect := display.filled_rectangle (ctx.with --color=SEVERAL_BLUE) 10 20 30 20
  texture_rect_2 := display.filled_rectangle (ctx.with --color=SEVERAL_BLUE) 10 65 30 20
  // Slightly smaller element-based rectangle.
  element_rect := FilledRectangleElement 11 21 --w=28 --h=18 --color=SEVERAL_BLACK
  element_rect_2 := FilledRectangleElement 10 110 --w=30 --h=20 --color=SEVERAL_GREEN
  display.add element_rect
  display.add element_rect_2
  display.draw

  texture_rect.move_to 20 20
  element_rect.move_to 21 21
  display.draw

  texture_rect_2.move_to 20 65
  display.draw

  element_rect_2.move_to 20 110
  display.draw
