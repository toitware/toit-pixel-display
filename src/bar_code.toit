// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import font show Font

import .element show CustomElement Element
import .pixel-display
import .style

EAN-13-QUIET-ZONE-WIDTH ::= 9
EAN-13-START-WIDTH ::= 3
EAN-13-MIDDLE-WIDTH ::= 5
EAN-13-DIGIT-WIDTH ::= 7
EAN-13-BOTTOM-SPACE ::= 5
EAN-13-WIDTH ::= 2 * EAN-13-QUIET-ZONE-WIDTH + 2 * EAN-13-START-WIDTH + EAN-13-MIDDLE-WIDTH + 12 * EAN-13-DIGIT-WIDTH
EAN-13-HEIGHT ::= 83
// Encoding of L digits.  R digits are the bitwise-not of this and G digits are
// the R digits in reverse order.
EAN-13-L-CODES_ ::= [0x0d, 0x19, 0x13, 0x3d, 0x23, 0x31, 0x2f, 0x3b, 0x37, 0x0b]
EAN-13-G-CODES_ ::= [0x27, 0x33, 0x1b, 0x21, 0x1d, 0x39, 0x05, 0x11, 0x09, 0x17]
// Encoding of the first (invisible) digit.
EAN-13-FIRST-CODES_ ::= [0x00, 0x0b, 0x0d, 0x0e, 0x13, 0x19, 0x1c, 0x15, 0x16, 0x1a]

/// Element that draws a standard EAN-13 bar code.
class BarCodeEanElement extends CustomElement:
  color_/int? := 0
  background_ := 0xff
  sans10_ ::= Font.get "sans10"
  number-height_ := EAN-13-BOTTOM-SPACE

  type -> string: return "bar-code-ean"

  set-attribute_ key/string value -> none:
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
  Constructs a new bar code element.
  $code_: The 13 digit product code.
  $x: The left edge of the barcode in the coordinate system of the transform.
  $y: The top edge of the barcode in the coordinate system of the transform.
  Use $set-styles to set the background to white and the color to black.
  See $Element.constructor for the other parameters.
  */
  constructor
      --code/string
      --x/int?=null
      --y/int?=null
      --style/Style?=null
      --classes/List?=null
      --id/string?=null
      --background=null
      --border/Border?=null:
    // The numbers go below the bar code in a way that depends on the size
    // of the digits, so we need to take that into account when calculating
    // the bounding box.
    code_ = code
    number-height_ = (sans10_.text-extent "8")[1]
    height := EAN-13-HEIGHT + number-height_ - EAN-13-BOTTOM-SPACE
    w := EAN-13-WIDTH
    h := height + 1
    super
        --x = x
        --y = y
        --w = w
        --h = h
        --style = style
        --classes = classes
        --id = id
        --background = background
        --border = border

  l_ digit:
    return EAN-13-L-CODES_[digit & 0xf]

  g_ digit:
    return EAN-13-G-CODES_[digit & 0xf]

  r_ digit:
    return (l_ digit) ^ 0x7f

  // Make a white background behind the bar code and draw the digits along the
  // bottom.
  draw-text_ canvas/Canvas:
    // Bar code coordinates.
    text-x := EAN-13-QUIET-ZONE-WIDTH + EAN-13-START-WIDTH
    text-y := EAN-13-HEIGHT + number-height_ - EAN-13-BOTTOM-SPACE + 1

    canvas.text 1 text-y --text=code_[..1] --color=color_ --font=sans10_

    code_[1..7].split "":
      if it != "":
        canvas.text text-x text-y --text=it --color=color_ --font=sans10_
        text-x += EAN-13-DIGIT-WIDTH
    text-x += EAN-13-MIDDLE-WIDTH - 1
    code_[7..13].split "":
      if it != "":
        canvas.text text-x text-y --text=it --color=color_ --font=sans10_
        text-x += EAN-13-DIGIT-WIDTH
    marker-width := (sans10_.text-extent ">")[0]
    text-x += EAN-13-START-WIDTH + EAN-13-QUIET-ZONE-WIDTH - marker-width
    canvas.text text-x text-y --text=">" --color=color_ --font=sans10_

  // Redraw routine.
  custom-draw canvas/Canvas:
    draw-text_ canvas

    x := EAN-13-QUIET-ZONE-WIDTH
    long-height := EAN-13-HEIGHT
    short-height := EAN-13-HEIGHT - EAN-13-BOTTOM-SPACE
    // Start bars: 101.
    canvas.rectangle x     0 --w=1 --h=long-height --color=color_
    canvas.rectangle x + 2 0 --w=1 --h=long-height --color=color_
    x += 3
    first-code := EAN-13-FIRST-CODES_[code_[0] & 0xf]
    // Left digits using the L or G mapping.
    for i := 1; i < 7; i++:
      digit := code_[i]
      code := ((first-code >> (6 - i)) & 1) == 0 ? (l_ digit) : (g_ digit)
      for b := 6; b >= 0; b--:
        if ((1 << b) & code) != 0:
          canvas.rectangle x 0 --w=1 --h=short-height --color=color_
        x++
    // Middle bars: 01010
    canvas.rectangle x + 1 0 --w=1 --h=long-height --color=color_
    canvas.rectangle x + 3 0 --w=1 --h=long-height --color=color_
    x += 5
    // Left digits using the R mapping.
    for i := 7; i < 13; i++:
      digit := code_[i]
      code := r_ digit
      for b := 6; b >= 0; b--:
        if ((1 << b) & code) != 0:
          canvas.rectangle x 0 --w=1 --h=short-height --color=color_
        x++
    // End bars: 101.
    canvas.rectangle x     0 --w=1 --h=long-height --color=color_
    canvas.rectangle x + 2 0 --w=1 --h=long-height --color=color_
