// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *
import font show Font
import pixel_display show *
import pixel_display.two_color
import pixel_display.true_color

class TwoColorDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_2_COLOR
  draw_two_color left/int top/int right/int bottom/int pixels/ByteArray -> none:

class ThreeColorDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_3_COLOR
  draw_two_bit left/int top/int right/int bottom/int plane0/ByteArray plane1/ByteArray -> none:

class FourGrayDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_4_COLOR
  draw_two_bit left/int top/int right/int bottom/int plane0/ByteArray plane1/ByteArray -> none:

class TrueColorDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_TRUE_COLOR
  draw_true_color left/int top/int right/int bottom/int r/ByteArray g/ByteArray b/ByteArray -> none:

class GrayScaleDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_GRAY_SCALE
  draw_gray_scale left/int top/int right/int bottom/int pixels/ByteArray -> none:

class SeveralColorDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_SEVERAL_COLOR
  draw_several_color left/int top/int right/int bottom/int pixels/ByteArray -> none:

class DrawRecordingDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_TRUE_COLOR | FLAG_PARTIAL_UPDATES
  r_left := 0
  r_top := 0
  r_right := 0
  r_bottom := 0

  constructor:
    reset

  reset -> none:
    r_left = 1_000_000
    r_top = 1_000_000
    r_right = -1
    r_bottom = -1

  draw_true_color left/int top/int right/int bottom/int r/ByteArray g/ByteArray b/ByteArray -> none:
    r_left = min r_left left
    r_top = min r_top top
    r_right = max r_right right
    r_bottom = max r_bottom bottom

main:
  for_the_win_test
  invalidate_test

invalidate_test:
  driver := DrawRecordingDriver
  display := TrueColorPixelDisplay driver

  context := display.context

  display.draw
  driver.reset

  print "Rectangle"
  display.filled_rectangle context 42 23 12 10
  display.draw

  expect_equals driver.r_left 40   // 42 rounded down.
  expect_equals driver.r_right 56  // 42 + 12 rounded up.
  expect_equals driver.r_top 16    // 23 rounded down.
  expect_equals driver.r_bottom 40 // 23 + 10 rounded up.

  driver.reset

  print "Window"

  window := true_color.SimpleWindow 42 23 22 20 context.transform
      0  // Border width.
      0  // Border color.
      0  // Background color.

  display.add window

  display.draw

  expect_equals driver.r_left 40   // 42 rounded down.
  expect_equals driver.r_right 64  // 42 + 22 rounded up.
  expect_equals driver.r_top 16    // 23 rounded down.
  expect_equals driver.r_bottom 48 // 23 + 20 rounded up.

  driver.reset

  // Place rectangle at window-relative coordinates.
  rect_in_window := true_color.FilledRectangle
      0  // Color.
      8  // x.
      0  // y.
      10 // w.
      1  // h.
      window.transform

  window.add rect_in_window

  display.draw

  expect_equals driver.r_left 48   // 42 + 8 rounded down.
  expect_equals driver.r_right 64  // 42 + 8 + 10 rounded up.
  expect_equals driver.r_top 16    // 23 + 0 rounded down.
  expect_equals driver.r_bottom 24 // 23 + 0 + 1 rounded up.

for_the_win_test:
  driver2 := TwoColorDriver
  display2 := TwoColorPixelDisplay driver2

  driver3 := ThreeColorDriver
  display3 := ThreeColorPixelDisplay driver3

  driver4 := FourGrayDriver
  display4 := FourGrayPixelDisplay driver4

  driver_true := TrueColorDriver
  display_true := TrueColorPixelDisplay driver_true

  driver_gray := GrayScaleDriver
  display_gray := GrayScalePixelDisplay driver_gray

  driver_several := SeveralColorDriver
  display_several := SeveralColorPixelDisplay driver_several

  sans10 := Font.get "sans10"

  [display2, display3, display4, display_true, display_gray, display_several].do: | display |
    ctx := display.context --landscape --font=sans10
    display.filled_rectangle ctx 10 20 30 40
    display.text ctx 50 20 "Testing"
    display.text ctx 50 40 "the display"
    display.text ctx 50 60 "for the win"
    display.draw
