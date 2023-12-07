// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests drawing a supermarket-style bar code on a pixel display.

import expect show *
import pixel_display show *
import pixel_display.bar_code show *
import pixel_display.element show *
import pixel_display.style show Style
import .png_visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 120 160 args[0] --outline=SEVERAL_BLUE
  display := SeveralColorPixelDisplay driver --portrait=false
  display.background = SEVERAL_GRAY

  style := Style --type_map={
      "bar-code-ean": Style --color=SEVERAL_BLACK --background=SEVERAL_WHITE,
  }

  barcode := BarCodeEanElement --x=15 --y=15 "4035999001512"
  display.add barcode
  display.set_styles [style]
  display.draw

  barcode.move_to 20 20
  display.draw

  barcode.code = "4000417020000"
  display.draw

  driver.write_png
