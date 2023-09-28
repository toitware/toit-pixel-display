// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *
import font show Font
import pixel_display show *
import pixel_display.true_color show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := TrueColorPngVisualizer 129 89 args[0] --outline=0xffff00
  display := TrueColorPixelDisplay driver
  display.background = get_rgb 0 1 2
  
  sans10 := Font.get "sans10"

  ctx := display.context --landscape=false --color=(get_rgb 255 120 0) --font=sans10

  display.filled_rectangle (ctx.with --color=0x4040ff) 10 20 30 40
  display.filled_rectangle (ctx.with --color=0x4040ff) 20 70 30 40
  display.text ctx 5 80 "Testing"
  middle_line := display.text ctx 5 100 "the display"
  display.draw
  display.text ctx 5 120 "for the win"

  display.draw

  middle_line.move_to 10 100
  display.draw

  middle_line.text = "the DisplaY"
  display.draw
