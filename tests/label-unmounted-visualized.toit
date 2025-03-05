// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests for Label that the change box is smaller when we only
// change part of the text.

import bitmap show *
import expect show *
import font show *
import pixel-display show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 192 96 args[0] --outline=SEVERAL-WHITE
  display := PixelDisplay.several-color driver
  display.background = SEVERAL-DARK-GRAY

  sans10 := Font.get "sans10"
  sans12 := Font.get "sans12"

  element-text := Label --x=30 --y=20 --color=SEVERAL-ORANGE --text="to be set"
  element-text-2 := Label --x=180 --y=50 --color=SEVERAL-ORANGE --text="to be set" --font=sans12 --alignment=ALIGN-RIGHT
  element-text-3 := Label --x=96 --y=80 --color=SEVERAL-ORANGE --text="T 123 For the win" --font=sans10 --alignment=ALIGN-CENTER

  element-text.text = "Testing 123"
  element-text.font = sans10
  element-text-2.text = "123 Testing"
  element-text-2.font = sans10
  display.add element-text
  display.add element-text-2
  display.add element-text-3
  display.draw

  display.remove-all

  element-text.label = "Testing 42"
  element-text-2.label = "42 Testing"
  // The "MM" has the same pixel width as the "123" above, so we can test the
  // case where the ends are unchanged, but the middle changes.
  element-text-3.label = "T MM For the win"
  display.add element-text
  display.add element-text-2
  display.add element-text-3
  display.draw

  driver.write-png
