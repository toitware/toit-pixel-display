// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import binary show LITTLE_ENDIAN
import bitmap show *
import .four_gray as four_gray
import .true_color as true_color
import .gray_scale as gray_scale
import .one_byte as one_byte
import .style
import .common
import .bar_code_impl_
import font show Font
import math

import png_tools.png_reader show *

abstract class Element extends ElementOrTexture_ implements Window:
  style_/Style? := ?
  classes/List? := ?
  id/string? := ?
  children/List? := ?
  background_ := null
  border_/Border? := null

  x_ /int? := null
  y_ /int? := null

  x -> int?: return x_
  y -> int?: return y_

  constructor
      --x/int?=null
      --y/int?=null
      --style/Style?=null
      --element_class/string?=null
      --.classes/List?=null
      --.id/string?=null
      --background=null
      --border/Border?=null
      .children/List?=null:
    x_ = x
    y_ = y
    style_ = style
    if element_class:
      if not classes: classes = []
      classes.add element_class
    background_=background
    border_=border

  get_element_by_id id/string:
    if id == this.id: return this
    if children:
      children.do: | child/Element |
        found := child.get_element_by_id id
        if found: return found
    return null

  add element/Element -> none:
    if not children: children = []
    children.add element
    element.change_tracker = this
    element.invalidate

  remove element/Element -> none:
    if children:
      children.remove element
      element.invalidate
      element.change_tracker = null

  child_invalidated x/int y/int w/int h/int -> none:
    unreachable  // This is only for textures, but we don't allow those.

  remove_all -> none:
    children.do:
      it.invalidate
      it.change_tracker = null
    children = null

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

  border= value/Border?:
    if value != border_:
      invalidate
      border_ = value
      invalidate

  background -> Background?:
    return background_

  background= value/Background?:
    if value != background_:
      invalidate
      background_ = value
      invalidate

  write_ canvas -> none:
    throw "Can't call write_ on an Element"

  abstract draw canvas/Canvas -> none
  abstract min_w -> int
  abstract min_h -> int

  child_invalidated_element x/int y/int w/int h/int -> none:
    if change_tracker:
      x2 := max x_ (x_ + x)
      y2 := max y_ (y_ + y)
      right := min (x_ + this.w) (x_ + x + w)
      bottom := min (y_ + this.h) (y_ + y + h)
      if x2 < right and y2 < bottom:
        change_tracker.child_invalidated_element x2 y2 (right - x2) (bottom - y2)

  abstract w -> int?
  abstract h -> int?

  set_styles styles/List -> none:
    styles_for_children := null
    install_style := : | style/Style |
      style.matching_styles --type=type --classes=classes --id=id: | style/Style |
        style.iterate_properties: | key/string value |
          set_attribute key value
        if children:
          if not styles_for_children: styles_for_children = styles.copy
          styles_for_children.add style
    styles.do install_style
    if style_:
      style_.iterate_properties: | key/string value |
        set_attribute key value
      install_style.call style_
    if children:
      children.do: | child/Element |
        child.set_styles (styles_for_children or styles)

  set_attribute key/string value -> none:
    if key == "background":
      if background_ != value:
        invalidate
        background_ = value

  abstract type -> string

interface ColoredElement:
  color -> int?
  color= value/int -> none

class Div extends Element:
  w_ /int? := null
  h_ /int? := null

  type -> string: return "div"

  constructor
      --x/int?=null
      --y/int?=null
      --w/int?=null
      --h/int?=null
      --style/Style?=null
      --element_class/string?=null
      --classes/List?=null
      --id/string?=null
      --background=null
      --border/Border?=null
      children/List?=null:
    w_ = w
    h_ = h
    super --x=x --y=y --style=style --element_class=element_class --classes=classes --id=id --background=background --border=border children

  invalidate:
    if change_tracker and x and y and w and h:
      change_tracker.child_invalidated_element x y w h

  w -> int?: return w_
  h -> int?: return h_

  w= value/int? -> none:
    if w_ != value:
      if w_: invalidate
      w_ = value
      if value: invalidate

  h= value/int? -> none:
    if h_ != value:
      if h_: invalidate
      h_ = value
      if value: invalidate

  set_size w/int h/int -> none:
    if w_ != w or h_ != h:
      if w_ and h_: invalidate
      w_ = w
      h_ = h
      invalidate

  min_w: return w_
  min_h: return h_

  set_attribute key/string value -> none:
    if key == "width":
      w = value
    else if key == "height":
      h = value

  draw canvas/Canvas -> none:
    Background.draw background_ canvas x y w h
    if border_: border_.draw canvas x y w h

class Label extends Element implements ColoredElement:
  color_/int := ?
  label_/string := ?
  alignment_/int := ?
  orientation_/int := ?
  font_/Font? := ?
  left_/int? := null
  top_/int? := null
  width_/int? := null
  height_/int? := null
  min_w_/int? := null
  min_h_/int? := null

  type -> string: return "label"

  set_attribute key/string value -> none:
    if key == "color":
      color = value
    else if key == "font":
      font = value

  color -> int?: return color_

  color= value/int -> none:
    if color_ != value:
      color_ = value
      invalidate

  font -> Font?: return font_

  font= value/Font -> none:
    if font_ != value:
      font_ = value
      min_w_ = null
      min_h_ = null
      left_ = null  // Trigger recalculation.
      invalidate

  constructor --x/int?=null --y/int?=null --color/int=0 --label/string="" --font/Font?=null --orientation/int=ORIENTATION_0 --alignment/int=ALIGN_LEFT:
    color_ = color
    label_ = label
    alignment_ = alignment
    orientation_ = orientation
    font_ = font
    super --x=x --y=y

  min_w -> int:
    if not min_w_:
      if orientation_ == ORIENTATION_0 or orientation_ == ORIENTATION_180:
        min_w_ = font_.pixel_width label_
      else:
        min_w_ = (font_.text_extent label_)[1]
    return min_w_

  min_h -> int:
    if not min_h_:
      if orientation_ == ORIENTATION_0 or orientation_ == ORIENTATION_180:
        min_h_ = (font_.text_extent label_)[1]
      else:
        min_h_ = font_.pixel_width label_
    return min_h_

  /**
  Calls the block with the left, top, width, and height.
  For zero sized objects, doesn't call the block.
  */
  xywh_ [block]:
    if not left_:
      extent/List := font_.text_extent label_
      displacement := 0
      if alignment_ != ALIGN_LEFT:
        displacement = (font_.pixel_width label_)
        if alignment_ == ALIGN_CENTER: displacement >>= 1
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

  w -> int:
    if not left_:
      xywh_: null
    return width_

  h -> int:
    if not left_:
      xywh_: null
    return height_

  invalidate:
    if change_tracker and x and y:
      xywh_: | x y w h |
        change_tracker.child_invalidated_element x y w h

  label= value/string -> none:
    if value == label_: return
    if orientation_ == ORIENTATION_0 and change_tracker and x and y:
      text_get_bounding_boxes_ label_ value alignment_ font_: | old/TextExtent_ new/TextExtent_ |
        change_tracker.child_invalidated_element (x_ + old.x) (y_ + old.y) old.w old.h
        change_tracker.child_invalidated_element (x_ + new.x) (y_ + new.y) new.w new.h
        label_ = value
        min_w_ = null  // Trigger recalculation.
        left_ = null  // Trigger recalculation.
        return
    invalidate
    label_ = value
    min_w_ = null
    min_h_ = null
    left_ = null  // Trigger recalculation.
    invalidate

  orientation= value/int -> none:
    if value == orientation_: return
    min_w_ = null
    min_h_ = null
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

  draw canvas /Canvas -> none:
    x := x_
    y := y_
    if not (x and y): return
    if alignment_ != ALIGN_LEFT:
      text_width := font_.pixel_width label_
      if alignment_ == ALIGN_CENTER: text_width >>= 1
      if orientation_ == ORIENTATION_0:
        x -= text_width
      else if orientation_ == ORIENTATION_90:
        y += text_width
      else if orientation_ == ORIENTATION_180:
        x += text_width
      else:
        assert: orientation_ == ORIENTATION_270
        y -= text_width
    canvas.text x y --text=label_ --color=color_ --font=font_ --orientation=orientation_

/**
A superclass for elements that can draw themselves.  Override the
  $draw method in your subclass to draw on the canvas.  The $w
  and $h methods/fields are used to determine the size of the element
  for redrawing purposes.

Drawing operations are not automatically clipped to w and h, but if you
  draw outside the area then partial screen updates will be broken.
*/
abstract class CustomElement extends Element:
  abstract w -> int?
  abstract h -> int?

  constructor --x/int?=null --y/int?=null:
    super --x=x --y=y

  invalidate:
    if change_tracker and x and y and w and h:
      change_tracker.child_invalidated_element x y w h

// Element that draws a standard EAN-13 bar code.  TODO: Other scales.
class BarCodeEanElement extends CustomElement:
  w/int
  h/int
  color_/int? := 0
  background_ := 0xff
  sans10_ ::= Font.get "sans10"
  number_height_ := EAN_13_BOTTOM_SPACE

  type -> string: return "bar-code-ean"

  set_attribute key/string value -> none:
    if key == "color":
      if color_ != value:
        invalidate
        color_ = value
    else if key == "background":
      if background_ != value:
        invalidate
        background_ = value

  min_w: return w
  min_h: return h

  code_ := ?  // 13 digit code as a string.

  code= value/string -> none:
    if value != code_: invalidate
    code_ = value

  code -> string: return code_

  /**
  $code_: The 13 digit product code.
  $x: The left edge of the barcode in the coordinate system of the transform.
  $y: The top edge of the barcode in the coordinate system of the transform.
  Use $set_styles to set the background to white and the color to black.
  */
  constructor .code_/string x/int?=null y/int?=null:
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
  draw_background_ canvas/Canvas:
    if not (x and y): return
    Background.draw background_ canvas x_ y_ w h

    // Bar code coordinates.
    text_x := x + EAN_13_QUIET_ZONE_WIDTH + EAN_13_START_WIDTH
    text_y := y + EAN_13_HEIGHT + number_height_ - EAN_13_BOTTOM_SPACE + 1

    canvas.text (x + 1) text_y --text=code_[..1] --color=color_ --font=sans10_

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
  draw canvas/Canvas:
    if not (x and y): return
    if (canvas.bounds_analysis x y w h) == Canvas.ALL_OUTSIDE: return
    draw_background_ canvas

    x := x_ + EAN_13_QUIET_ZONE_WIDTH
    top := y_
    long_height := EAN_13_HEIGHT
    short_height := EAN_13_HEIGHT - EAN_13_BOTTOM_SPACE
    // Start bars: 101.
    canvas.rectangle x     top --w=1 --h=long_height --color=color_
    canvas.rectangle x + 2 top --w=1 --h=long_height --color=color_
    x += 3
    first_code := EAN_13_FIRST_CODES_[code_[0] & 0xf]
    // Left digits using the L or G mapping.
    for i := 1; i < 7; i++:
      digit := code_[i]
      code := ((first_code >> (6 - i)) & 1) == 0 ? (l_ digit) : (g_ digit)
      for b := 6; b >= 0; b--:
        if ((1 << b) & code) != 0:
          canvas.rectangle x top --w=1 --h=short_height --color=color_
        x++
    // Middle bars: 01010
    canvas.rectangle x + 1 top --w=1 --h=long_height --color=color_
    canvas.rectangle x + 3 top --w=1 --h=long_height --color=color_
    x += 5
    // Left digits using the R mapping.
    for i := 7; i < 13; i++:
      digit := code_[i]
      code := r_ digit
      for b := 6; b >= 0; b--:
        if ((1 << b) & code) != 0:
          canvas.rectangle x top --w=1 --h=short_height --color=color_
        x++
    // End bars: 101.
    canvas.rectangle x     top --w=1 --h=long_height --color=color_
    canvas.rectangle x + 2 top --w=1 --h=long_height --color=color_

abstract class BorderlessWindowElement extends Div implements Window:

  constructor --x/int?=null --y/int?=null --w/int?=null --h/int?=null:
    super --x=x --y=y --w=w --h=h

  /**
  Calls the block with x, y, w, h, which includes the frame/border.
  */
  extent [block] -> none:
    block.call x_ y_ w_ h_

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
  abstract frame_map canvas/Canvas -> ByteArray

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
  abstract painting_map canvas/Canvas -> ByteArray

  /**
  Draws the background on the canvas.  This represents the interior wall color
    and other interior objects will be draw on top of this.  Does not need to
    take the frame_map or painting_map into account: The canvas this function
    draws on will be composited using them afterwards.
  The coordinate system of the canvas is the coordinate system of the window.
  */
  abstract draw_background canvas/Canvas -> none

  /**
  Expected to draw the frame on the canvas.  This represents the window frame
    color.  Does not need to take the frame_map or painting_map into account: The
    return value from this function will be composited using them afterwards.
  The coordinate system of the canvas is the coordinate system of the window, so
    the top and left edges will normally be plotted at negative coordinates.
  */
  abstract draw_frame canvas

  constructor --x/int?=null --y/int?=null --w/int?=null --h/int?=null:
    super --x=x --y=y --w=w --h=h

  // After the textures under us have drawn themselves, we draw on top.
  draw canvas/Canvas -> none:
    if not (x and y and h and w): return
    extent: | x2 y2 w2 h2 |
      if (canvas.bounds_analysis x2 y2 w2 h2) == Canvas.ALL_OUTSIDE: return

    old_transform := canvas.transform
    canvas.transform = old_transform.translate x_ y_

    painting_opacity := painting_map canvas

    // If the window is 100% painting at these coordinates then we can draw the
    // elements of the window and no compositing is required.  We merely draw
    // the window background color and then draw the textures.
    if is_all_opaque painting_opacity:
      draw_background canvas
      children.do: it.draw canvas
      canvas.transform = old_transform
      return

    frame_opacity := frame_map canvas

    if is_all_transparent frame_opacity and is_all_transparent painting_opacity:
      canvas.transform = old_transform
      return

    // The complicated case where we have to composit the tile from the wall,
    // the frame, and the painting_opacity.
    frame_canvas := null
    if not is_all_transparent frame_opacity:
      frame_canvas = canvas.create_similar
      draw_frame frame_canvas

    painting_canvas := canvas.create_similar
    draw_background painting_canvas
    children.do: it.draw painting_canvas

    canvas.composit frame_opacity frame_canvas painting_opacity painting_canvas

    canvas.transform = old_transform

  type -> string: return "window"

  set_attribute key/string value -> none:
    if key == "width":
      w = value
    else if key == "height":
      h = value

/**
A rectangular window with a fixed width colored border.  The border is
  added to the visible area inside the window.
*/
class SimpleWindowElement extends WindowElement:
  border_width_/int := ?
  border_color_/int? := ?
  background_color_/int? := ?

  constructor --x/int?=null --y/int?=null --w/int?=null --h/int?=null --border_width/int=0 --border_color/int=0 --background_color/int=0xffffff:
    if border_width < 0 or (border_width != 0 and border_color == null): throw "INVALID_ARGUMENT"
    border_width_ = border_width
    border_color_ = border_color
    background_color_ = background_color

    super --x=x --y=y --w=w --h=h  // Inner dimensions.

  extent [block]:
    if x and y and w and h:
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
        change_tracker.child_invalidated_element x_ y_ w_ h_
      background_color_ = new_color

  // Draws 100% opacity for the frame shape, a filled rectangle.
  // (The frame is behind the painting, so this doesn't mean we only
  // see the frame.)
  frame_map canvas/Canvas:
    if border_width_ == 0: return WindowElement.ALL_TRANSPARENT  // The frame is not visible anywhere.
    // Transform inner dimensions not including border
    canvas.transform.xywh 0 0 w_ h_: | x2 y2 w2 h2 |
      if x2 <= 0 and y2 <= 0 and x2 + w2 >= canvas.width_ and y2 + h2 >= canvas.height_:
        // In the middle, the window content is 100% opaque and draw on top of the
        // frame.  There is no need to provide a frame alpha map, so for efficiency we
        // just return 0 which indicates the frame is 100% transparent.
        return WindowElement.ALL_TRANSPARENT
    // Transform outer dimensions including border.
    outer_w := w_ + 2 * border_width_
    outer_h := h_ + 2 * border_width_
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
  painting_map canvas/Canvas:
    canvas.transform.xywh 0 0 w_ h_: | x2 y2 w2 h2 |
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
      --w=w_
      --h=h_
      --color=0xffffff
    return transparency_map

  draw_frame canvas/Canvas:
    if border_width_ != 0: canvas.set_all_pixels border_color_

  draw_background canvas/Canvas:
    if background_color_: canvas.set_all_pixels background_color_

  type -> string: return "simple-window"

class RoundedCornerOpacity_:
  byte_opacity/ByteArray
  bit_opacity/ByteArray
  radius/int
  bitmap_width/int
  static cache_ := Map.weak

  static get corner_radius/int -> RoundedCornerOpacity_:
    cached := cache_.get corner_radius
    if cached: return cached
    new := RoundedCornerOpacity_.private_ corner_radius
    cache_[corner_radius] = new
    return new

  static TABLE_SIZE_ ::= 256
  // The heights of a top-right quarter circle of radius [TABLE_SIZE_].
  static QUARTER_CIRCLE_ ::= create_quarter_circle_array_ TABLE_SIZE_

  static create_quarter_circle_array_ size:
    array := ByteArray size
    hypotenuse := (size - 1) * (size - 1)
    size.repeat:
      array[it] = (hypotenuse - it * it).sqrt.to_int
    return array

  constructor.private_ .radius:
    byte_opacity = ByteArray radius * radius
    downsample := TABLE_SIZE_ / radius  // For example 81 for a radius of 3.
    steps := List radius:
      (it * TABLE_SIZE_) / radius
    radius.repeat: | j |
      b := steps[j]
      radius.repeat: | i |
        a := steps[i]
        idx := j * radius + i
        // Set the opacity according to whether the downsample x downsample
        // square is fully outside the circle, fully inside the circle or on
        // the edge.
        if QUARTER_CIRCLE_[b + downsample - 1] >= a + downsample:
          byte_opacity[idx] = 0xff  // Inside quarter circle.
        else if QUARTER_CIRCLE_[b] < a:
          byte_opacity[idx] = 0  // Outside quarter circle.
        else:
          // Edge of quarter circle.
          total := 0
          downsample.repeat: | small_y |
            extent := QUARTER_CIRCLE_[b + small_y]
            if extent >= a + downsample:
              total += downsample
            else if extent > a:
              total += extent - a
          byte_opacity[idx] = (0xff * total) / (downsample * downsample)
    // Generate a bit version of the opacities in case we have to use it on a
    // 2-color or 3-color display.
    bitmap_width = round_up radius 8
    bit_opacity = ByteArray (byte_opacity.size / radius) * (bitmap_width >> 3)
    destination_line_stride := bitmap_width >> 3
    8.repeat: | bit |
      blit byte_opacity[bit..] bit_opacity ((radius + 7 - bit) >> 3)
          --source_pixel_stride=8
          --source_line_stride=radius
          --destination_line_stride=destination_line_stride
          --shift=bit
          --mask=(0x80 >> bit)
          --operation=OR

/** A rectangular window with rounded corners. */
class RoundedCornerWindowElement extends WindowElement:
  corner_radius_/int := ?
  background_color_/int? := ?
  opacities_/RoundedCornerOpacity_? := null
  shadow_palette_/ByteArray := #[]

  constructor --x/int?=null --y/int?=null --w/int?=null --h/int?=null --corner_radius/int=5 --background_color/int=0:
    if not 0 <= corner_radius <= RoundedCornerOpacity_.TABLE_SIZE_: throw "OUT_OF_RANGE"
    corner_radius_ = corner_radius
    background_color_ = background_color
    super --x=x --y=y --w=w --h=h

  corner_radius -> int: return corner_radius_

  corner_radius= new_radius/int -> none:
    if not 0 <= new_radius <= RoundedCornerOpacity_.TABLE_SIZE_: throw "OUT_OF_RANGE"
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
    if x and y and w and h:
      block.call x y w h   // Does not protrude beyond the inner bounds.

  ensure_opacities_:
    if opacities_: return
    opacities_ = RoundedCornerOpacity_.get corner_radius_

  frame_map canvas/Canvas:
    return WindowElement.ALL_TRANSPARENT  // No frame on these windows.

  // Draws 100% opacity for the window content, a filled rounded-corner rectangle.
  painting_map canvas/Canvas:
    canvas.transform.xywh 0 0 w_ h_: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if x2 >= canvas.width_ or y2 >= canvas.height_ or right <= 0 or bottom <= 0:
        return WindowElement.ALL_TRANSPARENT  // The content is 100% transparent outside the window.
      if x2                  <= 0 and y2 + corner_radius_ <= 0 and right                  >= canvas.width_ and bottom - corner_radius_ >= canvas.height_ or
         x2 + corner_radius_ <= 0 and y2                  <= 0 and right - corner_radius_ >= canvas.width_ and bottom                  >= canvas.height_:
        return WindowElement.ALL_OPAQUE  // The content is 100% opaque in the cross in the middle where there are no corners.
    // We need to create a bitmap to describe the content's extent.
    transparency_map := canvas.make_alpha_map
    draw_rounded_corners_ transparency_map 0 0 w_ h_ 0xff
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
    if transparency_map is one_byte.Canvas_:
      palette := opacity == 0xff ? #[] : shadow_palette_
      draw_corners_ x2 y2 right bottom corner_radius_: | x y orientation |
        transparency_map.pixmap x y --pixels=opacities_.byte_opacity --palette=palette --source_width=corner_radius_ --orientation=orientation
    else:
      draw_corners_ x2 y2 right bottom corner_radius_: | x y orientation |
        transparency_map.draw_bitmap x y --pixels=opacities_.bit_opacity --color=1 --source_width=corner_radius_ --orientation=orientation

  draw_corners_ left/int top/int right/int bottom/int corner_radius/int [block]:
    // Top left corner:
    block.call (left + corner_radius) (top + corner_radius) ORIENTATION_180
    // Top right corner:
    block.call right (top + corner_radius) ORIENTATION_90
    // Bottom left corner:
    block.call (left + corner_radius) bottom ORIENTATION_270
    // Bottom right corner:
    block.call right bottom ORIENTATION_0

  draw_frame canvas/Canvas:
    unreachable  // There's no frame.

  draw_background canvas/Canvas:
    if background_color_: canvas.set_all_pixels background_color_

  type -> string: return "rounded-corner-window"

class DropShadowWindowElement extends RoundedCornerWindowElement:
  blur_radius_/int := ?
  drop_distance_x_/int := ?
  drop_distance_y_/int := ?
  shadow_opacity_percent_/int := ?

  constructor --x/int?=null --y/int?=null --w/int?=null --h/int?=null --corner_radius/int=5 --blur_radius/int=5 --drop_distance_x/int=10 --drop_distance_y/int=10 --shadow_opacity_percent/int=25:
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
    if x and y and w and h:
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

  frame_map canvas/Canvas:
    // Transform inner dimensions excluding shadow to determine if the canvas
    // is wholly inside the window.
    canvas.transform.xywh 0 0 w_ h_: | x2 y2 w2 h2 |
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
      canvas.transform.xywh -left -top (w_ + left + right) (h_ + top + bottom): | x2 y2 w2 h2 |
        if x2 + w2 <= 0 or y2 + h2 <= 0 or x2 >= canvas.width_ or y2 >= canvas.height_:
          return WindowElement.ALL_TRANSPARENT  // The frame is not opaque outside the shadow

    // Create a bitmap to describe the frame's extent.  It needs to be padded
    // relative to the canvas size so we can use the Gaussian blur.
    transparency_map := canvas.make_alpha_map --padding=(blur_radius * 2)
    transparency_map.transform = (canvas.transform.invert.translate -blur_radius -blur_radius).invert

    max_shadow_opacity := (shadow_opacity_percent * 2.5500001).to_int
    draw_rounded_corners_ transparency_map drop_distance_x_ drop_distance_y_ w_ h_ max_shadow_opacity

    if blur_radius == 0 or transparency_map is not one_byte.Canvas_:
      return transparency_map

    one_byte_map := transparency_map as one_byte.Canvas_

    // Blur the shadow.
    bytemap_blur one_byte_map.pixels_ transparency_map.width_ blur_radius

    // Crop off the extra that was added to blur.
    transparency_map_unpadded := canvas.make_alpha_map
    blit
        one_byte_map.pixels_[blur_radius + blur_radius * one_byte_map.width_..]   // Source.
        (transparency_map_unpadded as one_byte.Canvas_).pixels_  // Destination.
        transparency_map_unpadded.width_   // Bytes per line.
        --source_line_stride=transparency_map.width_
    return transparency_map_unpadded

  draw_frame canvas/Canvas:
    canvas.set_all_pixels 0

  type -> string: return "drop-shadow-window"

// Element that draws a PNG image.
class PngElement extends CustomElement:
  w/int
  h/int
  png_/AbstractPng

  min_w: return w
  min_h: return h

  constructor --x/int?=null --y/int?=null png_file/ByteArray:
    info := PngInfo png_file
    if info.uncompressed_random_access:
      png_ = PngRandomAccess png_file
    else:
      png_ = Png png_file
    if png_.bit_depth > 8: throw "UNSUPPORTED"
    if png_.color_type == COLOR_TYPE_TRUECOLOR or png_.color_type == COLOR_TYPE_TRUECOLOR_ALPHA: throw "UNSUPPORTED"
    w = png_.width
    h = png_.height
    super --x=x --y=y

  // Redraw routine.
  draw canvas/Canvas:
    if not (x and y): return
    y2 := 0
    while y2 < h and (canvas.bounds_analysis x (y + y2) w (h - y2)) != Canvas.ALL_OUTSIDE:
      png_.get_indexed_image_data y2 h
          --accept_8_bit=canvas.supports_8_bit
          --need_gray_palette=canvas.gray_scale: | y_from/int y_to/int bits_per_pixel/int pixels/ByteArray line_stride/int palette/ByteArray alpha_palette/ByteArray |
        if bits_per_pixel == 1:
          // Last line a little shorter because it has no stride padding.
          adjust := line_stride - ((round_up w 8) >> 3)
          pixels = pixels[0 .. (y_to - y_from) * line_stride - adjust]
          canvas.bitmap x (y + y_from)
              --pixels=pixels
              --alpha=alpha_palette
              --palette=palette
              --source_width=w
              --source_line_stride=line_stride
        else:
          adjust := line_stride - w
          pixels = pixels[0 .. (y_to - y_from) * line_stride - adjust]
          canvas.pixmap x (y + y_from) --pixels=pixels
              --alpha=alpha_palette
              --palette=palette
              --source_width=w
              --source_line_stride=line_stride
        y2 = y_to

  type -> string: return "png"

  set_attribute key/string value -> none:
