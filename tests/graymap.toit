// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *
import font show Font
import pixel_display show *
import pixel_display.gray_scale show *

class TestDriver extends AbstractDriver:
  buffer := ByteArray 3 * 64 * 128

  width ::= 128
  height ::= 64
  flags ::= FLAG_GRAY_SCALE | FLAG_PARTIAL_UPDATES
  draw_gray_scale left/int top/int right/int bottom/int pixels/ByteArray -> none:
    w := right - left
    (bottom - top).repeat: | iy |
      w.repeat: | ix |
        buffer[left + ix + (top + iy) * width] = pixels[ix + iy * w]

  brightness_at x y:
    return buffer[x + y * width]

main:
  driver := TestDriver
  display := GrayScalePixelDisplay driver
  display.background = 0

  ctx := display.context --landscape --color=64
  ctx2 := display.context --landscape=false --color=64

  display.filled_rectangle ctx 10 20 30 40

  image := PixmapTexture 10 20 40 24 ctx.transform
  display.add image
  image2 := PixmapTexture 10 20 40 24 ctx2.transform
  display.add image2

  10.repeat:
    x := random 1 39
    y := random 2 22
    c := random 256
    image.set_pixel (x + 1) y c
    image.set_pixel x (y - 2) c
    image.set_pixel x (y - 1) c
    image.set_pixel (x - 1) y c
    image.set_pixel x (y + 1) c
    image.set_pixel x (y + 1) c
    image2.set_pixel (x + 1) y c
    image2.set_pixel x (y - 2) c
    image2.set_pixel x (y - 1) c
    image2.set_pixel (x - 1) y c
    image2.set_pixel x (y + 1) c
    image2.set_pixel x (y + 1) c

  for x := 11; x < 50; x++:
    display.draw
    p driver

    sleep --ms=40

    image.move_to x 20
    image2.move_to x 20

p driver:
  driver.height.repeat: | y |
    line := ""
    driver.width.repeat: | x |
      br := driver.brightness_at x y
      if br == 64:
        line += "-"
      else if br < 64:
        line += " "
      else if br > 192:
        line += "@"
      else:
        line += "#"
    print line
