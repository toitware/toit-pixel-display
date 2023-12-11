// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Mixes texture-based and element-based rectangles on the same display to test
// that they are positioned in the same way and the redraw boxes are right.
// Uses a rotated frame (portrait mode).

import expect show *
import pixel-display show *
import pixel-display.element show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 160 64 args[0] --outline=SEVERAL-WHITE
  display := PixelDisplay.several-color driver --inverted --portrait
  display.background = SEVERAL-DARK-GRAY

  // Element-based rectangle.
  element-rect := Div --x=11 --y=21 --w=28 --h=18 --background=SEVERAL-BLACK
  element-rect-2 := Div --x=10 --y=110 --w=30 --h=20 --background=SEVERAL-GREEN
  display.add element-rect
  display.add element-rect-2
  display.draw

  element-rect.move-to 21 21
  display.draw

  display.draw

  element-rect-2.move-to 20 110
  display.draw

  driver.write-png
