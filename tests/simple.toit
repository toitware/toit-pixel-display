// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *
import font show Font
import pixel-display show *
import pixel-display.two-color
import pixel-display.true-color

class TwoColorDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG-2-COLOR
  draw-two-color left/int top/int right/int bottom/int pixels/ByteArray -> none:

class ThreeColorDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG-3-COLOR
  draw-two-bit left/int top/int right/int bottom/int plane0/ByteArray plane1/ByteArray -> none:

class FourGrayDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG-4-COLOR
  draw-two-bit left/int top/int right/int bottom/int plane0/ByteArray plane1/ByteArray -> none:

class TrueColorDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG-TRUE-COLOR
  draw-true-color left/int top/int right/int bottom/int r/ByteArray g/ByteArray b/ByteArray -> none:

class GrayScaleDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG-GRAY-SCALE
  draw-gray-scale left/int top/int right/int bottom/int pixels/ByteArray -> none:

class SeveralColorDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG-SEVERAL-COLOR
  draw-several-color left/int top/int right/int bottom/int pixels/ByteArray -> none:

class DrawRecordingDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG-TRUE-COLOR | FLAG-PARTIAL-UPDATES
  r-left := 0
  r-top := 0
  r-right := 0
  r-bottom := 0

  constructor:
    reset

  reset -> none:
    r-left = 1_000_000
    r-top = 1_000_000
    r-right = -1
    r-bottom = -1

  draw-true-color left/int top/int right/int bottom/int r/ByteArray g/ByteArray b/ByteArray -> none:
    r-left = min r-left left
    r-top = min r-top top
    r-right = max r-right right
    r-bottom = max r-bottom bottom

main:
  for-the-win-test
  invalidate-test

invalidate-test:
  driver := DrawRecordingDriver
  display := PixelDisplay.true-color driver

  context := display.context

  display.draw
  driver.reset

  print "Rectangle"
  display.filled-rectangle context 42 23 12 10
  display.draw

  expect-equals driver.r-left 40   // 42 rounded down.
  expect-equals driver.r-right 56  // 42 + 12 rounded up.
  expect-equals driver.r-top 16    // 23 rounded down.
  expect-equals driver.r-bottom 40 // 23 + 10 rounded up.

  driver.reset

  print "Window"

  window := true-color.SimpleWindow 42 23 22 20 context.transform
      0  // Border width.
      0  // Border color.
      0  // Background color.

  display.add window

  display.draw

  expect-equals driver.r-left 40   // 42 rounded down.
  expect-equals driver.r-right 64  // 42 + 22 rounded up.
  expect-equals driver.r-top 16    // 23 rounded down.
  expect-equals driver.r-bottom 48 // 23 + 20 rounded up.

  driver.reset

  // Place rectangle at window-relative coordinates.
  rect-in-window := true-color.FilledRectangle
      0  // Color.
      8  // x.
      0  // y.
      10 // w.
      1  // h.
      window.transform

  window.add rect-in-window

  display.draw

  expect-equals driver.r-left 48   // 42 + 8 rounded down.
  expect-equals driver.r-right 64  // 42 + 8 + 10 rounded up.
  expect-equals driver.r-top 16    // 23 + 0 rounded down.
  expect-equals driver.r-bottom 24 // 23 + 0 + 1 rounded up.

for-the-win-test:
  driver2 := TwoColorDriver
  display2 := PixelDisplay.two-color driver2

  driver3 := ThreeColorDriver
  display3 := PixelDisplay.three-color driver3

  driver4 := FourGrayDriver
  display4 := PixelDisplay.four-gray driver4

  driver-true := TrueColorDriver
  display-true := PixelDisplay.true-color driver-true

  driver-gray := GrayScaleDriver
  display-gray := PixelDisplay.gray-scale driver-gray

  driver-several := SeveralColorDriver
  display-several := PixelDisplay.several-color driver-several

  sans10 := Font.get "sans10"

  [display2, display3, display4, display-true, display-gray, display-several].do: | display |
    ctx := display.context --landscape --font=sans10
    display.filled-rectangle ctx 10 20 30 40
    display.text ctx 50 20 "Testing"
    display.text ctx 50 40 "the display"
    display.text ctx 50 60 "for the win"
    display.draw
