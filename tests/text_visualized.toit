// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests for Label that the change box is smaller when we only
// change part of the text.

import bitmap show *
import expect show *
import font show *
import pixel_display show *
import pixel_display.element show *
import pixel_display.style show *
import .png_visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 192 96 args[0] --outline=SEVERAL_WHITE
  display := SeveralColorPixelDisplay driver
  display.background = SEVERAL_DARK_GRAY

  sans10 := Font.get "sans10"

  element_text := Label --x=30 --y=20 --color=SEVERAL_ORANGE --label="Testing 123" --font=sans10
  element_text_2 := Label --x=180 --y=50 --color=SEVERAL_ORANGE --label="123 Testing" --font=sans10 --alignment=ALIGN_RIGHT
  element_text_3 := Label --x=96 --y=80 --color=SEVERAL_ORANGE --label="T 123 For the win" --font=sans10 --alignment=ALIGN_CENTER
  display.add element_text
  display.add element_text_2
  display.add element_text_3
  display.draw

  element_text.label = "Testing 42"
  element_text_2.label = "42 Testing"
  // The "MM" has the same pixel width as the "123" above, so we can test the
  // case where the ends are unchanged, but the middle changes.
  element_text_3.label = "T MM For the win"
  display.draw

  element_text.label = "Test the West"
  element_text_2.label = "Test the Folketing"
  element_text_3.label = "Test * For the win"
  display.draw

  element_text.label = "Test the West"
  element_text_2.label = "Test the Folketlng"
  element_text_3.label = "Test * For the win"  // Both ends move because its centered.
  display.draw

  driver.write_png