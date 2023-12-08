// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import font show Font

import .common
import .element show CustomElement Element
import .style

EAN_13_QUIET_ZONE_WIDTH ::= 9
EAN_13_START_WIDTH ::= 3
EAN_13_MIDDLE_WIDTH ::= 5
EAN_13_DIGIT_WIDTH ::= 7
EAN_13_BOTTOM_SPACE ::= 5
EAN_13_WIDTH ::= 2 * EAN_13_QUIET_ZONE_WIDTH + 2 * EAN_13_START_WIDTH + EAN_13_MIDDLE_WIDTH + 12 * EAN_13_DIGIT_WIDTH
EAN_13_HEIGHT ::= 83
// Encoding of L digits.  R digits are the bitwise-not of this and G digits are
// the R digits in reverse order.
EAN_13_L_CODES_ ::= [0x0d, 0x19, 0x13, 0x3d, 0x23, 0x31, 0x2f, 0x3b, 0x37, 0x0b]
EAN_13_G_CODES_ ::= [0x27, 0x33, 0x1b, 0x21, 0x1d, 0x39, 0x05, 0x11, 0x09, 0x17]
// Encoding of the first (invisible) digit.
EAN_13_FIRST_CODES_ ::= [0x00, 0x0b, 0x0d, 0x0e, 0x13, 0x19, 0x1c, 0x15, 0x16, 0x1a]

/// Element that draws a standard EAN-13 bar code.
class BarCodeEanElement extends CustomElement:
  color_/int? := 0
  background_ := 0xff
  sans10_ ::= Font.get "sans10"
  number_height_ := EAN_13_BOTTOM_SPACE

  type -> string: return "bar-code-ean"

  set_attribute_ key/string value -> none:
    if key == "color":
      if color_ != value:
        invalidate
        color_ = value
    else:
      super key value

  code_/string := ?  // 13 digit code as a string.

  code= value/string -> none:
    if value != code_: invalidate
    code_ = value

  code -> string: return code_

  /**
  $code_: The 13 digit product code.
  $x: The left edge of the barcode in the coordinate system of the transform.
  $y: The top edge of the barcode in the coordinate system of the transform.
  Use $set_styles to set the background to white and the color to black.
  See $Element.constructor for the other parameters.
  */
  constructor
      --x/int?=null
      --y/int?=null
      --style/Style?=null
      --element_class/string?=null
      --classes/List?=null
      --id/string?=null
      --background=null
      --border/Border?=null
      --code/string:
    // The numbers go below the bar code in a way that depends on the size
    // of the digits, so we need to take that into account when calculating
    // the bounding box.
    code_ = code
    number_height_ = (sans10_.text_extent "8")[1]
    height := EAN_13_HEIGHT + number_height_ - EAN_13_BOTTOM_SPACE
    w := EAN_13_WIDTH
    h := height + 1
    super
        --x = x
        --y = y
        --w = w
        --h = h
        --style = style
        --element_class = element_class
        --classes = classes
        --id = id
        --background = background
        --border = border

  l_ digit:
    return EAN_13_L_CODES_[digit & 0xf]

  g_ digit:
    return EAN_13_G_CODES_[digit & 0xf]

  r_ digit:
    return (l_ digit) ^ 0x7f

  // Make a white background behind the bar code and draw the digits along the
  // bottom.
  draw_text_ canvas/Canvas:
    // Bar code coordinates.
    text_x := EAN_13_QUIET_ZONE_WIDTH + EAN_13_START_WIDTH
    text_y := EAN_13_HEIGHT + number_height_ - EAN_13_BOTTOM_SPACE + 1

    canvas.text 1 text_y --text=code_[..1] --color=color_ --font=sans10_

    code_[1..7].split "":
      if it != "":
        canvas.text text_x text_y --text=it --color=color_ --font=sans10_
        text_x += EAN_13_DIGIT_WIDTH
    text_x += EAN_13_MIDDLE_WIDTH - 1
    code_[7..13].split "":
      if it != "":
        canvas.text text_x text_y --text=it --color=color_ --font=sans10_
        text_x += EAN_13_DIGIT_WIDTH
    marker_width := (sans10_.text_extent ">")[0]
    text_x += EAN_13_START_WIDTH + EAN_13_QUIET_ZONE_WIDTH - marker_width
    canvas.text text_x text_y --text=">" --color=color_ --font=sans10_

  // Redraw routine.
  custom_draw canvas/Canvas:
    draw_text_ canvas

    x := EAN_13_QUIET_ZONE_WIDTH
    long_height := EAN_13_HEIGHT
    short_height := EAN_13_HEIGHT - EAN_13_BOTTOM_SPACE
    // Start bars: 101.
    canvas.rectangle x     0 --w=1 --h=long_height --color=color_
    canvas.rectangle x + 2 0 --w=1 --h=long_height --color=color_
    x += 3
    first_code := EAN_13_FIRST_CODES_[code_[0] & 0xf]
    // Left digits using the L or G mapping.
    for i := 1; i < 7; i++:
      digit := code_[i]
      code := ((first_code >> (6 - i)) & 1) == 0 ? (l_ digit) : (g_ digit)
      for b := 6; b >= 0; b--:
        if ((1 << b) & code) != 0:
          canvas.rectangle x 0 --w=1 --h=short_height --color=color_
        x++
    // Middle bars: 01010
    canvas.rectangle x + 1 0 --w=1 --h=long_height --color=color_
    canvas.rectangle x + 3 0 --w=1 --h=long_height --color=color_
    x += 5
    // Left digits using the R mapping.
    for i := 7; i < 13; i++:
      digit := code_[i]
      code := r_ digit
      for b := 6; b >= 0; b--:
        if ((1 << b) & code) != 0:
          canvas.rectangle x 0 --w=1 --h=short_height --color=color_
        x++
    // End bars: 101.
    canvas.rectangle x     0 --w=1 --h=long_height --color=color_
    canvas.rectangle x + 2 0 --w=1 --h=long_height --color=color_
