// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import bitmap show *
import font show Font
import pixel-display show *
import pixel-display.three-color show BLACK WHITE RED
import .png-visualizer

main args:
  sans10 := Font.get "sans10"

  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := ThreeColorPngVisualizer 240 160 args[0] --outline=RED
  display := PixelDisplay.three-color driver
  display.background = WHITE

  win := Div.clipping --x=30 --y=30 --w=180 --h=100 --background=RED
  display.add win

  text := Label --x=90 --y=55 --text="Hello, World!" --font=sans10 --color=BLACK
  win.add text

  display.draw

  text.move-to 120 65

  display.draw

  // Window-relative coordinates.
  text.move-to -10 7

  display.draw

  driver.write-png
