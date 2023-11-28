// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import bitmap show *
import font show Font
import pixel_display show *
import pixel_display.element show *
import pixel_display.two_color show BLACK WHITE
import .png_visualizer

main args:
  sans10 := Font.get "sans10"

  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := TwoColorPngVisualizer 240 160 args[0] --outline=BLACK
  display := TwoColorPixelDisplay driver
  display.background = BLACK

  win := RoundedCornerWindowElement --x=30 --y=30 --w=180 --h=100 --corner_radius=17 --background=WHITE
  display.add win

  text := Label --x=90 --y=55 --label="Hello, World!" --font=sans10 --color=BLACK
  win.add text

  display.draw

  text.move_to 120 65
  win.corner_radius--

  display.draw

  // Window-relative coordinates.
  text.move_to -10 7
  win.corner_radius--

  display.draw

  driver.write_png
