// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *
import font show Font
import pixel_display show *
import pixel_display.four_gray show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := FourGrayPngVisualizer 160 64 args[0] --outline=WHITE
  display := FourGrayPixelDisplay driver
  display.background = BLACK
  
  sans10 := Font.get "sans10"

  ctx := display.context --landscape --color=LIGHT_GRAY --font=sans10

  display.filled_rectangle (ctx.with --color=DARK_GRAY) 10 20 30 40
  display.text ctx 50 20 "Testing"
  middle_line := display.text ctx 50 40 "the display"
  display.draw
  display.text ctx 50 60 "for the win"

  display.draw

  middle_line.move_to 60 40
  display.draw

  middle_line.text = "the DISPLAY"
  display.draw
