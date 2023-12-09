// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Element-based rectangles with simple borders.

import expect show *
import pixel-display show *
import pixel-display.element show *
import pixel-display.style show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 200 64 args[0] --outline=SEVERAL-WHITE
  display := PixelDisplay.several-color driver
  display.background = SEVERAL-DARK-GRAY

  // Slightlly smaller element-based rectangle.
  element-rect   := Div --x=11  --y=21 --w=28 --h=18 --background=SEVERAL-BLACK
  element-rect-2 := Div --x=110 --y=20 --w=30 --h=20 --background=SEVERAL-GREEN
  element-rect-3 := Div --x=160 --y=10 --w=30 --h=30 --border=(SolidBorder --color=SEVERAL-BLUE --width=5)
  display.add element-rect
  display.add element-rect-2
  display.add element-rect-3
  display.draw

  element-rect.move-to 11 31
  display.draw

  element-rect-2.move-to 110 30
  display.draw

  display.remove element-rect
  display.remove element-rect-2

  element-rect-3.move-to 160 20
  display.draw

  element-rect-3.border = SolidBorder --color=SEVERAL-BLUE --width=2
  display.draw

  element-rect-3.border = SolidBorder --color=SEVERAL-BLUE --width=7
  display.draw

  driver.write-png
