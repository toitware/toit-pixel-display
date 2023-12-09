// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *
import pixel-display show *
import pixel-display.true-color show *

// Check that the minimal area is redrawn.
// All redraws are rounded to 8 pixels boundaries.

class AreaRememberingDriver extends AbstractDriver:
  width/int
  height/int
  flags ::= FLAG-TRUE-COLOR | FLAG-PARTIAL-UPDATES

  constructor .width .height:

  static NOT-VALID-PLUS_  ::=  1000000
  static NOT-VALID-MINUS_ ::= -1000000

  last-left   := NOT-VALID-PLUS_
  last-top    := NOT-VALID-PLUS_
  last-right  := NOT-VALID-MINUS_
  last-bottom := NOT-VALID-MINUS_

  reset:
    last-left   = NOT-VALID-PLUS_
    last-top    = NOT-VALID-PLUS_
    last-right  = NOT-VALID-MINUS_
    last-bottom = NOT-VALID-MINUS_

  draw-true-color left/int top/int right/int bottom/int r/ByteArray g/ByteArray b/ByteArray -> none:
    last-left = min left last-left
    last-top = min top last-top
    last-right = max right last-right
    last-bottom = max bottom last-bottom

main:
  small-test
  large-test 56 500
  large-test 1280 640

small-test:
  driver := AreaRememberingDriver 128 64
  display := PixelDisplay.true-color driver
  display.background = get-rgb 0 1 2

  display.draw

  expect-equals 0 driver.last-left
  expect-equals 0 driver.last-top
  expect-equals driver.width driver.last-right
  expect-equals driver.height driver.last-bottom

  driver.reset

  ctx := display.context --landscape --color=(get-rgb 255 120 0)

  display.filled-rectangle ctx 16 24 32 40
  display.draw
  expect-equals 16 driver.last-left
  expect-equals 24 driver.last-top
  expect-equals 48 driver.last-right
  expect-equals 64 driver.last-bottom

  driver.reset

  display.filled-rectangle ctx 7 15 8 16
  display.draw

  expect-equals 0 driver.last-left
  expect-equals 8 driver.last-top
  expect-equals 16 driver.last-right
  expect-equals 32 driver.last-bottom

  driver.reset

  display.filled-rectangle ctx 9 17 8 16
  display.draw

  expect-equals 8 driver.last-left
  expect-equals 16 driver.last-top
  expect-equals 24 driver.last-right
  expect-equals 40 driver.last-bottom

  driver.reset

  display.filled-rectangle ctx 7 15 9 17
  display.draw

  expect-equals 0 driver.last-left
  expect-equals 8 driver.last-top
  expect-equals 16 driver.last-right
  expect-equals 32 driver.last-bottom

large-test w h:
  driver := AreaRememberingDriver w h
  display := PixelDisplay.true-color driver
  display.background = get-rgb 0 1 2

  display.draw

  expect-equals 0 driver.last-left
  expect-equals 0 driver.last-top
  expect-equals driver.width driver.last-right
  expect-equals (round-up driver.height 8) driver.last-bottom

  ctx := display.context --color=(get-rgb 255 120 0)

  set-random-seed "FORTY TWO"
  100.repeat:
    left := random driver.width
    top := random driver.height
    width := 1 + (random 200)
    height := 1 + (random 200)
    right := left + width
    bottom := top + height
    display.filled-rectangle ctx left top width height

    driver.reset
    display.draw

    right = min right driver.width
    bottom = min bottom (round-up driver.height 8)

    expect-equals (round-down left 8) driver.last-left
    expect-equals (round-down top 8) driver.last-top
    expect-equals (round-up right 8) driver.last-right
    expect-equals (round-up bottom 8) driver.last-bottom
