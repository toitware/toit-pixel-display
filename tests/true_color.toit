// Copyright (C) 2021 Toitware ApS.  All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import expect show *
import font show Font
import pixel_display show *
import pixel_display.true_color show *

class TestDriver extends AbstractDriver:
  buffer := ByteArray 3 * 64 * 128

  width ::= 128
  height ::= 64
  flags ::= FLAG_TRUE_COLOR | FLAG_PARTIAL_UPDATES
  draw_true_color left/int top/int right/int bottom/int r/ByteArray g/ByteArray b/ByteArray -> none:
    w := right - left
    (bottom - top).repeat: | iy |
      w.repeat: | ix |
        buffer[0 + 3 * (left + ix + (top + iy) * width)] = r[ix + iy * w]
        buffer[1 + 3 * (left + ix + (top + iy) * width)] = g[ix + iy * w]
        buffer[2 + 3 * (left + ix + (top + iy) * width)] = b[ix + iy * w]

  red_at x y:
    return buffer[0 + 3 * (x + y * width)]

  green_at x y:
    return buffer[1 + 3 * (x + y * width)]

  blue_at x y:
    return buffer[2 + 3 * (x + y * width)]

main:
  driver := TestDriver
  display := TrueColorPixelDisplay driver
  display.background = get_rgb 0 1 2
  
  sans10 := Font.get "sans10"

  ctx := display.context --landscape --color=(get_rgb 255 120 0) --font=sans10

  display.filled_rectangle ctx 10 20 30 40
  display.text ctx 50 20 "Testing"
  display.text ctx 50 40 "the display"
  display.draw
  display.text ctx 50 60 "for the win"

  display.draw

  driver.height.repeat: | y |
    line := ""
    driver.width.repeat: | x |
      line += "$((driver.red_at x y) < 128 ? " " : "*")"
    print line
      
  50.repeat: | x |
    driver.height.repeat: | y |
      if x < 10 or y < 20 or x >= 40 or y >= 60:
        expect_equals 0 (driver.red_at x y)
        expect_equals 1 (driver.green_at x y)
        expect_equals 2 (driver.blue_at x y)
      else:
        expect_equals 255 (driver.red_at x y)
        expect_equals 120 (driver.green_at x y)
        expect_equals 0 (driver.blue_at x y)
