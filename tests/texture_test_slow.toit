// Copyright (C) 2020 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *

import bitmap show *
import crypto.sha1 as crypto
import font show *

import pixel-display.common show Transform
import pixel-display.four-gray
import pixel-display.two-bit-texture as two-bit
import pixel-display.three-color
import pixel-display.true-color
import pixel-display.two-color

THREE-COLOR ::= 0
TWO-COLOR ::= 1
FOUR-GRAY ::= 2
TRUE-COLOR ::= 3
VERSIONS := 4

skip-version version/int -> bool:
  if bitmap-primitives-present and version < TRUE-COLOR:
    return false
  if bytemap-primitives-present and version == TRUE-COLOR:
    return false
  return true

main:
  feature-detect
  test-simple-three-color
  test-simple-four-gray
  test-simple-two-color
  test-simple-true-color

bitmap-primitives-present := true
bytemap-primitives-present := true

feature-detect:
  e := catch:
    ba := ByteArray 25
    bytemap-blur ba 5 2
  if e == "UNIMPLEMENTED":
    bytemap-primitives-present = false
  e = catch:
    ba := ByteArray 16
    bitmap-rectangle 0 0 0 1 1 ba 16
  if e == "UNIMPLEMENTED":
    bitmap-primitives-present = false

identity ::= Transform.identity

orientation-to-transform x y orientation [block]:
  transform := null
  if orientation == ORIENTATION-0:
    transform = identity
  else:
    transform = Transform.identity.translate x y
    x = 0
    y = 0
    if orientation == ORIENTATION-90:
      transform = transform.rotate-right
    else if orientation == ORIENTATION-180:
      transform = transform.rotate-right.rotate-right
    else if orientation == ORIENTATION-270:
      transform = transform.rotate-left
  block.call x y transform

canvas-factory version w h x y:
  result := ?
  if version == THREE-COLOR:
    result = three-color.Canvas_ w h
  else if version == TWO-COLOR:
    result = two-color.Canvas_ w h
  else if version == FOUR-GRAY:
    result = four-gray.Canvas_ w h
  else:
    result = true-color.Canvas_ w h
  result.x-offset_ = x
  result.y-offset_ = y
  return result

test-simple-three-color:
  red-bg := three-color.RED

  // A little 8x8 canvas to draw on.
  canvas := three-color.Canvas_ 8 8

  // Fill the canvas with red.
  canvas.set-all-pixels red-bg

  8.repeat: | x | 8.repeat: | y |
    expect (canvas.get-pixel_ x y) == three-color.RED

test-simple-four-gray:
  // A little 8x8 canvas to draw on.
  canvas := four-gray.Canvas_ 8 8

  // Fill the canvas with light gray.
  canvas.set-all-pixels four-gray.LIGHT-GRAY

  8.repeat: | x | 8.repeat: | y |
    expect (canvas.get-pixel_ x y) == four-gray.LIGHT-GRAY

test-simple-two-color:
  // A little 8x8 canvas to draw on.
  canvas := two-color.Canvas_ 8 8

  8.repeat: | x | 8.repeat: | y |
    expect (canvas.get-pixel_ x y) == two-color.WHITE

  // Fill the canvas with black.
  canvas.set-all-pixels two-color.BLACK

  8.repeat: | x | 8.repeat: | y |
    expect (canvas.get-pixel_ x y) == two-color.BLACK

test-simple-true-color:
  bluish := true-color.get-rgb 0x12 0x34 0x56

  // A little 8x8 canvas to draw on.
  canvas := true-color.Canvas_ 8 8

  black := true-color.get-rgb 0 0 0

  8.repeat: | x | 8.repeat: | y |
    expect (canvas.get-pixel_ x y) == black

  // Fill the canvas with red.
  canvas.set-all-pixels bluish

  8.repeat: | x | 8.repeat: | y |
    expect (canvas.get-pixel_ x y) == bluish
