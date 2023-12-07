// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *
import font show Font
import pixel_display show *
import pixel_display.gray_scale show *
import pixel_display.element show *
import .png_visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := GrayScalePngVisualizer 160 64 args[0] --outline=0xff
  display := PixelDisplay.gray_scale driver
  display.background = 0x40

  sans10 := Font.get "sans10"

  display.add
      Div --x=10 --y=20 --w=30 --h=40 --background=0x80
  display.add
      Label --x=50 --y=20 --label="Testing" --font=sans10 --color=0xc0

  middle_line := Label --x=50 --y=40 --label="the display" --font=sans10 --color=0xc0
  display.add middle_line
  display.draw

  display.add
      Label --x=50 --y=60 --label="for the win" --font=sans10 --color=0xc0

  display.draw

  middle_line.move_to 60 40
  display.draw

  middle_line.label = "the DISPLAY"
  display.draw

  driver.write_png
