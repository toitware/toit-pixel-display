// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *
import font show Font
import pixel_display show *
import pixel_display.element show *
import pixel_display.true_color show *
import .png_visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := TrueColorPngVisualizer 129 89 args[0] --outline=0xffff00
  display := TrueColorPixelDisplay driver --portrait
  display.background = get_rgb 0 1 2

  sans10 := Font.get "sans10"

  foreground := get_rgb 255 120 0

  display.add
      Div --x=10 --y=20 --w=30 --h=40 --background=0x4040ff
  display.add
      Div --x=20 --y=70 --w=30 --h=40 --background=0x4040ff
  display.add
      Label --x=5 --y=80 --label="Testing" --font=sans10 --color=foreground
  middle_line := Label --x=5 --y=100 --label="the display" --font=sans10 --color=foreground
  display.add middle_line
  display.draw

  display.add
      Label --x=5 --y=120 --label="for the win" --font=sans10 --color=foreground

  display.draw

  middle_line.move_to 10 100
  display.draw

  middle_line.label = "the DisplaY"
  display.draw

  driver.write_png
