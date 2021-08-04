// Copyright (C) 2021 Toitware ApS.  All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import expect show *
import pixel_display show *
import pixel_display.true_color show *

// Check that the minimal area is redrawn.
// All redraws are rounded to 8 pixels boundaries.

class AreaRememberingDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_TRUE_COLOR | FLAG_PARTIAL_UPDATES

  static NOT_VALID_PLUS_  ::=  1000000
  static NOT_VALID_MINUS_ ::= -1000000

  last_left   := NOT_VALID_PLUS_
  last_top    := NOT_VALID_PLUS_
  last_right  := NOT_VALID_MINUS_
  last_bottom := NOT_VALID_MINUS_

  reset:
    last_left   = NOT_VALID_PLUS_
    last_top    = NOT_VALID_PLUS_
    last_right  = NOT_VALID_MINUS_
    last_bottom = NOT_VALID_MINUS_

  draw_true_color left/int top/int right/int bottom/int r/ByteArray g/ByteArray b/ByteArray -> none:
    last_left = min left last_left
    last_top = min top last_top
    last_right = max right last_right
    last_bottom = max bottom last_bottom

main:
  driver := AreaRememberingDriver
  display := TrueColorPixelDisplay driver
  display.background = get_rgb 0 1 2

  display.draw

  expect_equals 0 driver.last_left
  expect_equals 0 driver.last_top
  expect_equals driver.width driver.last_right
  expect_equals driver.height driver.last_bottom

  driver.reset
  
  ctx := display.context --landscape --color=(get_rgb 255 120 0)

  display.filled_rectangle ctx 16 24 32 40
  display.draw
  expect_equals 16 driver.last_left
  expect_equals 24 driver.last_top
  expect_equals 48 driver.last_right
  expect_equals 64 driver.last_bottom

  driver.reset

  display.filled_rectangle ctx 7 15 8 16
  display.draw

  expect_equals 0 driver.last_left
  expect_equals 8 driver.last_top
  expect_equals 16 driver.last_right
  expect_equals 32 driver.last_bottom

  driver.reset

  display.filled_rectangle ctx 9 17 8 16
  display.draw

  expect_equals 8 driver.last_left
  expect_equals 16 driver.last_top
  expect_equals 24 driver.last_right
  expect_equals 40 driver.last_bottom

  driver.reset

  display.filled_rectangle ctx 7 15 9 17
  display.draw

  expect_equals 0 driver.last_left
  expect_equals 8 driver.last_top
  expect_equals 16 driver.last_right
  expect_equals 32 driver.last_bottom
