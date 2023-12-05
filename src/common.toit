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

  abstract bitmap x/int y/int -> none
      --pixels/ByteArray
      --alpha/ByteArray          // 2-element byte array.
      --palette/ByteArray        // 6-element byte array.
      --source_width/int         // In pixels.
      --source_line_stride/int   // In bytes.

  abstract bitmap x/int y/int -> none
      --pixels/ByteArray
      --alpha/ByteArray          // 2-element byte array.
      --palette/ByteArray        // 6-element byte array.
      --source_width/int         // In pixels.
      --source_line_stride/int   // In bytes.
      --orientation/int

  pixmap x/int y/int
      --pixels/ByteArray
      --alpha/ByteArray=#[]
      --palette/ByteArray=#[]
      --source_width/int
      --orientation/int=ORIENTATION_0
      --source_line_stride/int=source_width:
   throw "Unimplemented"

  rgb_pixmap x/int y/int --r/ByteArray --g/ByteArray --b/ByteArray --source_width/int --orientation/int=ORIENTATION_0:
    throw "UNSUPPORTED"  // Only on true color canvas.

TRANSFORM_IDENTITY_ ::= Transform.with_ --x1=1 --x2=0 --y1=0 --y2=1 --tx=0 --ty=0
TRANSFORM_90_ ::= Transform.with_ --x1=0 --x2=-1 --y1=1 --y2=0 --tx=0 --ty=0
TRANSFORM_180_ ::= Transform.with_ --x1=-1 --x2=0 --y1=0 --y2=-1 --tx=0 --ty=0
TRANSFORM_270_ ::= Transform.with_ --x1=0 --x2=1 --y1=-1 --y2=0 --tx=0 --ty=0

/**
Classic 3x3 matrix for 2D transformations.
Right column is always 0 0 1, so we don't need to store it.
We don't support scaling so the top left 2x2 block is always 0s, 1s, and -1s.
*/
class Transform:
  // [ x1   y1    0  ]
  // [ x2   y2    0  ]
  // [ tx   ty    1  ]
  x1_/int ::= ?
  y1_/int ::= ?
  x2_/int ::= ?
  y2_/int ::= ?
  tx_/int ::= ?
  ty_/int ::= ?

  constructor.identity:
    return TRANSFORM_IDENTITY_

  constructor.with_ --x1/int --y1/int --x2/int --y2/int --tx/int --ty/int:
    x1_ = x1
    x2_ = x2
    tx_ = tx
    y1_ = y1
    y2_ = y2
    ty_ = ty

  apply other/Transform -> Transform:
    a0 := x1_
    a1 := y1_
    a2 := x2_
    a3 := y2_
    o0 := other.x1_
    o1 := other.y1_
    o2 := other.x2_
    o3 := other.y2_
    o4 := other.tx_
    o5 := other.ty_
    return Transform.with_
        --x1 = a0 * o0 + a2 * o1
        --y1 = a1 * o0 + a3 * o1
        --x2 = a0 * o2 + a2 * o3
        --y2 = a1 * o2 + a3 * o3
        --tx = a0 * o4 + a2 * o5 + tx_
        --ty = a1 * o4 + a3 * o5 + ty_

  invert -> Transform:
    a0 := x1_
    a1 := y1_
    a2 := x2_
    a3 := y2_
    // The scaling of the transform is always 1, so we don't need to do anything about that.
    assert: a0 * a3 - a1 * a2 == 1
    return Transform.with_
        --x1 = a3
        --y1 = -a1
        --x2 = -a2
        --y2 = a0
        --tx = -a3 * tx_ + a2 * ty_
        --ty = a1 * tx_ - a0 * ty_

  operator == other/Transform -> bool:
    if x1_ != other.x1_: return false
    if y1_ != other.y1_: return false
    if x2_ != other.x2_: return false
    if y2_ != other.y2_: return false
    if tx_ != other.tx_: return false
    if ty_ != other.ty_: return false
    return true

  /**
  Finds the extent of a rectangle after it has been transformed with the transform.
  - $x_in: The left edge before the transformation is applied.
  - $y_in: The top edge before the transformation is applied.
  - $w_in: The width before the transformation is applied.
  - $h_in: The height before the transformation is applied.
  - $block: A block that is called with arguments left top width height in the transformed coordinate space.
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
  - $x_in: The x coordinate before the transformation is applied.
  - $y_in: The y coordinate before the transformation is applied.
  - $o_in: The orientation before the transformation is applied.
  - $block: A block that is called with arguments x y orientation in the transformed coordinate space.
  */
  xyo x_in/int y_in/int o_in/int [block]:
    x_transformed := x x_in y_in
    y_transformed := y x_in y_in
    o_transformed/int := ?
    if      x1_ > 0: o_transformed = o_in + ORIENTATION_0
    else if y1_ < 0: o_transformed = o_in + ORIENTATION_90
    else if x1_ < 0: o_transformed = o_in + ORIENTATION_180
    else:                  o_transformed = o_in + ORIENTATION_270
    block.call x_transformed y_transformed (o_transformed & 3)

  /**
  Returns a new transform which represents this transform rotated left
    around the origin in the space of this transform
  */
  rotate_left -> Transform:
    return Transform.with_
        --x1 = -x2_
        --y1 = -y2_
        --x2 = x1_
        --y2 = y1_
        --tx = tx_
        --ty = ty_

  /**
  Returns a new transform which represents this transform rotated right
    around the origin in the space of this transform
  */
  rotate_right -> Transform:
    return Transform.with_
        --x1 = x2_
        --y1 = y2_
        --x2 = -x1_
        --y2 = -y1_
        --tx = tx_
        --ty = ty_

  /**
  Returns a new transform.  The origin of the new transform is at the point
    $x, $y in the space of this transform.
  */
  translate x/int y/int -> Transform:
    return Transform.with_
      --x1 = x1_
      --y1 = y1_
      --x2 = x2_
      --y2 = y2_
      --tx = tx_ + (width x y)
      --ty = ty_ + (height x y)

  // Used for font rendering.
  orientation_:
    if x1_ > 0: return ORIENTATION_0
    if y1_ < 0: return ORIENTATION_90
    if x1_ < 0: return ORIENTATION_180
    else: return ORIENTATION_270

  /**
  Returns the transformed x coordinate of the given point ($x, $y).
  */
  x x/int y/int -> int:
    return x * x1_ + y * x2_ + tx_

  /**
  Returns the transformed y coordinate of the given point ($x, $y).
  */
  y x/int y/int -> int:
    return x * y1_ + y * y2_ + ty_

  /**
  Returns the transformed width given an unrotated $width and $height.
  A negative result indicates the shape extends to the left of the origin.
  */
  width width/int height/int -> int:
    return width * x1_ + height * x2_

  /**
  Returns the transformed height given an unrotated $width and $height.
  A negative result indicates the shape extends upwards from the origin.
  */
  height width/int height/int -> int:
    return width * y1_ + height * y2_

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
