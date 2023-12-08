// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import bitmap show *
import font show Font
import pixel_display show *
import pixel_display.element show *
import pixel_display.style show *
import .png_visualizer

main args:
  sans10 := Font.get "sans10"

  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 240 160 args[0] --outline=SEVERAL_BLUE
  display := PixelDisplay.several_color driver
  display.background = SEVERAL_BLUE

  win := Div.clipping --x=30 --y=30 --w=180 --h=100 --background=SEVERAL_LIGHT_GRAY --border=(RoundedCornerBorder --radius=15)
  display.add win

  text := Label --x=90 --y=55 --label="Hello, World!" --font=sans10 --color=SEVERAL_BLACK
  win.add text

  display.draw

  text.move_to 120 65

  display.draw

  // Window-relative coordinates.
  text.move_to -10 7

  display.draw

  driver.write_png
