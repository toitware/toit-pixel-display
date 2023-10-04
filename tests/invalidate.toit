// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *
import pixel_display show *
import pixel_display.true_color show *

// Check that the minimal area is redrawn.
// All redraws are rounded to 8 pixels boundaries.

class AreaRememberingDriver extends AbstractDriver:
  width/int
  height/int
  flags ::= FLAG_TRUE_COLOR | FLAG_PARTIAL_UPDATES

  constructor .width .height:

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
  small_test
  large_test 56 500
  large_test 1280 640

small_test:
  driver := AreaRememberingDriver 128 64
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

large_test w h:
  driver := AreaRememberingDriver w h
  display := TrueColorPixelDisplay driver
  display.background = get_rgb 0 1 2

  display.draw

  expect_equals 0 driver.last_left
  expect_equals 0 driver.last_top
  expect_equals driver.width driver.last_right
  expect_equals (round_up driver.height 8) driver.last_bottom

  ctx := display.context --color=(get_rgb 255 120 0)

  set_random_seed "FORTY TWO"
  100.repeat:
    left := random driver.width
    top := random driver.height
    width := 1 + (random 200)
    height := 1 + (random 200)
    right := left + width
    bottom := top + height
    display.filled_rectangle ctx left top width height

    driver.reset
    display.draw

    right = min right driver.width
    bottom = min bottom (round_up driver.height 8)

    expect_equals (round_down left 8) driver.last_left
    expect_equals (round_down top 8) driver.last_top
    expect_equals (round_up right 8) driver.last_right
    expect_equals (round_up bottom 8) driver.last_bottom
