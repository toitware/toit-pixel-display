// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests some simple vertical sliders where there is a movable boundary between
// two different backgrounds.

import expect show *
import font show *
import pixel-display show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  WIDTH ::= 220
  HEIGHT ::= 140
  driver := TrueColorPngVisualizer WIDTH HEIGHT args[0] --outline=0x4040ff
  display := PixelDisplay.true-color driver
  display.background = 0x808080

  sans10 := Font.get "sans10"
  label := Label --x=0 --y=0 --text="foo" --font=sans10
  div := Div --x=30 --y=30 --w=(WIDTH - 60) --h=(HEIGHT - 60) [
    // Since this isn't a clipping div, the label is drawn, even though it is
    // outside the div.
    label
  ]
  display.add div

  display.draw

  label.text = "bar"
  display.draw

  label.y = 25
  // As long as there isn't any background or border we don't need the
  // dimensions of non-clipping divs.
  div = Div [label]
  display.remove-all
  display.add div
  display.draw

  div.background = 0x404040
  // Without dimensions, the background is ignored.
  display.draw

  div.w = WIDTH - 60
  div.h = HEIGHT - 60
  display.draw

  driver.write-png
