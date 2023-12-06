// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// TODO: Absorb this into pixel_display.toit now that textures are gone.

import font show Font
import bitmap show ORIENTATION_0 ORIENTATION_90 ORIENTATION_180 ORIENTATION_270

import .element show Element
import .style

/**
A display or a window within a display.
You can add and remove element objects to a Window.  They will be drawn
  in the order they were added, where the first elements are at the back
  and are overwritten by elements added later.
*/
interface Window:
  add element/Element -> none
  remove element/Element -> none
  remove_all -> none

  // Called by elements that have been added to this.
  // Called by elements that have been added to this.
  child_invalidated_element x/int y/int w/int h/int -> none

/**
Something you can draw on a canvas.  It could be a text string, a pixmap or
  a geometric figure. They can be stacked up and will be drawn from back to
  front, with transparency.
*/
abstract class ElementOrTexture_:
  hash_code/int ::= random 0 0x10000000
  change_tracker/Window? := null

  /**
  Writes the image data to a canvas window.
  $canvas: Some sort of canvas.  The precise type depends on the depth of the display.
  */
  write canvas/Canvas -> none:
    write_ canvas

  abstract write_ canvas

  abstract invalidate -> none

abstract class Canvas:
  width_ / int
  height_ / int
  transform / Transform? := null

  constructor .width_ .height_:

  abstract create_similar -> Canvas

  abstract set_all_pixels color/int -> none

  abstract supports_8_bit -> bool
  abstract gray_scale -> bool

  abstract make_alpha_map -> Canvas
  abstract make_alpha_map --padding/int -> Canvas

  static DISJOINT           ::= 0  // The area and the canvas are disjoint.
  static AREA_IN_CANVAS     ::= 1  // The area is a subset of the canvas.
  static CANVAS_IN_AREA     ::= 2  // The canvas is a subset of the area.
  static COINCIDENT         ::= 3  // The area and the canvas are identical.
  static OVERLAP            ::= 4  // The areas overlap, but neither is a subset of the other.

  bounds_analysis x/int y/int w/int h/int -> int:
    if h == 0 or w == 0 or width_ == 0 or height_ == 0: return DISJOINT
    transform.xywh x y w h: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if right < 0 or bottom < 0 or x2 >= width_ or y2 >= height_: return DISJOINT
      if x2 >= 0 and y2 >= 0 and right <= width_ and bottom <= height_:
        if x2 == 0 and y2 == 0 and right == width_ and bottom == height_: return COINCIDENT
        return AREA_IN_CANVAS
      if x2 <= 0 and y2 <= 0 and right >= width_ and bottom >= height_: return CANVAS_IN_AREA
    return OVERLAP

  abstract composit frame_opacity frame_canvas/Canvas painting_opacity painting_canvas/Canvas

  abstract rectangle x/int y/int --w/int --h/int --color/int -> none

  abstract text x/int y/int --text/string --color/int --font/Font --orientation/int
  abstract text x/int y/int --text/string --color/int --font/Font

TRANSFORM_IDENTITY_ ::= Transform.with_ [1, 0, 0, 1, 0, 0]
TRANSFORM_90_ ::= Transform.with_ [0, -1, 1, 0, 0, 0]
TRANSFORM_180_ ::= Transform.with_ [-1, 0, 0, -1, 0, 0]
TRANSFORM_270_ ::= Transform.with_ [0, 1, -1, 0, 0, 0]

// Classic 3x3 matrix for 2D transformations.  Right column is always 0 0 1, so
// we don't need to store it.  We don't support scaling so the top left 2x2
// block is always 0s, 1s, and -1s.
class Transform:
  array_ ::= ?  // 6-element integer array.

  constructor.identity:
    return TRANSFORM_IDENTITY_

  constructor.with_ .array_:

  stringify -> string:
    line1 := "$(%3d array_[0]) $(%3d array_[1])"
    line2 := "$(%3d array_[2]) $(%3d array_[3])"
    line3 := "$(%3d array_[4]) $(%3d array_[5])"
    return "$line1\n$line2\n$line3"

  apply other/Transform -> Transform:
    a0 := array_[0]
    a1 := array_[1]
    a2 := array_[2]
    a3 := array_[3]
    o0 := other.array_[0]
    o1 := other.array_[1]
    o2 := other.array_[2]
    o3 := other.array_[3]
    o4 := other.array_[4]
    o5 := other.array_[5]
    array := [a0 * o0 + a2 * o1,
              a1 * o0 + a3 * o1,
              a0 * o2 + a2 * o3,
              a1 * o2 + a3 * o3,
              a0 * o4 + a2 * o5 + array_[4],
              a1 * o4 + a3 * o5 + array_[5]]
    return Transform.with_ array

  invert -> Transform:
    a0 := array_[0]
    a1 := array_[1]
    a2 := array_[2]
    a3 := array_[3]
    // The scaling of the transform is always 1, so we don't need to do anything about that.
    assert: a0 * a3 - a1 * a2 == 1
    return Transform.with_ [a3, -a1, -a2, a0, -a3 * array_[4] + a2 * array_[5], a1 * array_[4] - a0 * array_[5]]

  operator == other/Transform -> bool:
    6.repeat: | i |
      if array_[i] != other.array_[i]: return false
    return true

  /**
  Finds the extent of a rectangle after it has been transformed with the transform.
    $x_in: The left edge before the transformation is applied.
    $y_in: The top edge before the transformation is applied.
    $w_in: The width before the transformation is applied.
    $h_in: The height before the transformation is applied.
    $block: A block that is called with arguments left top width height in the transformed coordinate space.
  */
  xywh x_in/int y_in/int w_in/int h_in/int [block]:
    x_transformed := x x_in y_in
    y_transformed := y x_in y_in
    w_transformed := width w_in h_in
    h_transformed := height w_in h_in
    x2 := min
      x_transformed
      x_transformed + w_transformed
    y2 := min
      y_transformed
      y_transformed + h_transformed
    w2 := w_transformed.abs
    h2 := h_transformed.abs
    block.call x2 y2 w2 h2

  /**
  Finds a point and an orientation after it has been transformed with the transform.
    $x_in: The x coordinate before the transformation is applied.
    $y_in: The y coordinate before the transformation is applied.
    $o_in: The orientation before the transformation is applied.
    $block: A block that is called with arguments x y orientation in the transformed coordinate space.
  */
  xyo x_in/int y_in/int o_in/int [block]:
    x_transformed := x x_in y_in
    y_transformed := y x_in y_in
    o_transformed/int := ?
    if      array_[0] > 0: o_transformed = o_in + ORIENTATION_0
    else if array_[1] < 0: o_transformed = o_in + ORIENTATION_90
    else if array_[0] < 0: o_transformed = o_in + ORIENTATION_180
    else:                  o_transformed = o_in + ORIENTATION_270
    block.call x_transformed y_transformed (o_transformed & 3)

  /**
  Returns a new transform which represents this transform rotated left
   around the origin in the space of this transform
  */
  rotate_left -> Transform:
    return Transform.with_ [-array_[2], -array_[3], array_[0], array_[1], array_[4], array_[5]]

  /**
  Returns a new transform which represents this transform rotated right
    around the origin in the space of this transform
  */
  rotate_right -> Transform:
    return Transform.with_ [array_[2], array_[3], -array_[0], -array_[1], array_[4], array_[5]]

  /**
  Returns a new transform.  The origin of the new transform is at the point
    $x, $y in the space of this transform.
  */
  translate x/int y/int -> Transform:
    return Transform.with_ [array_[0], array_[1], array_[2], array_[3], array_[4] + (width x y), array_[5] + (height x y)]

  /**
  Returns a new transform.  The new transform is reflected around either
    a horizontal line (if you specify the $y coordinate) or a vertical line
    (if you specify the $x coordinate).

  You cannot specify both $x and $y.  We do not support reflected transforms.

  Most of this library is integer-only, but for this operation you may need
    to use a half-pixel line depending on whether the thing you want to reflect
    is an even or odd number of pixels high/wide.
  */
  reflect_around --x/num?=null --y/num?=null:
    if x:
      if y: throw "INVALID_ARGUMENT"
      return apply (Transform.with_ [-1, 0, 0, 1, (x * 2).to_int, 0])
    else if y:
      return apply (Transform.with_ [1, 0, 0, -1, 0, (y * 2).to_int])
    else:
      return this

  // Does not handle reflections or scaling.  Used for font rendering which
  // currently has no support for scaled or reflected text.
  orientation_:
    if array_[0] > 0: return ORIENTATION_0
    if array_[1] < 0: return ORIENTATION_90
    if array_[0] < 0: return ORIENTATION_180
    else: return ORIENTATION_270

  /**
  Returns the transformed x coordinate of the given point ($x, $y).
  */
  x x/int y/int -> int:
    return x * array_[0] + y * array_[2] + array_[4]

  /**
  Returns the transformed y coordinate of the given point ($x, $y).
  */
  y x/int y/int -> int:
    return x * array_[1] + y * array_[3] + array_[5]

  /**
  Returns the transformed width given an unrotated $width and $height.
  A negative result indicates the shape extends to the left of the origin.
  */
  width width/int height/int -> int:
    return width * array_[0] + height * array_[2]

  /**
  Returns the transformed height given an unrotated $width and $height.
  A negative result indicates the shape extends upwards from the origin.
  */
  height width/int height/int -> int:
    return width * array_[1] + height * array_[3]

class TextExtent_:
  x := 0
  y := 0
  w := 0
  h := 0
  displacement := 0

  // Gets the graphical extent of a string nominally positioned at (0, 0),
  // Where the nominal position of the text is relative to the letters depends
  // on the alignment, but it is always somewhere on the textual baseline.
  // Some confusion is caused here by the fact that the y-axis of elements
  // grows towards the bottom, whereas the y-axis of fonts grows towards the
  // top.
  constructor text font alignment:
    box := font.text_extent text
    if alignment != ALIGN_LEFT:
      displacement = -(font.pixel_width text)
      if alignment == ALIGN_CENTER: displacement >>= 1
    w = box[0]
    h = box[1]
    x = box[2] + displacement
    y = -box[1] - box[3]

text_get_bounding_boxes_ old/string new/string alignment/int font/Font [block]:
  left_doesnt_move  := alignment == ALIGN_LEFT
  right_doesnt_move := alignment == ALIGN_RIGHT
  // If the rendered length does not change then both ends don't move.
  pixel_width_old := font.pixel_width old
  if pixel_width_old == (font.pixel_width new):
    left_doesnt_move = true
    right_doesnt_move = true
  length := min old.size new.size
  unchanged_left := 0
  unchanged_right := 0
  if left_doesnt_move:
    // Find out how many bytes are unchanged at the start of the string.
    unchanged_left = length
    for i := 0; i < length; i++:
      if old[i] != new[i]:
        unchanged_left = i
        break
  if right_doesnt_move:
    // Find out how many bytes are unchanged at the end of the string.
    unchanged_right = length
    last_character_start := 0  // Location (counting from end) of the start of the last UTF-8 sequence.
    for i := 0; i < length; i++:
      if old[old.size - 1 - i] != new[new.size - 1 - i]:
        unchanged_right = last_character_start
        break
      else if old[old.size - 1 - i]:
        last_character_start = i + 1
  if unchanged_right != 0 or unchanged_left != 0:
    changed_old := old.copy unchanged_left (old.size - unchanged_right)
    changed_new := new.copy unchanged_left (new.size - unchanged_right)
    changed_extent_old := TextExtent_ changed_old font alignment
    changed_extent_new := TextExtent_ changed_new font alignment
    if alignment == ALIGN_LEFT:
      unchanged_width := font.pixel_width old[..unchanged_left]
      changed_extent_old.x += unchanged_width
      changed_extent_new.x += unchanged_width
    else if alignment == ALIGN_RIGHT:
      unchanged_width := font.pixel_width old[old.size - unchanged_right..]
      // Make x relative to the text origin, which is the right edge.
      changed_extent_old.x -= unchanged_width
      changed_extent_new.x -= unchanged_width
    else:
      assert: alignment == ALIGN_CENTER
      assert: pixel_width_old == (font.pixel_width new)
      // Make x relative to the text origin, which is the middle.
      unchanged_width := ((pixel_width_old + 1) >> 1) - (font.pixel_width old[..unchanged_left])
      changed_extent_old.x -= unchanged_width + changed_extent_old.displacement
      changed_extent_new.x -= unchanged_width + changed_extent_new.displacement
    block.call changed_extent_old changed_extent_new
