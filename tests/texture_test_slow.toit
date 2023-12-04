// Copyright (C) 2020 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *

import bitmap show *
import crypto.sha1 as crypto
import font show *
import pixel_display.histogram show *
import pixel_display.texture show *

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
  barcode_test
  test_simple_three_color
  test_simple_four_gray
  test_simple_two_color
  test_simple_true_color
  test_simple_scene
  test_with_transparency
  composite_test
  test_bounding_box

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

filled_rectangle_factory version color x y w h:
  if version == THREE_COLOR:
    return three_color.FilledRectangle color x y w h identity
  else if version == TWO_COLOR:
    return two_color.FilledRectangle color x y w h identity
  else if version == FOUR_GRAY:
    return four_gray.FilledRectangle color x y w h identity
  else:
    return true_color.FilledRectangle color x y w h identity

bitmap_texture_factory version x y orientation w h color:
  orientation_to_transform x y orientation: | x y transform |
    if version == THREE_COLOR:
      return three_color.BitmapTexture x y w h transform color
    else if version == TWO_COLOR:
      return two_color.BitmapTexture x y w h transform color
    else if version == FOUR_GRAY:
      return four_gray.BitmapTexture x y w h transform color
    else:
      return true_color.BitmapTexture x y w h transform color
  unreachable

opaque_bitmap_texture_factory version x y w h foreground background:
  if version == THREE_COLOR:
    return three_color.OpaqueBitmapTexture x y w h identity foreground background
  else if version == TWO_COLOR:
    return two_color.OpaqueBitmapTexture x y w h identity foreground background
  else if version == FOUR_GRAY:
    return four_gray.OpaqueBitmapTexture x y w h identity foreground background
  else:
    return true_color.OpaqueBitmapTexture x y w h identity foreground background

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

text_texture_factory version x y orientation alignment text font color:
  orientation_to_transform x y orientation: | x y transform |
    if version == THREE_COLOR:
      return three_color.TextTexture x y transform alignment text font color
    else if version == TWO_COLOR:
      return two_color.TextTexture x y transform alignment text font color
    else if version == FOUR_GRAY:
      return four_gray.TextTexture x y transform alignment text font color
    else:
      return true_color.TextTexture x y transform alignment text font color
  unreachable

barcode_factory version code x y orientation:
  orientation_to_transform x y orientation: | x y transform |
    if version == THREE_COLOR:
      return three_color.BarCodeEan13 code x y transform
    else if version == TWO_COLOR:
      return two_color.BarCodeEan13 code x y transform
    else if version == FOUR_GRAY:
      return four_gray.BarCodeEan13 code x y transform
    else:
      return true_color.BarCodeEan13 code x y transform
  unreachable

histogram_factory version x y w h color orientation:
  orientation_to_transform x y orientation: | x y transform |
    texture := null
    reflected := (random 2) == 0 ? false : true
    if version == THREE_COLOR:
      texture = ThreeColorHistogram --x=x --y=y --width=w --height=h --transform=transform --scale=0.4 --color=color --reflected=reflected
    else if version == TWO_COLOR:
      texture = TwoColorHistogram --x=x --y=y --width=w --height=h --transform=transform --scale=0.4 --color=color --reflected=reflected
    else if version == FOUR_GRAY:
      texture = FourGrayHistogram --x=x --y=y --width=w --height=h --transform=transform --scale=0.4 --color=color --reflected=reflected
    else if version == TRUE_COLOR:
      texture = TrueColorHistogram --x=x --y=y --width=w --height=h --transform=transform --scale=0.4 --color=color --reflected=reflected
    40.repeat:
      texture.add (random 0 100) - 20
    return texture
  unreachable

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

test_simple_scene:
  // The scene has an 8x8 red square at 0, 0.
  VERSIONS.repeat: | version |
    if skip_version version: continue.repeat
    red_square := bitmap_texture_factory version 0 0 ORIENTATION_0 8 8 (get_red version)

    8.repeat: | x | 8.repeat: | y | red_square.set_pixel x y

    // Render the scene onto some canvases.
    8.repeat: | square_x | 8.repeat: | square_y |
      red_square.move_to square_x square_y
      // The canvas is always 8-aligned relative to the scene.
      3.repeat: | xi | 3.repeat: | yi |
        x := (xi - 1) * 8
        y := (yi - 1) * 8
        canvas := canvas_factory version 16 16 (x - 8) (y - 8)
        // The canvas is placed in various places and we render our scene onto it.
        red_square.write canvas
        // Check there is a red square on the canvas from 8-x,8-y to 16-x,16-y
        16.repeat: | x2 | 16.repeat: | y2 |
          if 8 - x + square_x <= x2 < 16 - x + square_x and 8 - y + square_y <= y2 < 16 - y + square_y:
            expect (canvas.get_pixel_ x2 y2) == (get_red version)
          else:
            expect (canvas.get_pixel_ x2 y2) == 0

hash := crypto.sha1 "Toitware!"

pseudo_random x:
  mod := hash.size << 3
  x %= mod
  if x < 0: x += mod
  return hash[x >> 3] & (1 << (x & 7)) != 0

test_with_transparency:
  if not bitmap_primitives_present: return
  // The scene has a noisy 8x8 image, initially at 0,0. Some pixels are black, others are transparent.
  prime_image := three_color.BitmapTexture 0 0 8 8 Transform.identity three_color.BLACK
  8.repeat: | x | 8.repeat: | y |
    if (pseudo_random y * 8 + x):
      prime_image.set_pixel x y
    else:
      prime_image.clear_pixel x y

  // The scene has a red circle, centered on 6,6, under the noisy 8x8 image.  Outside the circle is transparency.
  red_circle := three_color.BitmapTexture 0 0 12 16 Transform.identity three_color.RED
  12.repeat: | x | 16.repeat: | y |
    r2 := (x - 6) * (x - 6) + (y - 6) * (y - 6)
    if r2 > 36:
      red_circle.clear_pixel x y
    else:
      red_circle.set_pixel x y

  // Render the scene onto some canvases.
  8.repeat: | texture_x | 8.repeat: | texture_y |
    // The prime numbers illustration moves down to the right, and the red circle goes the other way.
    prime_image.move_to texture_x texture_y
    red_circle.move_to (8 - texture_x) (8 - texture_y)
    // The canvas is always 8-aligned relative to the scene.
    3.repeat: | xi | 3.repeat: | yi |
      x := (xi - 1) * 8
      y := (yi - 1) * 8
      canvas := three_color.Canvas_ 16 16  // Starts off white.
      canvas.x_offset_ = x
      canvas.y_offset_ = y
      // The canvas is placed in various places (8-aligned) and we render our scene onto it.
      red_circle.write canvas
      prime_image.write canvas

      // Check the scene rendered right onto the canvas.
      16.repeat: | x2 | 16.repeat: | y2 |
        scene_x := x2 + x
        scene_y := y2 + y
        prime_x := scene_x - texture_x
        prime_y := scene_y - texture_y
        if 0 <= prime_x < 8 and 0 <= prime_y < 8 and pseudo_random prime_y * 8 + prime_x:
          expect (canvas.get_pixel_ x2 y2) == three_color.BLACK
        else:
          circle_x := scene_x - 8 + texture_x
          circle_y := scene_y - 8 + texture_y
          if 0 <= circle_x < red_circle.w_ and 0 <= circle_y < red_circle.h_:
            if (red_circle.pixel_is_set circle_x circle_y):
              expect (canvas.get_pixel_ x2 y2) == three_color.RED
            else:
              expect (canvas.get_pixel_ x2 y2) == three_color.WHITE  // Initial color of canvas.

get_white version:
  if version == THREE_COLOR:
    return three_color.WHITE
  if version == TWO_COLOR:
    return two_color.WHITE
  if version == FOUR_GRAY:
    return four_gray.WHITE
  return true_color.get_rgb 0xff 0xff 0xff

get_black version:
  if version == THREE_COLOR:
    return three_color.BLACK
  if version == TWO_COLOR:
    return two_color.BLACK
  if version == FOUR_GRAY:
    return four_gray.BLACK
  return true_color.get_rgb 0 0 0

get_red version:
  if version == THREE_COLOR:
    return three_color.RED
  if version == TWO_COLOR:
    return two_color.BLACK  // No red on two-color
  if version == FOUR_GRAY:
    return four_gray.DARK_GRAY  // No red on four-gray
  return true_color.get_rgb 0xff 0 0

bullseye_get_color version x y:
  r2 := (x - 6.5) * (x - 6.5) + (y - 6.5) * (y - 6.5)
  if r2 < 42:
    if r2 < 11:
      return false   // Transparent in center
    else:
      return true    // Colored ring
  else:
    return false

get_j_pixel x y j_bitmap -> bool:
  if not 0 <= x < 16: return false
  if not 0 <= y < 16: return false
  return (j_bitmap[x + (y >> 3) * 16] & (1 << (y & 7))) != 0

composite_test:
  if not bitmap_primitives_present:
    return  // This test always uses bitmap_draw_text
  VERSIONS.repeat: | version |
    if skip_version version: continue.repeat

    red_dot := bitmap_texture_factory version 0 0 ORIENTATION_0 13 16 (get_red version)

    13.repeat: | x | 16.repeat: | y |
      if (bullseye_get_color version x y):
        red_dot.set_pixel x y
      else:
        red_dot.clear_pixel x y

    sans10 := Font.get "sans10"

    j_color := 0
    if version == TRUE_COLOR:
      j_color = true_color.get_rgb 4 5 6
    else:
      j_color = get_black version
    letter_j := text_texture_factory version 0 0 0 TEXT_TEXTURE_ALIGN_LEFT "j" sans10 j_color

    j_bitmap := ByteArray 32  // 16x16 bitmap.
    bitmap_draw_text 4 12 1 0 "j" sans10 j_bitmap 16

    set_random_seed "mustard"

    100.repeat:
      // Add a random colored box.
      box_w := random 3 17
      box_h := random 3 17
      box_color := random 0 [3, 2, 4, 0x1000000][version]
      box := filled_rectangle_factory version box_color 0 0 box_w box_h
      box_x := random -20 25
      box_y := random -20 25
      box.move_to box_x box_y

      // Move the red dot to a random place.
      rd_x := random -20 25
      rd_y := random -20 25
      red_dot.move_to rd_x rd_y

      // Move the letter j to a random place.
      j_x := random -20 25
      j_y := random -20 25
      letter_j.move_to j_x j_y

      // Stack them in a random order.
      order := random 0 6
      seq := null
      if order == 0:      seq = [red_dot, letter_j, box]
      else if order == 1: seq = [red_dot, box, letter_j]
      else if order == 2: seq = [box, letter_j, red_dot]
      else if order == 3: seq = [box, red_dot, letter_j]
      else if order == 4: seq = [letter_j, box, red_dot]
      else if order == 5: seq = [letter_j, red_dot, box]

      x_offset := (random 0 3) * 8
      y_offset := (random 0 3) * 8

      // Draw onto a window that is positioned at a random aligned place in the scene.
      canvas := canvas_factory version 24 24 x_offset y_offset

      seq[2].write canvas
      seq[1].write canvas
      seq[0].write canvas

      24.repeat: | x | 24.repeat: | y |
        actual_pixel := canvas.get_pixel_ x y
        scene_x := x + x_offset
        scene_y := y + y_offset
        done := false
        for idx := 0; not done; idx++:
          if idx >= seq.size:
            expect actual_pixel == 0
            done = true
          else if seq[idx] == red_dot:
            is_red := bullseye_get_color version scene_x - rd_x scene_y - rd_y
            if is_red:
              expect (get_red version) == actual_pixel
              done = true
          else if seq[idx] == box:
            in_x := box_x <= scene_x < box_x + box_w
            in_y := box_y <= scene_y < box_y + box_h
            if in_x and in_y:
              expect actual_pixel == box_color
              done = true
          else:
            expect seq[idx] == letter_j
            bit := get_j_pixel (4 + scene_x - j_x) (12 + scene_y - j_y) j_bitmap
            if bit:
              expect actual_pixel == j_color
              done = true

barcode_test:
  if not bitmap_primitives_present:
    return
  barcode := three_color.BarCodeEan13 "5017239191589" 10 10 Transform.identity
  canvas := three_color.Canvas_ 128 104  // Starts off white.
  barcode.write canvas

  expect (barcode.l_ 0) == 0x0d
  expect (barcode.g_ 0) == 0x27
  expect (barcode.r_ 0) == 0x72

  line := ""
  canvas.width_.repeat: | x |
    line += (canvas.get_pixel_ x 60) == 0 ? " " : "*"

  expect line == "                   * *   ** * **  **  *   *  *  ** **** *  * *** * * **  ** *** *  **  ** *  *** *  *   *** *  * *              "

  canvas.height_.repeat: | y |
    if y > 80:
      str := ""
      canvas.width_.repeat: | x |
        str += (canvas.get_pixel_ x y) == 0 ? " " : "*"
      print str

random_pixel_ version x y:
  hash1 := (x ^ y) + (y << 7)
  hash2 := (x + y) ^ ((x ^ y) >> 5) ^ ((x - y) << 3)
  return (pseudo_random hash1)

test_bounding_box:
  VERSIONS.repeat: | version |
    if skip_version version: continue.repeat
    WIDTH ::= version == TRUE_COLOR ? 48 : 128
    HEIGHT ::= version == TRUE_COLOR ? 48 : 128
    noisy_background := opaque_bitmap_texture_factory version 0 0 WIDTH HEIGHT (get_red version) (get_white version)
    white_background := null
    if version == THREE_COLOR:
      white_background = three_color.WHITE
    else if version == TWO_COLOR:
      white_background = two_color.WHITE
    else if version == FOUR_GRAY:
      white_background = four_gray.WHITE
    else:
      white_background = true_color.get_rgb 0xff 0xff 0xff
    sans10 := Font.get "sans10"
    WIDTH.repeat: | x | HEIGHT.repeat: | y |
      if random_pixel_ version x y:
        noisy_background.set_pixel x y  // Make pixel red (or black for two-color)

    100.repeat:
      type := random 0 5
      texture := null
      x := random 0 WIDTH
      y := random 0 HEIGHT
      w := random 0 32
      h := random 0 32
      color := random 0 [3, 2, 4, 0x1000000][version]
      orientation := random 0 4
      if type == 0:
        alignment := random 0 3
        text := ["ji", "AV", "VA", "AA", "To", "X", "x", "a"][random 0 8]
        texture = text_texture_factory version x y orientation alignment text sans10 color
        w = texture.display_w
        h = texture.display_h
        // Text is positioned by the bottom left corner, but the max extent is
        // determined by the top left corner, after rotation, so we read that
        // back.
        x = texture.display_x
        y = texture.display_y
      else if type == 1:
        code := "$(%06d (random 0 1000000))$(%07d (random 0 10000000))"
        texture = barcode_factory version code x y orientation
        w = texture.display_w
        h = texture.display_h
        x = texture.display_x
        y = texture.display_y
        color = -1
      else if type == 2:
        texture = filled_rectangle_factory version color x y w h
      else if type == 3:
        texture = bitmap_texture_factory version x y orientation w h color
        w.repeat: | i | h.repeat: | j |
          texture.set_pixel i j
        if w != 0 and h != 0 and version == THREE_COLOR:
          10.repeat:
            texture.clear_pixel (random 0 w) (random 0 h)
        w = texture.display_w
        h = texture.display_h
        x = texture.display_x
        y = texture.display_y
      else if type == 4:
        texture = histogram_factory version x y w h color orientation
        w = texture.display_w
        h = texture.display_h
        x = texture.display_x
        y = texture.display_y

      canvas_x_offset := (random 0 16) << 3
      canvas_y_offset := (random 0 16) << 3
      canvas := canvas_factory version WIDTH HEIGHT 0 0
      canvas.set_all_pixels white_background
      noisy_background.write canvas
      canvas.x_offset_ = canvas_x_offset
      canvas.y_offset_ = canvas_y_offset
      texture.write canvas

      // Sample some random points to see if they are OK.
      50.repeat:
        i := random 0 WIDTH
        j := random 0 HEIGHT

        scene_x := i + canvas_x_offset
        scene_y := j + canvas_y_offset
        noisy_pixel := (random_pixel_ version i j) ? (get_red version) : (get_white version)
        if scene_x < x or scene_x >= x+w or scene_y < y or scene_y >= y+h:
          // If we are outside the texture, then the canvas should be untouched.
          expect (canvas.get_pixel_ i j) == noisy_pixel
        else:
          // Inside the texture the pixels should either be the texture color or
          // the original pattern.
          if color == -1:
            // Barcodes are black and white and have a solid background.
            white := get_white version
            black := get_black version
            expect ((canvas.get_pixel_ i j) == black or (canvas.get_pixel_ i j) == white)
          else:
            // Other textures have a single color in this test.
            if (canvas.get_pixel_ i j) != color:
              expect (canvas.get_pixel_ i j) == noisy_pixel

      // Trace a line around the perimeter of the texture to see that the pixels
      // outside the box are untouched.
      w.repeat: | i |
        canvas_x := x + i - canvas_x_offset
        if 0 <= canvas_x < WIDTH:
          2.repeat: | one_or_zero |
            canvas_y := (y - 1) - canvas_y_offset + (one_or_zero * (h + 1))
            noisy_pixel := (random_pixel_ version canvas_x canvas_y) ? (get_red version) : (get_white version)
            if 0 <= canvas_y < HEIGHT:
              expect (canvas.get_pixel_ canvas_x canvas_y) == noisy_pixel

      h.repeat: | i |
        canvas_y := y + i - canvas_y_offset
        if 0 <= canvas_y < HEIGHT:
          2.repeat: | one_or_zero |
            canvas_x := (x - 1) - canvas_x_offset + (one_or_zero * (w + 1))
            noisy_pixel := (random_pixel_ version canvas_x canvas_y) ? (get_red version) : (get_white version)
            if 0 <= canvas_x < WIDTH:
              expect (canvas.get_pixel_ canvas_x canvas_y) == noisy_pixel
