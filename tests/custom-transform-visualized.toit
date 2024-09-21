// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import bitmap show *
import font show Font
import pixel-display show *
import pixel-display.two-color show BLACK WHITE
import .png-visualizer

class TransformedDriver extends TwoColorPngVisualizer:
  constructor width/int height/int path/string --outline/int?=null:
    super width height path --outline=outline

  base-transform --inverted/bool --portrait/bool? -> Transform:
    // Simulate a display that wants its input rotated 90 degrees and inverted.
    if portrait == null:
      portrait = true
    else:
      portrait = not portrait
    return super --no-inverted --portrait=portrait

main args:
  sans10 := Font.get "sans10"

  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := TransformedDriver 240 160 args[0] --outline=BLACK
  display := PixelDisplay.two-color driver
  display.background = WHITE

  text := Label --x=10 --y=55 --text="Hello, World!" --font=sans10 --color=BLACK
  display.add text

  display.draw

  driver.write-png
