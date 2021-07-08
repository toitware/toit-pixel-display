// Copyright (C) 2021 Toitware ApS.  All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import expect show *
import font show Font
import pixel_display show *
import pixel_display.two_color

class TwoColorDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_2_COLOR
  draw_two_color x/int y/int w/int h/int pixels/ByteArray -> none:

class ThreeColorDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_3_COLOR
  draw_two_bit x/int y/int w/int h/int plane0/ByteArray plane1/ByteArray -> none:

class FourGrayDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_4_COLOR
  draw_two_bit x/int y/int w/int h/int plane0/ByteArray plane1/ByteArray -> none:

class TrueColorDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_TRUE_COLOR
  draw_true_color x/int y/int w/int h/int r/ByteArray g/ByteArray b/ByteArray -> none:

main:
  driver2 := TwoColorDriver
  display2 := TwoColorPixelDisplay driver2
  
  driver3 := ThreeColorDriver
  display3 := ThreeColorPixelDisplay driver3

  driver4 := FourGrayDriver
  display4 := FourGrayPixelDisplay driver4

  driver_true := TrueColorDriver
  display_true := TrueColorPixelDisplay driver_true

  sans10 := Font.get "sans10"

  [display2, display3, display4, display_true].do: | display |
    ctx := display.context --landscape --font=sans10
    display.filled_rectangle ctx 10 20 30 40
    display.text ctx 50 20 "Testing"
    display.text ctx 50 40 "the display"
    display.text ctx 50 60 "for the win"
    display.draw
