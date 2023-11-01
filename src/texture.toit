// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import binary show LITTLE_ENDIAN
import bitmap show *
import .true_color as true_color
import .one_byte as one_byte
import font show Font
import math

TRANSFORM_IDENTITY_ ::= Transform.with_ [1, 0, 0, 1, 0, 0]
TRANSFORM_90_ ::= Transform.with_ [0, -1, 1, 0, 0, 0]
TRANSFORM_180_ ::= Transform.with_ [-1, 0, 0, -1, 0, 0]
TRANSFORM_270_ ::= Transform.with_ [0, 1, -1, 0, 0, 0]

// Classic 3x3 matrix for 2D transformations.  Right column is always 0 0 1, so we
// don't need to store it.  We don't support scaling so the top left 2x2 block is
// always 0s, 1s, and -1s.
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

  You cannot specify both $x and $y.  Not all textures support
    reflected transforms.  In particular, text and icons cannot be reflected.

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

abstract class AbstractCanvas:
  width_ / int                    // Used by both Textures and Elements.
  height_ / int                   // Only used by Textures.
  x_offset_ / int := 0            // Only used by Textures.
  y_offset_ / int := 0            // Only used by Textures.
  transform / Transform? := null  // Only used by Elements.

  constructor .width_ .height_:

  abstract create_similar -> AbstractCanvas

  abstract set_all_pixels color/int -> none

  abstract make_alpha_map -> AbstractCanvas
  abstract make_alpha_map --padding/int -> AbstractCanvas

  static ALL_OUTSIDE ::= 0
  static ALL_INSIDE ::= 1
  static MIXED_BOUNDS ::= 2

  bounds_analysis x/int y/int w/int h/int -> int:
    if h == 0 or w == 0: return ALL_OUTSIDE
    transform.xywh x y w h: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if right < 0 or bottom < 0 or x2 >= width_ or y2 >= height_: return ALL_OUTSIDE
      if x2 >= 0 and y2 >= 0 and right <= width_ and bottom <= height_: return ALL_INSIDE
    return MIXED_BOUNDS

  abstract composit frame_opacity frame_canvas/AbstractCanvas painting_opacity painting_canvas/AbstractCanvas

  // draw a Line from x1,y1 (inclusive) to x2,y2 (exclusive) using the transform.
  // The line must be horizontal or vertical.
  line x1/int y1/int x2/int y2/int color/int:
    if x1 == x2:
      if y1 < y2:
        rectangle x1 y1 --w=(y2 - y1) --h=1 --color=color
      else if y2 < y1:
        rectangle x1 y2 --w=(y1 - y2) --h=1 --color=color
      // Else do nothing - zero length line.
    else if y1 == y2:
      if x1 < x2:
        rectangle x1 y1 --w=1 --h=(x2 - x1) --color=color
      else:
        rectangle x2 y1 --w=1 --h=(x1 - x2) --color=color
    else:
      throw "LINE_NOT_HORIZONTAL_OR_VERTICAL"

  abstract rectangle x/int y/int --w/int --h/int --color/int -> none

  abstract text x/int y/int --text/string --color/int --font/Font --orientation/int
  abstract text x/int y/int --text/string --color/int --font/Font

/**
Something you can draw on a canvas.  It could be a text string, a pixmap or
  a geometric figure. They can be stacked up and will be drawn from back to
  front, with transparency.
*/
abstract class Texture:
  hash_code /int ::= random 0 0x10000000
  change_tracker /Window? := null

  /**
  Writes the image data to a canvas window.
  $canvas: Some sort of canvas.  The precise type depends on the depth of the display.
  */
  write canvas/AbstractCanvas -> none:
    write_ canvas

  abstract write_ canvas

  abstract invalidate -> none

abstract class Element extends Texture:
  x_ /int? := null
  y_ /int? := null

  x -> int: return x_
  y -> int: return y_

  constructor --x/int?=null --y/int?=null:
    x_ = x
    y_ = y

  x= value/int -> none:
    invalidate
    x_ = value
    invalidate

  y= value/int -> none:
    invalidate
    y_ = value
    invalidate

  move_to x/int y/int:
    invalidate
    x_ = x
    y_ = y
    invalidate

  write_ canvas -> none:
    throw "Can't call write_ on an Element"

  abstract draw texture/Texture -> none

interface ColoredElement:
  color -> int?
  color= value/int -> none

abstract class ResizableElement extends Element:
  w_ /int? := null
  h_ /int? := null

  constructor --x/int?=null --y/int?=null --w/int?=null --h/int?=null:
    w_ = w
    h_ = h
    super --x=x --y=y

  invalidate:
    if change_tracker:
      change_tracker.child_invalidated_element x y w h

  w -> int: return w_
  h -> int: return h_

  w= value/int -> none:
    invalidate
    w_ = value
    invalidate

  h= value/int -> none:
    invalidate
    h_ = value
    invalidate

  set_size w/int h/int -> none:
    invalidate
    w_ = w
    h_ = h
    invalidate

abstract class RectangleElement extends ResizableElement implements ColoredElement:
  color_ /int := ?

  color -> int: return color_

  color= value/int -> none:
    if color_ != value:
      color_ = value
      invalidate

  constructor --x/int?=null --y/int?=null --w/int --h/int --color/int:
    color_ = color
    super --x=x --y=y --w=w --h=h

class GradientSpecifier:
  color/int
  percent/int

  constructor --.color/int .percent/int:

/**
GradientElements are similar to CSS linear gradients and SVG gradients.
They are given a list of $GradientSpecifiers, each of which has a color and
  a percentage, indicating where in the gradient the color should appear.
  The specifiers should be ordered in increasing order of perentage.
Angles are as in CSS, with 0 degrees being up and 90 degrees being to the right
  (this is different from text orientations, which go anti-clockwise).
See https://cssgradient.io/ for a visual explanation and playground for CSS
  gradients.
Example:
```
  gradient = GradientElement --w=200 --h=100 --angle=45
      --specifiers=[
          GradientSpecifier --color=0xff0000 10,    // Red from 0-10%, red-to-green from 10-50%.
          GradientSpecifier --color=0x00ff00 50,    // Green-to-blue from 50-90%.
          GradientSpecifier --color=0x0000ff 90,    // Blue from 90-100%.
      ]
  display.add gradient
```
*/
class GradientElement extends ResizableElement:
  angle_/int := ?
  specifiers_/List? := ?
  red_pixels_/ByteArray? := null
  green_pixels_/ByteArray? := null
  blue_pixels_/ByteArray? := null
  draw_vertical_/bool? := null

  constructor --x/int?=null --y/int?=null --w/int --h/int --angle/int --specifiers/List:
    angle_ = normalize_angle_ angle
    if specifiers.size == 0: throw "INVALID_ARGUMENT"
    validate_specifiers_ specifiers
    specifiers_ = specifiers
    super --x=x --y=y --w=w --h=h
    recalculate_texture_

  static normalize_angle_ angle/int -> int:
    if 0 <= angle < 360:
      return angle
    else if angle < 0:
      return angle % 360 + 360
    else:
      return angle % 360

  specifiers= value/List -> none:
    validate_specifiers_ value
    specifiers_ = value
    recalculate_texture_
    invalidate

  angle= value/int -> none:
    if value != angle_:
      invalidate
      angle_ = normalize_angle_ value
      recalculate_texture_

  w= value/int -> none:
    super = value
    recalculate_texture_

  h= value/int -> none:
    super = value
    recalculate_texture_

  recalculate_texture_ -> none:
    if h == 0 or w == 0: return

    // CSS gradient angles are:
    //    0 bottom to top.
    //   90 left to right
    //  180 top to bottom
    //  270 right to left

    // Create an angle that is between 0 and 90 degrees and has the same amount of
    // verticalness as the gradient.
    gangle := angle_
    if gangle >= 180: gangle = 360 - gangle
    if gangle >= 90: gangle = 180 - gangle
    // Create an angle from the center of the rectangle to the top right corner.
    // This is the angle that we will use to calculate the verticalness of the
    // rectangle.
    rangle := math.atan (w.to_float / h)  // From 0 to PI/2.
    rangle *= 180.0 / math.PI            // From 0 to 90.
    draw_vertical_ = gangle < rangle
    texture_length/int := ?
    if draw_vertical_:
      // The gradient is more vertical than the rectangle, so we will draw
      // vertical lines on the rectangle.
      texture_length = (h + w * (math.tan (gangle * math.PI / 180.0)) + 0.01).round
    else:
      // The gradient is more horizontal than the rectangle, so we will draw
      // horizontal lines on the rectangle.
      texture_length = (w + h * (math.tan ((90 - gangle) * math.PI / 180.0)) + 0.01).round

    red_pixels_ = ByteArray texture_length
    green_pixels_ = ByteArray texture_length
    blue_pixels_ = ByteArray texture_length
    ranges/List := extract_ranges_ specifiers_
    ranges.do: | range |
      get_colors range texture_length: | index red green blue |
        red_pixels_[index] = red
        green_pixels_[index] = green
        blue_pixels_[index] = blue

  static validate_specifiers_ specifiers -> none:
    last_percent := 0
    if specifiers.size == 0: throw "INVALID_ARGUMENT"
    specifiers.do: | specifier/GradientSpecifier |
      if specifier.percent < last_percent: throw "INVALID_ARGUMENT"
      last_percent = specifier.percent
      if last_percent > 100: throw "INVALID_ARGUMENT"

  /// Returns a list of quadruples of the form starting-percent ending-percent start-color end-color.
  static extract_ranges_ specifiers/List -> List:
    result := []
    for i := -1; i < specifiers.size; i++:
      from := i < 0 ? 0 : specifiers[i].percent
      to := i >= specifiers.size - 1 ? 100 : specifiers[i + 1].percent
      if to != from:
        from_color := specifiers[max i 0].color
        to_color := specifiers[min (i + 1) (specifiers.size - 1)].color
        result.add [from, to, from_color, to_color]
    return result

  static get_colors range/List h/int [block] -> none:
    from_y := range[0] * h / 100
    to_y := range[1] * h / 100
    if to_y == from_y: return
    divisor := to_y - from_y
    from_color := range[2]
    // Use 8.16 fixed point arithmetic to avoid floating point.
    r := from_color & 0xff0000
    g := (from_color & 0xff00) << 8
    b := (from_color & 0xff) << 16
    to_color := range[3]
    to_r := to_color & 0xff0000
    to_g := (to_color & 0xff00) << 8
    to_b := (to_color & 0xff) << 16
    step_r := (to_r - r) / divisor
    step_g := (to_g - g) / divisor
    step_b := (to_b - b) / divisor
    for y := from_y; y < to_y; y++:
      block.call y (r >> 16) (g >> 16) (b >> 16)
      r += step_r
      g += step_g
      b += step_b

  draw canvas/AbstractCanvas -> none:
    analysis := canvas.bounds_analysis x y w h
    if analysis == AbstractCanvas.ALL_OUTSIDE: return
    // Determine whether the draw operations will be automatically cropped for
    // us, or whether we need to do it ourselves by using slices for drawing
    // operations.  We could also check whether we are inside a window that will
    // use compositing to crop everything.
    auto_crop := analysis == AbstractCanvas.ALL_INSIDE

    // CSS gradient angles are:
    //    0 bottom to top.
    //   90 left to right
    //  180 top to bottom
    //  270 right to left

    if draw_vertical_:
      // The gradient goes broadly vertically, and we draw in vertical strips.
      up/bool := angle_ < 90
      orientation/int := ORIENTATION_90
      x2/int := x
      y2/int := y + h
      if 90 < angle_ < 270:  // Top to bottom.
        up = angle_ <= 180
        orientation = ORIENTATION_270
        x2++
        y2 = y
      start/int := w - 1
      stop/int := -1
      i_step/int := -1
      if up:
        start = 0
        stop = w
        i_step = 1
      offset := 0
      step := ((red_pixels_.size - h) << 16) / w  // n.16 fixed point.
      for i := start; i != stop; i += i_step:
        o := offset >> 16
        y3 := ?
        r := red_pixels_
        g := green_pixels_
        b := blue_pixels_
        if auto_crop:
          if orientation == ORIENTATION_90:
            y3 = y2 + o
          else:
            y3 = y2 - o
        else:
          y3 = y2
          r = r[o .. o + h]
          g = g[o .. o + h]
          b = b[o .. o + h]
        if canvas is true_color.Canvas:
          (canvas as true_color.Canvas).draw_rgb_pixmap (i + x2) y3 --r=r --g=g --b=b --pixmap_width=h --orientation=orientation
        else:
          (canvas as one_byte.OneByteCanvas_).draw_pixmap (i + x2) y3 --pixels=b --pixmap_width=h --orientation=orientation
        offset += step
    else:
      // The gradient goes broadly horizontally, and we draw in horizontal strips.
      up/bool := angle_ > 90
      orientation/int := ORIENTATION_0
      x2/int := x
      y2/int := y
      if angle_ >= 180:  // Right to left.
        up = angle_ < 270
        orientation = ORIENTATION_180
        x2 += w
        y2++
      start := h - 1
      stop := -1
      i_step := -1
      if up:
        start = 0
        stop = h
        i_step = 1
      offset := 0
      step := ((red_pixels_.size - w) << 16) / h  // n.16 fixed point.
      for i := start; i != stop; i += i_step:
        o := offset >> 16
        x3 := ?
        r := red_pixels_
        g := green_pixels_
        b := blue_pixels_
        if auto_crop:
          if orientation == ORIENTATION_0:
            x3 = x2 - o
          else:
            x3 = x2 + o
        else:
          x3 = x2
          r = r[o .. o + w]
          g = g[o .. o + w]
          b = b[o .. o + w]
        if canvas is true_color.Canvas:
          (canvas as true_color.Canvas).draw_rgb_pixmap x3 (i + y2) --r=r --g=g --b=b --pixmap_width=w --orientation=orientation
        else:
          (canvas as one_byte.OneByteCanvas_).draw_pixmap x3 (i + y2) --pixels=b --pixmap_width=w --orientation=orientation
        offset += step

class FilledRectangleElement extends RectangleElement:
  constructor --x/int --y/int --w/int --h/int --color/int:
    super --x=x --y=y --w=w --h=h --color=color

  draw canvas/AbstractCanvas -> none:
    canvas.rectangle x_ y_ --w=w_ --h=h_ --color=color_

class OutlineRectangleElement extends RectangleElement:
  thickness_/int := ?

  constructor --x/int --y/int --w/int --h/int --color/int --thickness/int=1:
    if thickness > (min h w): throw "INVALID_ARGUMENT"
    thickness_ = thickness
    super --x=x --y=y --w=w --h=h --color=color

  thickness -> int: return thickness_

  thickness= value/int -> none:
    if thickness_ != value:
      if value > (min h_ w_): throw "INVALID_ARGUMENT"
      thickness_ = max thickness_ value
      invalidate
      thickness_ = value

  invalidate -> none:
    if change_tracker:
      change_tracker.child_invalidated_element x y w thickness
      change_tracker.child_invalidated_element x y thickness h
      change_tracker.child_invalidated_element x (y + h - thickness) w thickness
      change_tracker.child_invalidated_element (x + w - thickness) y thickness h

  draw canvas /AbstractCanvas -> none:
    canvas.rectangle x_ y_                     --w=thickness_ --h=h_         --color=color_
    canvas.rectangle x_ y_                     --w=w_         --h=thickness_ --color=color_
    canvas.rectangle (x_ + w_ - thickness_) y_ --w=thickness_ --h=h_         --color=color_
    canvas.rectangle x_ (y + h_ - thickness_)  --w=w_         --h=thickness_ --color=color_

class TextElement extends Element implements ColoredElement:
  color_/int := ?
  text_/string? := null
  alignment_/int := ?
  orientation_/int := ?
  font_/Font := ?
  left_/int? := null
  top_/int? := null
  width_/int? := null
  height_/int? := null

  color -> int: return color_

  color= value/int -> none:
    if color_ != value:
      color_ = value
      invalidate

  constructor --x/int --y/int --color/int --text/string?=null --font/Font --orientation/int=ORIENTATION_0 --alignment/int=TEXT_TEXTURE_ALIGN_LEFT:
    color_ = color
    text_ = text
    alignment_ = alignment
    orientation_ = orientation
    font_ = font
    super --x=x --y=y

  /**
  Calls the block with the left, top, width, and height.
  For zero sized objects, doesn't call the block.
  */
  xywh_ [block]:
    if not text_: return
    if not left_:
      extent/List := font_.text_extent text_
      displacement := 0
      if alignment_ != TEXT_TEXTURE_ALIGN_LEFT:
        displacement = (font_.pixel_width text_)
        if alignment_ == TEXT_TEXTURE_ALIGN_CENTER: displacement >>= 1
      l := extent[2] - displacement
      r := extent[2] - displacement + extent[0]
      t := -extent[1] - extent[3]
      b := extent[3]
      if orientation_ == ORIENTATION_0:
        left_   = l
        top_    = t
        width_  = extent[0]
        height_ = extent[1]
      else if orientation_ == ORIENTATION_90:
        left_   = t
        top_    = -r
        width_  = extent[1]
        height_ = extent[0]
      else if orientation_ == ORIENTATION_180:
        left_   = -r
        top_    = b
        width_  = extent[0]
        height_ = extent[1]
      else:
        assert: orientation_ == ORIENTATION_270
        left_   = b
        top_    = l
        width_  = extent[1]
        height_ = extent[0]
    block.call (x_ + left_) (y_ + top_) width_ height_

  invalidate:
    if change_tracker and text_:
      xywh_: | x y w h |
        change_tracker.child_invalidated_element x y w h

  text= value/string? -> none:
    if value == text_: return
    if orientation_ == ORIENTATION_0 and change_tracker and text_:
      TextTexture_.get_bounding_boxes_ text_ value alignment_ font_: | old/TextExtent_ new/TextExtent_ |
        change_tracker.child_invalidated_element (x_ + old.x) (y_ + old.y) old.w old.h
        change_tracker.child_invalidated_element (x_ + new.x) (y_ + new.y) new.w new.h
        text_ = value
        left_ = null  // Trigger recalculation.
        return
    invalidate
    text_ = value
    left_ = null  // Trigger recalculation.
    invalidate

  orientation= value/int -> none:
    if value == orientation_: return
    invalidate
    orientation_ = value
    left_ = null  // Trigger recalculation.
    invalidate

  alignment= value/int -> none:
    if value == alignment_: return
    invalidate
    alignment_ = value
    left_ = null  // Trigger recalculation.
    invalidate

  draw canvas /AbstractCanvas -> none:
    x := x_
    y := y_
    if alignment_ != TEXT_TEXTURE_ALIGN_LEFT:
      text_width := font_.pixel_width text_
      if alignment_ == TEXT_TEXTURE_ALIGN_CENTER: text_width >>= 1
      if orientation_ == ORIENTATION_0:
        x -= text_width
      else if orientation_ == ORIENTATION_90:
        y += text_width
      else if orientation_ == ORIENTATION_180:
        x += text_width
      else:
        assert: orientation_ == ORIENTATION_270
        y -= text_width
    canvas.text x y --text=text_ --color=color_ --font=font_ --orientation=orientation_

/**
A superclass for elements that can draw themselves.  Override the
  $draw method in your subclass to draw on the canvas.  The $w
  and $h methods/fields are used to determine the size of the element
  for redrawing purposes.

Drawing operations are not automatically clipped to w and h, but if you
  draw outside the area then partial screen updates will be broken.
*/
abstract class CustomElement extends Element:
  abstract w -> int
  abstract h -> int

  constructor --x/int?=null --y/int?=null:
    super --x=x --y=y

  invalidate:
    if change_tracker:
      change_tracker.child_invalidated_element x y w h

// Element that draws a standard EAN-13 bar code.  TODO: Other scales.
class BarCodeEanElement extends CustomElement:
  w/int
  h/int
  foreground/int
  background/int
  sans10_ ::= Font.get "sans10"
  number_height_ := EAN_13_BOTTOM_SPACE

  code_ := ?  // 13 digit code as a string.

  code= value/string -> none:
    if value != code_: invalidate
    code_ = value

  code -> string: return code_

  /**
  $code_: The 13 digit product code.
  $x: The left edge of the barcode in the coordinate system of the transform.
  $y: The top edge of the barcode in the coordinate system of the transform.
  $background should normally be white and foreground should normally be black.
  */
  constructor .code_/string x/int y/int --.background/int --.foreground/int:
    // The numbers go below the bar code in a way that depends on the size
    // of the digits, so we need to take that into account when calculating
    // the bounding box.
    number_height_ = (sans10_.text_extent "8")[1]
    height := EAN_13_HEIGHT + number_height_ - EAN_13_BOTTOM_SPACE
    w = EAN_13_WIDTH
    h = height + 1
    super --x=x --y=y

  l_ digit:
    return EAN_13_L_CODES_[digit & 0xf]

  g_ digit:
    return EAN_13_G_CODES_[digit & 0xf]

  r_ digit:
    return (l_ digit) ^ 0x7f

  // Make a white background behind the bar code and draw the digits along the bottom.
  draw_background_ canvas/AbstractCanvas:
    canvas.rectangle x_ y_ --w=w --h=h --color=background

    // Bar code coordinates.
    text_x := x + EAN_13_QUIET_ZONE_WIDTH + EAN_13_START_WIDTH
    text_y := y + EAN_13_HEIGHT + number_height_ - EAN_13_BOTTOM_SPACE + 1

    canvas.text (x + 1) text_y --text=code_[..1] --color=foreground --font=sans10_

    code_[1..7].split "":
      if it != "":
        canvas.text text_x text_y --text=it --color=foreground --font=sans10_
        text_x += EAN_13_DIGIT_WIDTH
    text_x += EAN_13_MIDDLE_WIDTH - 1
    code_[7..13].split "":
      if it != "":
        canvas.text text_x text_y --text=it --color=foreground --font=sans10_
        text_x += EAN_13_DIGIT_WIDTH
    marker_width := (sans10_.text_extent ">")[0]
    text_x += EAN_13_START_WIDTH + EAN_13_QUIET_ZONE_WIDTH - marker_width
    canvas.text text_x text_y --text=">" --color=foreground --font=sans10_

  // Redraw routine.
  draw canvas/AbstractCanvas:
    if (canvas.bounds_analysis x y w h) == AbstractCanvas.ALL_OUTSIDE: return
    draw_background_ canvas

    x := x_ + EAN_13_QUIET_ZONE_WIDTH
    top := y_
    long_height := EAN_13_HEIGHT
    short_height := EAN_13_HEIGHT - EAN_13_BOTTOM_SPACE
    // Start bars: 101.
    canvas.rectangle x     top --w=1 --h=long_height --color=foreground
    canvas.rectangle x + 2 top --w=1 --h=long_height --color=foreground
    x += 3
    first_code := EAN_13_FIRST_CODES_[code_[0] & 0xf]
    // Left digits using the L or G mapping.
    for i := 1; i < 7; i++:
      digit := code_[i]
      code := ((first_code >> (6 - i)) & 1) == 0 ? (l_ digit) : (g_ digit)
      for b := 6; b >= 0; b--:
        if ((1 << b) & code) != 0:
          canvas.rectangle x top --w=1 --h=short_height --color=foreground
        x++
    // Middle bars: 01010
    canvas.rectangle x + 1 top --w=1 --h=long_height --color=foreground
    canvas.rectangle x + 3 top --w=1 --h=long_height --color=foreground
    x += 5
    // Left digits using the R mapping.
    for i := 7; i < 13; i++:
      digit := code_[i]
      code := r_ digit
      for b := 6; b >= 0; b--:
        if ((1 << b) & code) != 0:
          canvas.rectangle x top --w=1 --h=short_height --color=foreground
        x++
    // End bars: 101.
    canvas.rectangle x     top --w=1 --h=long_height --color=foreground
    canvas.rectangle x + 2 top --w=1 --h=long_height --color=foreground

/**
Most $Texture s have a size and know their own position in the scene, and are
  thus SizedTextures.  A sized texture keeps track of the coordinate system that
  it lives in, via the $transform_.  It also tracks the untransformed left,
  top, width and height of the texture, and the transformed left, top, width
  and height of the texture with the current transform.
*/
abstract class SizedTexture extends Texture:
  x_ /int := 0
  y_ /int := 0
  w_ /int := 0
  h_ /int := 0
  transform_ /Transform := Transform.identity

  transform -> Transform: return transform_

  /**
  Create a new SizedTexture with the given position and size in the
    coordinate system of the given transform.
  $x_: The left of the texture.
  $y_: The top of the texture.
  $w_: The width of the texture.
  $h_: The height of the texture.
  $transform_: The coordinate system of the texture.
  */
  constructor .x_ .y_ .w_ .h_ .transform_:

  /**
  Returns the left edge of the texture in the display coordinates.
  */
  display_x -> int:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      return x2
    unreachable

  /**
  Returns the top edge of the texture in the display coordinates.
  */
  display_y -> int:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      return y2
    unreachable

  /**
  Returns the width of the texture in the display coordinates.
  */
  display_w -> int:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      return w2
    unreachable

  /**
  Returns the height of the texture in the display coordinates.
  */
  display_h -> int:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      return h2
    unreachable

  /**
  Returns the left edge of the texture in the coordinate system of the transform.
  */
  x -> int:
    return x_

  /**
  Returns the top edge of the texture in the coordinate system of the transform.
  */
  y -> int:
    return y_

  /**
  Invalidates (mark for redrawing) the entire area of this texture.
  */
  invalidate:
    if change_tracker:
      transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
        change_tracker.child_invalidated x2 y2 w2 h2

  /**
  Sets a new coordinate system for the texture.  This can cause it to move or rotate.
  */
  set_transform new_transform/Transform -> none:
    invalidate
    transform_ = new_transform
    invalidate

  /**
  Invalidates (mark for redrawing) a part of this texture.  Coordinates are
    in the transforms coordinate system.
  $x: The left edge of the area to redraw.
  $y: The top edge of the area to redraw.
  $w: The width of the area to redraw.
  $h: The height of the area to redraw.
  */
  invalidate x/int y/int w/int h/int -> none:
    if change_tracker:
      transform_.xywh x y w h: | x2 y2 w2 h2 |
        change_tracker.child_invalidated x2 y2 w2 h2

  /**
  Moves to a new position in the coordinate system of the texture's transform.
  $new_x: New left edge in the texture's own coordinate system.
  $new_y: New top edge in the texture's own coordinate system.
  */
  move_to new_x/int new_y/int -> none:
    if new_x != x_ or new_y != y_:
      invalidate
      x_ = new_x
      y_ = new_y
      invalidate

  // Redraws in a tile that will be copied to a part of the display.
  write_ canvas/AbstractCanvas -> none:
    win_w := canvas.width_
    win_h := canvas.height_
    win_x := canvas.x_offset_
    win_y := canvas.y_offset_
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      if win_x + win_w <= x2: return  // Right hand side of window is to the left of this texture.
      if win_x >= x2 + w2: return     // Left hand side of window is to the right of this texture.
      if win_y + win_h <= y2: return  // Bottom of window is above this texture.
      if win_y >= y2 + h2: return     // Top of window is below this texture.
    write2_ canvas

  /**
  # Inheritance
  Override with method that will redraw in a file that will be copied to a
    part of the display.  Is not called for tiles that are wholly disjoint
    with the texture.
  */
  abstract write2_ canvas

abstract class ResizableTexture extends SizedTexture:
  constructor x/int y/int w/int h/int transform/Transform:
    super x y w h transform

  width= new_width/int:
    if new_width != w_:
      invalidate
      w_ = new_width
      invalidate

  height= new_height/int:
    if new_height != h_:
      invalidate
      h_ = new_height
      invalidate

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

// Texture that draws a standard EAN-13 bar code.  TODO: Other scales.
abstract class BarCodeEan13_ extends SizedTexture:
  sans10_ ::= Font.get "sans10"
  number_height_ := EAN_13_BOTTOM_SPACE

  code_ := ?  // 13 digit code as a string.

  /**
  $code_: The 13 digit product code.
  $x: The left edge of the barcode in the coordinate system of the transform.
  $y: The top edge of the barcode in the coordinate system of the transform.
  $transform: The coordinate system of the barcode.
  */
  constructor .code_/string x/int y/int transform/Transform:
    // The numbers go below the bar code in a way that depends on the size
    // of the digits, so we need to take that into account when calculating
    // the bounding box.
    number_height_ = (sans10_.text_extent "8")[1]
    height := EAN_13_HEIGHT + number_height_ - EAN_13_BOTTOM_SPACE
    w := EAN_13_WIDTH
    h := height + 1
    super x y w h transform

  l_ digit:
    return EAN_13_L_CODES_[digit & 0xf]

  g_ digit:
    return EAN_13_G_CODES_[digit & 0xf]

  r_ digit:
    return (l_ digit) ^ 0x7f

  // Make a white background behind the bar code and draw the digits along the bottom.
  draw_background_ canvas/AbstractCanvas:
    // Background of a bar code is always white (0 color).
    transform_.xywh x y w_ h_: | x2 y2 w2 h2 |
      white_square_
          x2 - canvas.x_offset_
          y2 - canvas.y_offset_
          w2
          h2
          canvas

    text_orientation := transform_.orientation_

    // Bar code coordinates.
    text_x := x + EAN_13_QUIET_ZONE_WIDTH + EAN_13_START_WIDTH
    text_y := y + EAN_13_HEIGHT + number_height_ - EAN_13_BOTTOM_SPACE + 1

    // Canvas coordinates.
    canvas_x := (transform_.x x + 1 text_y) - canvas.x_offset_
    canvas_y := (transform_.y x + 1 text_y) - canvas.y_offset_
    digit_ (code_.copy 0 1) canvas_x canvas_y canvas text_orientation

    canvas_x = (transform_.x text_x text_y) - canvas.x_offset_
    canvas_y = (transform_.y text_x text_y) - canvas.y_offset_
    step_x := (transform_.width 1 0)
    step_y := (transform_.height 1 0)
    (code_.copy 1 7).split "":
      if it != "":
        digit_ it canvas_x canvas_y canvas text_orientation
        canvas_x += EAN_13_DIGIT_WIDTH * step_x
        canvas_y += EAN_13_DIGIT_WIDTH * step_y
    canvas_x += (EAN_13_MIDDLE_WIDTH - 1) * step_x
    canvas_y += (EAN_13_MIDDLE_WIDTH - 1) * step_y
    (code_.copy 7 13).split "":
      if it != "":
        digit_ it canvas_x canvas_y canvas text_orientation
        canvas_x += EAN_13_DIGIT_WIDTH * step_x
        canvas_y += EAN_13_DIGIT_WIDTH * step_y
    marker_width := (sans10_.text_extent ">")[0]
    canvas_x += (EAN_13_START_WIDTH + EAN_13_QUIET_ZONE_WIDTH - marker_width) * step_x
    canvas_y += (EAN_13_START_WIDTH + EAN_13_QUIET_ZONE_WIDTH - marker_width) * step_y
    digit_ ">" canvas_x canvas_y canvas text_orientation

  // Draw a black rectangle from x,y sized width,height in canvas coordinates.
  abstract block_ x y width height canvas

  // Draw a white background rectangle from x,y sized width,height in canvas
  // coordinates.
  abstract white_square_ x y w h canvas

  // Draw a digit at x,y in canvas coordinates.
  abstract digit_ digit x y canvas orientation

  // Line in transform coordinates.
  line_ x top bottom canvas/AbstractCanvas transform:
    height := bottom - top
    transform.xywh x top 1 height: | x y w h |
      block_ x - canvas.x_offset_ y - canvas.y_offset_ w h canvas

  // Redraw routine.
  write2_ canvas/AbstractCanvas:
    win_x := canvas.x_offset_
    win_y := canvas.y_offset_
    draw_background_ canvas

    x := x_ + EAN_13_QUIET_ZONE_WIDTH
    top := y_

    bottom := y_ + EAN_13_HEIGHT
    y := bottom - EAN_13_BOTTOM_SPACE
    // Start bars: 101.
    line_ x     top bottom canvas transform_
    line_ x + 2 top bottom canvas transform_
    x += 3
    first_code := EAN_13_FIRST_CODES_[code_[0] & 0xf]
    // Left digits using the L or G mapping.
    for i := 1; i < 7; i++:
      digit := code_[i]
      code := ((first_code >> (6 - i)) & 1) == 0 ? (l_ digit) : (g_ digit)
      for b := 6; b >= 0; b--:
        if ((1 << b) & code) != 0:
          line_ x top y canvas transform_
        x++
    // Middle bars: 01010
    line_ x + 1 top bottom canvas transform_
    line_ x + 3 top bottom canvas transform_
    x += 5
    // Left digits using the R mapping.
    for i := 7; i < 13; i++:
      digit := code_[i]
      code := r_ digit
      for b := 6; b >= 0; b--:
        if ((1 << b) & code) != 0:
          line_ x top y canvas transform_
        x++
    // End bars: 101.
    line_ x     top bottom canvas transform_
    line_ x + 2 top bottom canvas transform_

TEXT_TEXTURE_ALIGN_LEFT ::= 0
TEXT_TEXTURE_ALIGN_CENTER ::= 1
TEXT_TEXTURE_ALIGN_RIGHT ::= 2

class TextExtent_:
  x := 0
  y := 0
  w := 0
  h := 0
  displacement := 0

  // Gets the graphical extent of a string nominally positioned at (0, 0),
  // Where the nominal position of the text is relative to the letters depends
  // on the alignment, but it is always somewhere on the textual baseline.
  // Some confusion is caused here by the fact that the y-axis of textures
  // grows towards the bottom, whereas the y-axis of fonts grows towards the
  // top.
  constructor text font alignment:
    box := font.text_extent text
    if alignment != TEXT_TEXTURE_ALIGN_LEFT:
      displacement = -(font.pixel_width text)
      if alignment == TEXT_TEXTURE_ALIGN_CENTER: displacement >>= 1
    w = box[0]
    h = box[1]
    x = box[2] + displacement
    y = -box[1] - box[3]

/**
A texture that represents the graphical display of a string.
*/
abstract class TextTexture_ extends SizedTexture:
  // Position in the coordinate system of the transform of the textual origin.
  // The actual text may extend below and to the left of this point, especially
  // with an alignment that is not TEXT_TEXTURE_ALIGN_LEFT.
  text_x_ := 0
  text_y_ := 0
  alignment_ := 0
  displacement := 0
  string_ := ?
  font_ := ?

  /**
  $text_x_: The X coordinate of the origin of the text string.  For left aligned
    text this is the left of the text string (though some characters may overhang the left
    edge, depending on the font).
  $text_y_: The Y coordinate of the origin of the text string.  This is the baseline
    of the text string (though some characters extend below the baseline).
  $transform: The coordinate system in which the string is placed.
  $string_: The actual text to be displayed.
  $font_: The font to display the string with.
  */
  constructor .text_x_/int .text_y_/int transform/Transform .alignment_/int .string_/string .font_/Font:
    extent := TextExtent_ string_ font_ alignment_
    displacement = extent.displacement
    super
      text_x_ + extent.x
      text_y_ + extent.y
      extent.w
      extent.h
      transform

  /**
  Returns the current text being displayed.
  */
  text -> string:
    return string_

  /**
  Returns the current alignment of the string, either
    TEXT_TEXTURE_ALIGN_LEFT, TEXT_TEXTURE_ALIGN_CENTER, or
    TEXT_TEXTURE_ALIGN_RIGHT.
  */
  alignment:
    return alignment_

  /**
  Set a new string for this TextTexture to display.  If the string
    is related to the previous string, it tries to find the minimum screen
    area that needs updating.
  */
  text= new_string/string -> none:
    if new_string == string_: return
    if not change_tracker:
      string_ = new_string
      fix_bounding_box_
      return

    get_bounding_boxes_ string_ new_string alignment_ font_: | changed_extent_old/TextExtent_ changed_extent_new/TextExtent_ |
      invalidate_extent_ changed_extent_old
      invalidate_extent_ changed_extent_new
      string_ = new_string
      fix_bounding_box_
      return
    string_ = new_string
    update_

  static get_bounding_boxes_ old/string new/string alignment/int font/Font [block]:
    left_doesnt_move  := alignment == TEXT_TEXTURE_ALIGN_LEFT
    right_doesnt_move := alignment == TEXT_TEXTURE_ALIGN_RIGHT
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
      if alignment == TEXT_TEXTURE_ALIGN_LEFT:
        unchanged_width := font.pixel_width old[..unchanged_left]
        changed_extent_old.x += unchanged_width
        changed_extent_new.x += unchanged_width
      else if alignment == TEXT_TEXTURE_ALIGN_RIGHT:
        unchanged_width := font.pixel_width old[old.size - unchanged_right..]
        // Make x relative to the text origin, which is the right edge.
        changed_extent_old.x -= unchanged_width
        changed_extent_new.x -= unchanged_width
      else:
        assert: alignment == TEXT_TEXTURE_ALIGN_CENTER
        assert: pixel_width_old == (font.pixel_width new)
        // Make x relative to the text origin, which is the middle.
        unchanged_width := ((pixel_width_old + 1) >> 1) - (font.pixel_width old[..unchanged_left])
        changed_extent_old.x -= unchanged_width + changed_extent_old.displacement
        changed_extent_new.x -= unchanged_width + changed_extent_new.displacement
      block.call changed_extent_old changed_extent_new

  invalidate_extent_ ex:
    invalidate
      text_x_ + ex.x
      text_y_ + ex.y
      ex.w
      ex.h

  /**
  Sets a new alignment for this TextTexture to display.
  */
  alignment= new_alignment/int -> none:
    if new_alignment == alignment_: return
    alignment_ = alignment
    update_

  /**
  Sets a new font for this TextTexture to display.
  */
  font= new_font/Font -> none:
    if new_font == font_: return
    font_ = new_font
    update_

  /**
  Sets the alignment of this TextTexture to "center".
  */
  center -> none:
    alignment = TEXT_TEXTURE_ALIGN_CENTER

  /**
  Sets the alignment of this TextTexture to "right".
  */
  align_right -> none:
    alignment = TEXT_TEXTURE_ALIGN_RIGHT

  /**
  Sets the alignment of this TextTexture to "left".
  */
  align_left -> none:
    alignment = TEXT_TEXTURE_ALIGN_LEFT

  /**
  Moves the text origin to new coordinates.
  */
  move_to new_x/int new_y/int -> none:
    if new_x == text_x_ and new_y == text_y_: return
    text_x_ = new_x
    text_y_ = new_y
    update_

  fix_bounding_box_:
    extent := TextExtent_ string_ font_ alignment_
    displacement = extent.displacement
    x_ = text_x_ + extent.x
    y_ = text_y_ + extent.y
    w_ = extent.w
    h_ = extent.h

  update_ -> none:
    invalidate
    fix_bounding_box_
    invalidate

  // After the textures under us have drawn themselves, we draw on top.
  write2_ canvas/AbstractCanvas:
    x2 := transform_.x text_x_ + displacement text_y_
    y2 := transform_.y text_x_ + displacement text_y_
    draw_
      x2 - canvas.x_offset_
      y2 - canvas.y_offset_
      transform_.orientation_
      canvas

  abstract draw_ bx by orientation canvas

/**
A rectangle in a solid color.
*/
abstract class FilledRectangle_ extends ResizableTexture:
  constructor x/int y/int w/int h/int transform/Transform:
    super x y w h transform

  // Draw a colored rectangle at x,y on the canvas.
  write2_ canvas/AbstractCanvas:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      start_x := x2 - canvas.x_offset_
      start_y := y2 - canvas.y_offset_
      translated_write_ start_x start_y w2 h2 canvas

  // Takes canvas coordinates.
  abstract translated_write_ x y w h canvas

  // A helper method to make lines out of our rectangle primitives.
  static line_ x1 y1 x2 y2 [build]:
    if x1 == x2:
      if y1 <= y2:
        return build.call x1 y1 1 y2 - y1
      else:
        return build.call x1 y2 1 y1 - y2
    else if y1 == y2:
      if x1 <= x2:
        return build.call x1 y1 x2 - x1 1
      else:
        return build.call x2 y1 x1 - x2 1
    else:
      throw "LINE_NOT_HORIZONTAL_OR_VERTICAL"


/**
A collections of textures which can be added to a display as a single texture.
  It is not visible, only the textures it contains are visible.  It has no
  dimensions.  Textures added to this group are drawn in the order they were
  added, so the first-added textures are at the back and the last-added are
  at the front.
*/
class TextureGroup extends Texture implements Window:
  elements_ := []

  add element -> none:
    elements_.add element
    element.change_tracker = this
    element.invalidate

  remove element -> none:
    element.invalidate
    elements_.remove element
    element.change_tracker = null

  remove_all -> none:
    elements_.do:
      it.invalidate
      it.change_tracker = null
    elements_ = []

  // After the textures under us have drawn themselves, we draw on top.
  write_ canvas/AbstractCanvas -> none:
    elements_.do: it.write canvas

  // We don't crop anything, just pass on the invalidation to the next higher Window.
  child_invalidated x/int y/int w/int h/int -> none:
    if change_tracker:
      change_tracker.child_invalidated x y w h

  child_invalidated_element x/int y/int w/int h/int -> none:
    throw "NOT_IMPLEMENTED"

  invalidate -> none:
    elements_.do: it.invalidate

/**
A display or a window within a display.
You can add and remove texture objects to a Window.  They will be drawn
  in the order they were added, where the first textures are at the back
  and are overwritten by textures added later.
*/
interface Window:
  add element /Texture -> none
  remove element /Texture -> none
  remove_all -> none

  // Called by elements that have been added to this.
  child_invalidated x/int y/int w/int h/int ->none

  // Called by elements that have been added to this.
  child_invalidated_element x/int y/int w/int h/int ->none

abstract class BorderlessWindowElement extends Element implements Window:
  inner_w_/int := ?
  inner_h_/int := ?
  elements_ := {}

  constructor --x/int --y/int --w/int --h/int:
    inner_w_ = w
    inner_h_ = h
    super --x=x --y=y

  add element/Element -> none:
    elements_.add element
    element.change_tracker = this
    element.invalidate

  remove element/Element -> none:
    elements_.remove element
    element.invalidate
    element.change_tracker = null

  remove_all -> none:
    elements_.do:
      it.invalidate
      it.change_tracker = null
    elements_.remove_all

  /**
  Calls the block with x, y, w, h, which includes the frame/border.
  */
  extent [block] -> none:
    block.call x_ y_ inner_w_ inner_h_

  child_invalidated_element x/int y/int w/int h/int -> none:
    if change_tracker:
      x2 := max x_ (x_ + x)
      y2 := max y_ (y_ + y)
      right := min (x_ + inner_w_) (x_ + x + w)
      bottom := min (y_ + inner_h_) (y_ + y + h)
      if x2 < right and y2 < bottom:
        change_tracker.child_invalidated_element x2 y2 (right - x2) (bottom - y2)

  child_invalidated x/int y/int w/int h/int -> none:
    throw "NOT_IMPLEMENTED"  // This is only for textures, but we don't allow those.

  invalidate:
    if change_tracker:
      extent: | outer_x outer_y outer_w outer_h |
        change_tracker.child_invalidated_element outer_x outer_y outer_w outer_h

/**
A WindowElement is a collections of elements.  It is modeled like a painting hung on
  a wall.  It consists (from back to front) of a wall, a frame and the painting
  itself. The optional frame extends around and behind the picture, and can be
  partially transparent on true-color displays, which enables drop shadows.  The
  painting can also be partially transparent.
*/
abstract class WindowElement extends BorderlessWindowElement implements Window:
  /**
  Changes the inner width (without any borders) of the window.
  */
  w= new_width/int:
    if new_width != inner_w_:
      invalidate
      inner_w_ = new_width
      invalidate

  /**
  Changes the inner height (without any borders) of the window.
  */
  h= new_height/int:
    if new_height != inner_h_:
      invalidate
      inner_h_ = new_height
      invalidate

  /**
  Gets the inner width (without any borders) of the window.
  */
  w -> int:
    return inner_w_

  /**
  Gets the inner height (without any borders) of the window.
  */
  h -> int:
    return inner_h_

  /**
  Changes the top left corner (without any borders) of the window.
  */
  move_to new_x/int new_y/int -> none:
    if new_x != x_ or new_y != y_:
      invalidate
      x_ = new_x
      y_ = new_y
      invalidate

  static ALL_TRANSPARENT ::= ByteArray 1: 0
  static ALL_OPAQUE ::= ByteArray 1: 0xff

  static is_all_transparent opacity -> bool:
    if opacity is not ByteArray: return false
    return opacity.size == 1 and opacity[0] == 0

  static is_all_opaque opacity -> bool:
    if opacity is not ByteArray: return false
    return opacity.size == 1 and opacity[0] == 0xff

  /**
  Returns a canvas that is an alpha map for the given area that describes where
    the wall around this window shines through.  This defines the edges and
    shadows of a window frame.  For 2-color and 3-color textures this is a
    bitmap with 0 for transparent and 1 for opaque.  For true-color and
    gray-scale textures it is a bytemap with 0 for transparent and 0xff for
    opaque.  As a special case it may return a single-entry byte array, which
    means all pixels have the same transparency.
  The coordinate system of the canvas is the coordinate system of the window, so
    the top and left edges will normally be plotted at negative coordinates.
  */
  abstract frame_map canvas/AbstractCanvas -> ByteArray

  /**
  Returns a canvas that is an alpha map for the given area that describes where
    the painting is visible.  This defines the edges of the content of this
    window.  For 2-color and 3-color textures this is a bitmap with 0 for
    transparent and 1 for opaque.  For true-color and gray-scale textures it is
    a bytemap with 0 for transparent and 0xff for opaque.  As a special case it
    may return a single-entry byte array, which means all pixels have the same
    transparency.
  The coordinate system of the canvas is the coordinate system of the window.
  */
  abstract painting_map canvas/AbstractCanvas -> ByteArray

  /**
  Draws the background on the canvas.  This represents the interior wall color
    and other interior objects will be draw on top of this.  Does not need to
    take the frame_map or painting_map into account: The canvas this function
    draws on will be composited using them afterwards.
  The coordinate system of the canvas is the coordinate system of the window.
  */
  abstract draw_background canvas/AbstractCanvas -> none

  /**
  Expected to draw the frame on the canvas.  This represents the window frame
    color.  Does not need to take the frame_map or painting_map into account: The
    return value from this function will be composited using them afterwards.
  The coordinate system of the canvas is the coordinate system of the window, so
    the top and left edges will normally be plotted at negative coordinates.
  */
  abstract draw_frame canvas

  constructor --x/int --y/int --w/int --h/int:
    super --x=x --y=y --w=w --h=h

  // After the textures under us have drawn themselves, we draw on top.
  draw canvas/AbstractCanvas -> none:
    extent: | x2 y2 w2 h2 |
      if (canvas.bounds_analysis x2 y2 w2 h2) == AbstractCanvas.ALL_OUTSIDE: return

    old_transform := canvas.transform
    canvas.transform = old_transform.translate x_ y_

    painting_opacity := painting_map canvas

    // If the window is 100% painting at these coordinates then we can draw the
    // elements of the window and no compositing is required.  We merely draw
    // the window background color and then draw the textures.
    if is_all_opaque painting_opacity:
      draw_background canvas
      elements_.do: it.draw canvas
      canvas.transform = old_transform
      return

    frame_opacity := frame_map canvas

    if is_all_transparent frame_opacity and is_all_transparent painting_opacity:
      canvas.transform = old_transform
      return

    // The complicated case where we have to composite the tile from the wall,
    // the frame, and the painting_opacity.
    frame_canvas := null
    if not is_all_transparent frame_opacity:
      frame_canvas = canvas.create_similar
      draw_frame frame_canvas

    painting_canvas := canvas.create_similar
    draw_background painting_canvas
    elements_.do: it.draw painting_canvas

    canvas.composit frame_opacity frame_canvas painting_opacity painting_canvas

    canvas.transform = old_transform

/**
A rectangular window with a fixed width colored border.  The border is
  added to the visible area inside the window.
*/
class SimpleWindowElement extends WindowElement:
  border_width_/int := ?
  border_color_/int? := ?
  background_color_/int? := ?

  constructor --x/int --y/int --w/int --h/int --border_width/int --border_color/int?=null --background_color/int?=null:
    if border_width < 0 or (border_width != 0 and border_color == null): throw "INVALID_ARGUMENT"
    border_width_ = border_width
    border_color_ = border_color
    background_color_ = background_color

    super --x=x --y=y --w=w --h=h  // Inner dimensions.

  extent [block]:
    block.call
        x - border_width_
        y - border_width_
        w + border_width_ * 2
        h + border_width_ * 2

  border_width -> int: return border_width_

  border_color -> int: return border_color_

  background_color -> int?: return background_color_

  border_width= new_width/int -> none:
    if new_width < 0 or (new_width != 0 and border_color_ == null): throw "INVALID_ARGUMENT"
    if new_width > border_width_:
      border_width_ = new_width
      invalidate
    else if new_width < border_width_:
      invalidate
      border_width_ = new_width

  border_color= new_color/int -> none:
    if new_color != border_color_:
      if border_width_ != 0: invalidate
      border_color_ = new_color

  background_color= new_color/int? -> none:
    if new_color != background_color_:
      if change_tracker:
        change_tracker.child_invalidated_element x_ y_ inner_w_ inner_h_
      background_color_ = new_color

  // Draws 100% opacity for the frame shape, a filled rectangle.
  // (The frame is behind the painting, so this doesn't mean we only
  // see the frame.)
  frame_map canvas/AbstractCanvas:
    if border_width_ == 0: return WindowElement.ALL_TRANSPARENT  // The frame is not visible anywhere.
    // Transform inner dimensions not including border
    canvas.transform.xywh 0 0 inner_w_ inner_h_: | x2 y2 w2 h2 |
      if x2 <= 0 and y2 <= 0 and x2 + w2 >= canvas.width_ and y2 + h2 >= canvas.height_:
        // In the middle, the window content is 100% opaque and draw on top of the
        // frame.  There is no need to provide a frame alpha map, so for efficiency we
        // just return 0 which indicates the frame is 100% transparent.
        return WindowElement.ALL_TRANSPARENT
    // Transform outer dimensions including border.
    outer_w := inner_w_ + 2 * border_width_
    outer_h := inner_h_ + 2 * border_width_
    canvas.transform.xywh -border_width_ -border_width_ outer_w outer_h: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if right <= 0 or bottom <= 0 or x2 >= canvas.width_ or y2 >= canvas.height_:
        // The frame is completely outside the window, so it is 100% transparent.
        return WindowElement.ALL_TRANSPARENT
    // We need to create a bitmap to describe the frame's extent.
    transparency_map := canvas.make_alpha_map
    // Declare the whole area inside the frame's extent opaque.  The window content will
    // draw on top of this as needed.
    transparency_map.rectangle -border_width -border_width_
        --w=outer_w
        --h=outer_h
        --color=0xffffff
    return transparency_map

  // Draws 100% opacity for the window content, a filled rectangle.
  painting_map canvas/AbstractCanvas:
    canvas.transform.xywh 0 0 inner_w_ inner_h_: | x2 y2 w2 h2 |
      if x2 <= 0 and y2 <= 0 and x2 + w2 >= canvas.width_ and y2 + h2 >= canvas.height_:
        return WindowElement.ALL_OPAQUE  // The content is 100% opaque in the middle.
      right := x2 + w2
      bottom := y2 + h2
      if right <= 0 or bottom <= 0 or x2 >= canvas.width_ or y2 >= canvas.height_:
        return WindowElement.ALL_TRANSPARENT  // The content is 100% transparent outside the window.
    // We need to create a bitmap to describe the content's extent.
    transparency_map := canvas.make_alpha_map
    // Declare the whole area inside the content's extent opaque.  The window content will
    // draw on top of this as needed.
    transparency_map.rectangle 0 0
      --w=inner_w_
      --h=inner_h_
      --color=0xffffff
    return transparency_map

  draw_frame canvas/AbstractCanvas:
    if border_width_ != 0: canvas.set_all_pixels border_color_

  draw_background canvas/AbstractCanvas:
    if background_color_: canvas.set_all_pixels background_color_

/** A rectangular window with rounded corners. */
class RoundedCornerWindowElement extends WindowElement:
  corner_radius_/int := ?
  background_color_/int? := ?
  opacities_ := null
  bit_opacities_ := null
  shadow_palette_/ByteArray := #[]

  constructor --x/int --y/int --w/int --h/int --corner_radius/int=5 --background_color/int?=null:
    if not 0 <= corner_radius <= TABLE_SIZE_: throw "OUT_OF_RANGE"
    corner_radius_ = corner_radius
    background_color_ = background_color
    super --x=x --y=y --w=w --h=h

  corner_radius -> int: return corner_radius_

  corner_radius= new_radius/int -> none:
    if not 0 <= new_radius <= TABLE_SIZE_: throw "OUT_OF_RANGE"
    if new_radius != corner_radius_:
      opacities_ = null
      invalid_radius := max corner_radius_ new_radius
      corner_radius_ = new_radius
      if change_tracker:
        change_tracker.child_invalidated_element x                      y                      invalid_radius invalid_radius
        change_tracker.child_invalidated_element x + w - invalid_radius y                      invalid_radius invalid_radius
        change_tracker.child_invalidated_element x                      y + h - invalid_radius invalid_radius invalid_radius
        change_tracker.child_invalidated_element x + w + invalid_radius y + h - invalid_radius invalid_radius invalid_radius

  extent [block]:
    block.call x y w h   // Does not protrude beyond the inner bounds.

  ensure_opacities_:
    if opacities_: return

    opacities_ = ByteArray corner_radius_ * corner_radius_
    downsample := TABLE_SIZE_ / corner_radius_  // For example 81 for a corner_radius of 3.
    steps := List corner_radius_:
      (it * TABLE_SIZE_) / corner_radius
    corner_radius_.repeat: | j |
      b := steps[j]
      corner_radius_.repeat: | i |
        a := steps[i]
        idx := j * corner_radius_ + i
        // Set the opacity according to whether the downsample x downsample
        // square is fully outside the circle, fully inside the circle or on
        // the edge.
        if QUARTER_CIRCLE_[b + downsample - 1] >= a + downsample:
          opacities_[idx] = 0xff  // Inside quarter circle.
        else if QUARTER_CIRCLE_[b] < a:
          opacities_[idx] = 0  // Outside quarter circle.
        else:
          // Edge of quarter circle.
          total := 0
          downsample.repeat: | small_y |
            extent := QUARTER_CIRCLE_[b + small_y]
            if extent >= a + downsample:
              total += downsample
            else if extent > a:
              total += extent - a
          opacities_[idx] = (0xff * total) / (downsample * downsample)
    // Generate a bit version of the opacities in case we have to use it on a
    // 2-color or 3-color display.
    bitmap_width := round_up corner_radius_ 8
    bit_opacities_ = ByteArray (opacities_.size / corner_radius_) * (bitmap_width >> 3)
    destination_line_stride := bitmap_width >> 3
    8.repeat: | bit |
      blit opacities_[bit..] bit_opacities_ ((corner_radius_ + 7 - bit) >> 3)
          --source_pixel_stride=8
          --source_line_stride=corner_radius_
          --destination_line_stride=destination_line_stride
          --shift=bit
          --mask=(0x80 >> bit)
          --operation=OR

  frame_map canvas/AbstractCanvas:
    return WindowElement.ALL_TRANSPARENT  // No frame on these windows.

  static TABLE_SIZE_ ::= 256
  // The heights of a top-right quarter circle of radius [TABLE_SIZE_].
  static QUARTER_CIRCLE_ ::= create_quarter_circle_array_ TABLE_SIZE_

  static create_quarter_circle_array_ size:
    array := ByteArray size
    hypotenuse := (size - 1) * (size - 1)
    size.repeat:
      array[it] = (hypotenuse - it * it).sqrt.to_int
    return array

  // Draws 100% opacity for the window content, a filled rounded-corner rectangle.
  painting_map canvas/AbstractCanvas:
    canvas.transform.xywh 0 0 inner_w_ inner_h_: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if x2 >= canvas.width_ or y2 >= canvas.height_ or right <= 0 or bottom <= 0:
        return WindowElement.ALL_TRANSPARENT  // The content is 100% transparent outside the window.
      if x2                  <= 0 and y2 + corner_radius_ <= 0 and right                  >= canvas.width_ and bottom - corner_radius_ >= canvas.height_ or
         x2 + corner_radius_ <= 0 and y2                  <= 0 and right - corner_radius_ >= canvas.width_ and bottom                  >= canvas.height_:
        return WindowElement.ALL_OPAQUE  // The content is 100% opaque in the cross in the middle where there are no corners.
    // We need to create a bitmap to describe the content's extent.
    transparency_map := canvas.make_alpha_map
    draw_rounded_corners_ transparency_map 0 0 inner_w_ inner_h_ 0xff
    return transparency_map

  draw_rounded_corners_ transparency_map x2/int y2/int w2/int h2/int opacity/int -> none:
    // Part 1 of a cross of opacity (the rounded rectangle minus its corners).
    transparency_map.rectangle (x2 + corner_radius_) y2 --w=(w2 - 2 * corner_radius_) --h=h2 --color=opacity
    if corner_radius_ == 0: return
    ensure_opacities_
    // Part 2 of the cross.
    transparency_map.rectangle x2 (y2 + corner_radius_) --w=w2 --h=(h2 - 2 * corner_radius_) --color=opacity
    // The rounded corners.
    // opacity_ has an alpha map shaped like this (only rounder).
    // ______
    // |    |
    // |    /
    // |___/

    left := x2 + corner_radius_ - 1
    right := x2 + w2 - corner_radius_
    top := y2 + corner_radius_ - 1
    bottom := y2 + h2 - corner_radius_
    if transparency_map is one_byte.OneByteCanvas_:
      palette := opacity == 0xff ? #[] : shadow_palette_
      draw_corners_ x2 y2 right bottom corner_radius_: | x y orientation |
        transparency_map.draw_pixmap x y --pixels=opacities_ --palette=palette --pixmap_width=corner_radius_ --orientation=orientation
    else:
      draw_corners_ x2 y2 right bottom corner_radius_: | x y orientation |
        transparency_map.draw_bitmap x y --pixels=bit_opacities_ --color=1 --pixmap_width=corner_radius_ --orientation=orientation

  draw_corners_ left/int top/int right/int bottom/int corner_radius/int [block]:
    // Top left corner:
    block.call (left + corner_radius) (top + corner_radius) ORIENTATION_180
    // Top right corner:
    block.call right (top + corner_radius) ORIENTATION_90
    // Bottom left corner:
    block.call (left + corner_radius) bottom ORIENTATION_270
    // Bottom right corner:
    block.call right bottom ORIENTATION_0

  draw_frame canvas/AbstractCanvas:
    throw "NOT_IMPLEMENTED"  // There's no frame.

  draw_background canvas/AbstractCanvas:
    if background_color_: canvas.set_all_pixels background_color_

class DropShadowWindowElement extends RoundedCornerWindowElement:
  blur_radius_/int := ?
  drop_distance_x_/int := ?
  drop_distance_y_/int := ?
  shadow_opacity_percent_/int := ?

  constructor --x/int --y/int --w/int --h/int --corner_radius/int=5 --blur_radius/int=5 --drop_distance_x/int=10 --drop_distance_y/int=10 --shadow_opacity_percent/int=25:
    if not 0 <= blur_radius <= 6: throw "OUT_OF_RANGE"
    blur_radius_ = blur_radius
    drop_distance_x_ = drop_distance_x
    drop_distance_y_ = drop_distance_y
    shadow_opacity_percent_ = shadow_opacity_percent
    super --x=x --y=y --w=w --h=h --corner_radius=corner_radius
    update_shadow_palette_

  extent_helper_ [block]:
    extension_left := blur_radius_ > drop_distance_x_ ?  blur_radius_ - drop_distance_x_ : 0
    extension_top := blur_radius_ > drop_distance_y_ ?  blur_radius_ - drop_distance_y_ : 0
    extension_right := blur_radius_ > -drop_distance_x_ ? blur_radius_ + drop_distance_x_ : 0
    extension_bottom := blur_radius_ > -drop_distance_y_ ? blur_radius_ + drop_distance_y_ : 0
    block.call extension_left extension_top extension_right extension_bottom

  extent [block]:
    extent_helper_: | left top right bottom |
      block.call
          x - left
          y - top
          w + left + right
          h + top + bottom

  blur_radius -> int: return blur_radius_

  drop_distance_x -> int: return drop_distance_x_

  drop_distance_y -> int: return drop_distance_y_

  shadow_opacity_percent -> int: return shadow_opacity_percent_

  blur_radius= new_radius/int -> none:
    if not 0 <= new_radius <= 6: throw "OUT_OF_RANGE"
    if new_radius > blur_radius_:
      blur_radius_ = new_radius
      invalidate
    else if new_radius < blur_radius_:
      invalidate
      blur_radius_ = new_radius

  drop_distance_x= new_distance/int -> none:
    if new_distance != drop_distance_x_:
      invalidate
      drop_distance_x_ = new_distance
      invalidate

  drop_distance_y= new_distance/int -> none:
    if new_distance != drop_distance_y_:
      invalidate
      drop_distance_y_ = new_distance
      invalidate

  shadow_opacity_percent= new_percent/int -> none:
    if new_percent != shadow_opacity_percent_:
      invalidate
      shadow_opacity_percent_ = new_percent
      update_shadow_palette_

  update_shadow_palette_ -> none:
    max_shadow_opacity := (shadow_opacity_percent_ * 2.5500001).to_int
    shadow_palette_ = #[]
    if max_shadow_opacity != 0xff:
      shadow_palette_ = ByteArray 0x300: ((it / 3) * max_shadow_opacity) / 0xff

  frame_map canvas/AbstractCanvas:
    // Transform inner dimensions excluding shadow to determine if the canvas
    // is wholly inside the window.
    canvas.transform.xywh 0 0 inner_w_ inner_h_: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if x2                  <= 0 and y2 + corner_radius_ <= 0 and right                  >= canvas.width_ and bottom - corner_radius_ >= canvas.height_ or
         x2 + corner_radius_ <= 0 and y2                  <= 0 and right - corner_radius_ >= canvas.width_ and bottom                  >= canvas.height_:
        // In the middle, the window content is 100% opaque and draw on top of the
        // frame.  There is no need to provide a frame alpha map, so for efficiency we
        // just return 0 which indicates the frame is 100% transparent.
        return WindowElement.ALL_TRANSPARENT

    // Transform outer dimensions including border to determine if the canvas
    // is wholly outside the window and its shadow.
    extent_helper_: | left top right bottom |
      canvas.transform.xywh -left -top (inner_w_ + left + right) (inner_h_ + top + bottom): | x2 y2 w2 h2 |
        if x2 + w2 <= 0 or y2 + h2 <= 0 or x2 >= canvas.width_ or y2 >= canvas.height_:
          return WindowElement.ALL_TRANSPARENT  // The frame is not opaque outside the shadow

    // Create a bitmap to describe the frame's extent.  It needs to be padded
    // relative to the canvas size so we can use the Gaussian blur.
    transparency_map := canvas.make_alpha_map --padding=(blur_radius * 2)
    transparency_map.transform = (canvas.transform.invert.translate -blur_radius -blur_radius).invert

    max_shadow_opacity := (shadow_opacity_percent * 2.5500001).to_int
    draw_rounded_corners_ transparency_map drop_distance_x_ drop_distance_y_ inner_w_ inner_h_ max_shadow_opacity

    if blur_radius == 0 or transparency_map is not one_byte.OneByteCanvas_:
      return transparency_map

    one_byte_map := transparency_map as one_byte.OneByteCanvas_

    // Blur the shadow.
    bytemap_blur one_byte_map.pixels_ transparency_map.width_ blur_radius

    // Crop off the extra that was added to blur.
    transparency_map_unpadded := canvas.make_alpha_map
    blit
        one_byte_map.pixels_[blur_radius + blur_radius * one_byte_map.width_..]   // Source.
        (transparency_map_unpadded as one_byte.OneByteCanvas_).pixels_  // Destination.
        transparency_map_unpadded.width_   // Bytes per line.
        --source_line_stride=transparency_map.width_
    return transparency_map_unpadded

  draw_frame canvas/AbstractCanvas:
    canvas.set_all_pixels 0

abstract class BitmapTextureBase_ extends SizedTexture:
  w := 0
  h := 0
  bytes_per_line_ /int

  constructor x/int y/int .w .h transform/Transform:
    bytes_per_line_ = (w + 7) >> 3  // Divide by 8, rounding up.
    super x y w h transform

  index_and_mask_ x y [block]:
    if not 0 <= x < w: throw "OUT_OF_RANGE"
    if not 0 <= y < h: throw "OUT_OF_RANGE"
    index := (x >> 3) + (y * bytes_per_line_)
    bit := 0x80 >> (x & 7)
    block.call index bit

  // After the textures under us have drawn themselves, we draw on top.
  write2_ canvas/AbstractCanvas:
    if w == 0 or h == 0: return
    x2 := transform_.x x_ y_
    y2 := transform_.y x_ y_
    draw_
      x2 - canvas.x_offset_
      y2 - canvas.y_offset_
      transform_.orientation_
      canvas

  abstract draw_ bx by orientation canvas

abstract class BitmapTexture_ extends BitmapTextureBase_:
  bytes_ /ByteArray? ::= null

  constructor x/int y/int w/int h/int transform/Transform:
    bytes_per_line := (w + 7) >> 3  // Divide by 8, rounding up.
    bytes_ = ByteArray h * bytes_per_line
    super x y w h transform

  constructor.no_allocate_ x/int y/int w/int h/int transform/Transform:
    super x y w h transform

  pixel_is_set x/int y/int -> bool:
    index_and_mask_ x y: | index bit |
      return (bytes_[index] & bit) != 0
    unreachable

  set_pixel x/int y/int -> none:
    index_and_mask_ x y: | index bit |
      bytes_[index] |= bit

  clear_pixel x/int y/int -> none:
    index_and_mask_ x y: | index bit |
      bytes_[index] &= 0xff ^ bit

  set_all_pixels -> none:
    bitmap_zap bytes_ 1

  clear_all_pixels -> none:
    bitmap_zap bytes_ 0

abstract class PixmapTexture_ extends SizedTexture:
  w /int
  h /int

  constructor x/int y/int .w .h transform/Transform:
    super x y w h transform

  // After the textures under us have drawn themselves, we draw on top.
  write2_ canvas/AbstractCanvas:
    if w == 0 or h == 0: return
    x2 := transform_.x x_ y_
    y2 := transform_.y x_ y_
    draw_
      x2 - canvas.x_offset_
      y2 - canvas.y_offset_
      transform_.orientation_
      canvas

  abstract draw_ bx by orientation canvas

class PbmParser_:
  static INVALID_PBM_ ::= "INVALID PBM"

  bytes_ /ByteArray
  next_ := 0

  width := 0
  height := 0
  rows_ := null
  row_byte_length_ := 0
  image_data_offset := 0

  constructor bytes/ByteArray:
    bytes_ = bytes

  parse_:
    parse_magic_number_
    parse_multiple_whitespace_
    width = parse_number_
    parse_multiple_whitespace_ --at_least_one
    height = parse_number_
    parse_whitespace_
    image_data_offset = next_
    parse_bit_map_

  parse_magic_number_:
    if not (bytes_.size > next_ + 1 and bytes_[next_] == 'P' and bytes_[next_ + 1] == '4'): throw INVALID_PBM_
    next_ += 2

  parse_whitespace_:
    if not (bytes_.size > next_ and is_pbm_whitespace_ bytes_[next_]): throw INVALID_PBM_
    next_++

  parse_multiple_whitespace_ --at_least_one=false:
    start := next_
    while bytes_.size > next_ and is_pbm_whitespace_ bytes_[next_]: next_++
    if bytes_.size > next_ and bytes_[next_] == '#':  // Skip comment.
      while bytes_.size > next_ and bytes_[next_] != '\n': next_++
      if bytes_.size > next_: next_++
    if at_least_one and start == next_: throw INVALID_PBM_

  parse_number_ -> int:
    next_ws := next_
    while next_ws < bytes_.size and not is_pbm_whitespace_ bytes_[next_ws]: next_ws++
    if not bytes_.is_valid_string_content next_ next_ws: throw INVALID_PBM_
    number_string := bytes_.to_string next_ next_ws
    number := int.parse number_string --on_error=: throw INVALID_PBM_
    next_ = next_ws
    return number

  parse_bit_map_:
    row_byte_length_ = width / 8 + (width % 8 == 0 ? 0 : 1)
    if not bytes_.size > row_byte_length_ * height: throw INVALID_PBM_

  rows:
    if not rows_:
      rows_ = List height:
        from := next_
        next_ = next_ + row_byte_length_
        bytes_.copy from next_
    return rows_

  is_pbm_whitespace_ byte -> bool:
    return byte == '\t' or byte == '\v' or byte == ' ' or byte == '\n' or byte == '\r' or byte == '\f'
