// Copyright (C) 2020 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *

import bitmap show *
import crypto.sha1 as crypto
import font show *

import pixel_display.common show Transform
import pixel_display.four_gray
import pixel_display.two_bit_texture as two_bit
import pixel_display.three_color
import pixel_display.true_color
import pixel_display.two_color

THREE_COLOR ::= 0
TWO_COLOR ::= 1
FOUR_GRAY ::= 2
TRUE_COLOR ::= 3
VERSIONS := 4

skip_version version/int -> bool:
  if bitmap_primitives_present and version < TRUE_COLOR:
    return false
  if bytemap_primitives_present and version == TRUE_COLOR:
    return false
  return true

main:
  feature_detect
  test_simple_three_color
  test_simple_four_gray
  test_simple_two_color
  test_simple_true_color

bitmap_primitives_present := true
bytemap_primitives_present := true

feature_detect:
  e := catch:
    ba := ByteArray 25
    bytemap_blur ba 5 2
  if e == "UNIMPLEMENTED":
    bytemap_primitives_present = false
  e = catch:
    ba := ByteArray 16
    bitmap_rectangle 0 0 0 1 1 ba 16
  if e == "UNIMPLEMENTED":
    bitmap_primitives_present = false

identity ::= Transform.identity

orientation_to_transform x y orientation [block]:
  transform := null
  if orientation == ORIENTATION_0:
    transform = identity
  else:
    transform = Transform.identity.translate x y
    x = 0
    y = 0
    if orientation == ORIENTATION_90:
      transform = transform.rotate_right
    else if orientation == ORIENTATION_180:
      transform = transform.rotate_right.rotate_right
    else if orientation == ORIENTATION_270:
      transform = transform.rotate_left
  block.call x y transform

canvas_factory version w h x y:
  result := ?
  if version == THREE_COLOR:
    result = three_color.Canvas_ w h
  else if version == TWO_COLOR:
    result = two_color.Canvas_ w h
  else if version == FOUR_GRAY:
    result = four_gray.Canvas_ w h
  else:
    result = true_color.Canvas_ w h
  result.x_offset_ = x
  result.y_offset_ = y
  return result

test_simple_three_color:
  red_bg := three_color.RED

  // A little 8x8 canvas to draw on.
  canvas := three_color.Canvas_ 8 8

  // Fill the canvas with red.
  canvas.set_all_pixels red_bg

  8.repeat: | x | 8.repeat: | y |
    expect (canvas.get_pixel_ x y) == three_color.RED

test_simple_four_gray:
  // A little 8x8 canvas to draw on.
  canvas := four_gray.Canvas_ 8 8

  // Fill the canvas with light gray.
  canvas.set_all_pixels four_gray.LIGHT_GRAY

  8.repeat: | x | 8.repeat: | y |
    expect (canvas.get_pixel_ x y) == four_gray.LIGHT_GRAY

test_simple_two_color:
  // A little 8x8 canvas to draw on.
  canvas := two_color.Canvas_ 8 8

  8.repeat: | x | 8.repeat: | y |
    expect (canvas.get_pixel_ x y) == two_color.WHITE

  // Fill the canvas with black.
  canvas.set_all_pixels two_color.BLACK

  8.repeat: | x | 8.repeat: | y |
    expect (canvas.get_pixel_ x y) == two_color.BLACK

test_simple_true_color:
  bluish := true_color.get_rgb 0x12 0x34 0x56

  // A little 8x8 canvas to draw on.
  canvas := true_color.Canvas_ 8 8

  black := true_color.get_rgb 0 0 0

  8.repeat: | x | 8.repeat: | y |
    expect (canvas.get_pixel_ x y) == black

  // Fill the canvas with red.
  canvas.set_all_pixels bluish

  8.repeat: | x | 8.repeat: | y |
    expect (canvas.get_pixel_ x y) == bluish
