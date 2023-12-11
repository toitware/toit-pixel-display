// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *
import font show Font
import pixel-display show *
import pixel-display.gray-scale show *

class TestDriver extends AbstractDriver:
  buffer := ByteArray 64 * 128

  width ::= 128
  height ::= 64
  flags ::= FLAG-GRAY-SCALE | FLAG-PARTIAL-UPDATES
  draw-gray-scale left/int top/int right/int bottom/int pixels/ByteArray -> none:
    w := right - left
    (bottom - top).repeat: | iy |
      w.repeat: | ix |
        buffer[left + ix + (top + iy) * width] = pixels[ix + iy * w]

  pixel-at x y:
    return buffer[x + y * width]

main:
  driver := TestDriver
  display := PixelDisplay.gray-scale driver
  display.background = 1

  sans10 := Font.get "sans10"

  ctx := display.context --landscape --color=250 --font=sans10

  display.filled-rectangle ctx 10 20 30 40
  display.text ctx 50 20 "Testing"
  display.text ctx 50 40 "the display"
  display.draw
  display.text ctx 50 60 "for the win"

  display.draw

  for y := 0; y < driver.height; y += 2:
    line := ""
    driver.width.repeat: | x |
      top-half := (driver.pixel-at x y) < 128
      bottom-half := (driver.pixel-at x y + 1) < 128
      line += "$(top-half ? (bottom-half ? " " : "▄") : (bottom-half ? "▀" : "█"))"
    print line

  50.repeat: | x |
    driver.height.repeat: | y |
      if x < 10 or y < 20 or x >= 40 or y >= 60:
        expect-equals 1 (driver.pixel-at x y)
      else:
        expect-equals 250 (driver.pixel-at x y)
