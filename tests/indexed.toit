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

  reddish x y:
    return (red_at x y) > (green_at x y) * 2 and (red_at x y) > (blue_at x y) * 2

  yellowish x y:
    return (red_at x y) > (blue_at x y) * 2 and (green_at x y) > (blue_at x y) * 2

  pinkish x y:
    return (red_at x y) > 224 and 128 <= (green_at x y) <= 200 and 128 <= (blue_at x y) <= 200

main:
  driver := TestDriver
  display := TrueColorPixelDisplay driver
  display.background = get_rgb 0 1 2

  ctx := display.context --landscape --color=(get_rgb 255 120 0)
  ctx2 := display.context --landscape=false --color=(get_rgb 255 120 0)

  display.filled_rectangle ctx 10 20 30 40

  image := IndexedPixmapTexture 10 20 40 24 ctx.transform
  display.add image
  image2 := IndexedPixmapTexture 10 20 40 24 ctx2.transform
  display.add image2
  red := image.allocate_color 255 0 0
  image2.allocate_color 255 0 0
  pink := image.allocate_color 255 192 192
  image2.allocate_color 255 192 192
  yellow := image.allocate_color 255 255 0
  image2.allocate_color 255 255 0

  10.repeat:
    x := random 1 39
    y := random 2 22
    c := random 1 4
    image.set_pixel x+1 y c
    image.set_pixel x y-2 c
    image.set_pixel x y-1 c
    image.set_pixel x-1 y c
    image.set_pixel x y+1 c
    image.set_pixel x y+1 c
    image2.set_pixel x+1 y c
    image2.set_pixel x y-2 c
    image2.set_pixel x y-1 c
    image2.set_pixel x-1 y c
    image2.set_pixel x y+1 c
    image2.set_pixel x y+1 c

  for x := 11; x < 50; x++:
    display.draw
    p driver

    sleep --ms=30

    image.move_to x 20
    image2.move_to x 20

p driver:
  driver.height.repeat: | y |
    line := ""
    driver.width.repeat: | x |
      if driver.reddish x y:
        line += "r"
      else if driver.yellowish x y:
        line += "y"
      else if driver.pinkish x y:
        line += "p"
      else:
        line += " "
    print line
