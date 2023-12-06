// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests for TextTexture that the change box is smaller when we only
// change part of the text.

import bitmap show *
import expect show *
import font show *
import pixel_display show *
import pixel_display.texture show *
import .png_visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := SeveralColorPngVisualizer 192 96 args[0] --outline=SEVERAL_WHITE
  display := SeveralColorPixelDisplay driver
  display.background = SEVERAL_DARK_GRAY

  sans10 := Font.get "sans10"

  ctx := display.context --landscape --color=SEVERAL_ORANGE --font=sans10

  texture_text := display.text ctx 30 20 "Testing 123"
  texture_text_2 := display.text (ctx.with --alignment=TEXT_TEXTURE_ALIGN_RIGHT) 180 50 "123 Testing"
  texture_text_3 := display.text (ctx.with --alignment=TEXT_TEXTURE_ALIGN_CENTER) 96 80 "T 123 For the win"
  display.draw

  texture_text.text = "Testing 42"
  texture_text_2.text = "42 Testing"
  // The "MM" has the same pixel width as the "123" above, so we can test the
  // case where the ends are unchanged, but the middle changes.
  texture_text_3.text = "T MM For the win"
  display.draw

  texture_text.text = "Test the West"
  texture_text_2.text = "Test the Folketing"
  texture_text_3.text = "Test * For the win"
  display.draw

  texture_text.text = "Test the West"
  texture_text_2.text = "Test the Folketïng"
  texture_text_3.text = "Test * For the win"  // Both ends move because its centered.
  display.draw

  driver.write_png
