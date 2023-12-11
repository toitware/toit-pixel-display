// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *
import font show Font
import pixel-display show *
import pixel-display.true-color show *

class TestDriver extends AbstractDriver:
  buffer := ByteArray 3 * 64 * 128

  width ::= 128
  height ::= 64
  flags ::= FLAG-TRUE-COLOR | FLAG-PARTIAL-UPDATES
  draw-true-color left/int top/int right/int bottom/int r/ByteArray g/ByteArray b/ByteArray -> none:
    w := right - left
    (bottom - top).repeat: | iy |
      w.repeat: | ix |
        buffer[0 + 3 * (left + ix + (top + iy) * width)] = r[ix + iy * w]
        buffer[1 + 3 * (left + ix + (top + iy) * width)] = g[ix + iy * w]
        buffer[2 + 3 * (left + ix + (top + iy) * width)] = b[ix + iy * w]

  red-at x y:
    return buffer[0 + 3 * (x + y * width)]

  green-at x y:
    return buffer[1 + 3 * (x + y * width)]

  blue-at x y:
    return buffer[2 + 3 * (x + y * width)]

main:
  driver := TestDriver
  display := PixelDisplay.true-color driver
  display.background = get-rgb 0 1 2

  sans10 := Font.get "sans10"

  ctx := display.context --landscape --color=(get-rgb 255 120 0) --font=sans10

  display.filled-rectangle ctx 10 20 30 40
  display.text ctx 50 20 "Testing"
  display.text ctx 50 40 "the display"
  display.draw
  display.text ctx 50 60 "for the win"

  display.draw

  for y := 0; y < driver.height; y += 2:
    line := ""
    driver.width.repeat: | x |
      top-half := (driver.red-at x y) < 128
      bottom-half := (driver.red-at x y + 1) < 128
      line += "$(top-half ? (bottom-half ? " " : "▄") : (bottom-half ? "▀" : "█"))"
    print line

  50.repeat: | x |
    driver.height.repeat: | y |
      if x < 10 or y < 20 or x >= 40 or y >= 60:
        expect-equals 0 (driver.red-at x y)
        expect-equals 1 (driver.green-at x y)
        expect-equals 2 (driver.blue-at x y)
      else:
        expect-equals 255 (driver.red-at x y)
        expect-equals 120 (driver.green-at x y)
        expect-equals 0 (driver.blue-at x y)
