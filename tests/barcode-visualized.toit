// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests drawing a supermarket-style bar code on a pixel display.

import expect show *
import pixel-display show *
import pixel-display.bar-code show *
import pixel-display.element show *
import pixel-display.style show Style
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 120 160 args[0] --outline=SEVERAL-BLUE
  display := PixelDisplay.several-color driver --portrait=false
  display.background = SEVERAL-GRAY

  style := Style --type-map={
      "bar-code-ean": Style --color=SEVERAL-BLACK --background=SEVERAL-WHITE,
  }

  barcode := BarCodeEanElement --x=15 --y=15 --code="4035999001512"
  display.add barcode
  display.set-styles [style]
  display.draw

  barcode.move-to 20 20
  display.draw

  barcode.code = "4000417020000"
  display.draw

  driver.write-png
