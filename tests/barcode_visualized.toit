// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests for TextElement that the change box is smaller when we only
// change part of the text.

import expect show *
import pixel_display show *
import pixel_display.texture show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 120 160 args[0] --outline=SEVERAL_BLUE
  display := SeveralColorPixelDisplay driver --portrait=false
  display.background = SEVERAL_GRAY

  barcode := BarCodeEanElement "4035999001512" 15 15 --foreground=SEVERAL_BLACK --background=SEVERAL_WHITE
  display.add barcode
  display.draw

  barcode.move_to 20 20
  display.draw

  barcode.code = "4000417020000"
  display.draw
