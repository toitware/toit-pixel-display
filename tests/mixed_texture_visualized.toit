// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Mixes texture-based and element-based rectangles on the same display to test
// that they are positioned in the same way and the redraw boxes are right.

import expect show *
import pixel_display show *
import pixel_display.texture show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 200 64 args[0] --outline=SEVERAL_WHITE
  display := SeveralColorPixelDisplay driver
  display.background = SEVERAL_GRAY

  ctx := display.context --landscape --color=SEVERAL_ORANGE

  // Texture-based rectangle.
  texture_rect := display.filled_rectangle (ctx.with --color=SEVERAL_BLUE) 10 20 30 20
  texture_rect_2 := display.filled_rectangle (ctx.with --color=SEVERAL_BLUE) 60 20 30 20
  // Slightlly smaller element-based rectangle.
  element_rect := FilledRectangleElement 11 21 --w=28 --h=18 --color=SEVERAL_BLACK
  element_rect_2 := FilledRectangleElement 110 20 --w=30 --h=20 --color=SEVERAL_GREEN
  element_rect_3 := OutlineRectangleElement 160 10 --w=30 --h=30 --color=SEVERAL_BLUE --thickness=5
  display.add element_rect
  display.add element_rect_2
  display.add element_rect_3
  display.draw

  texture_rect.move_to 10 30
  element_rect.move_to 11 31
  display.draw

  texture_rect_2.move_to 60 30
  display.draw

  element_rect_2.move_to 110 30
  display.draw

  display.remove element_rect
  display.remove element_rect_2
  display.remove texture_rect
  display.remove texture_rect_2

  element_rect_3.move_to 160 20
  display.draw

  element_rect_3.thickness = 2
  display.draw

  element_rect_3.thickness = 7
  display.draw
