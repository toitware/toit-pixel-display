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
import .style show RoundedCornerOpacity_
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
    if children:
      old_transform := canvas.transform
      canvas.transform = old_transform.translate x_ y_
      Background.draw background_ canvas 0 0 w h
      if children: children.do: it.draw canvas
      if border_: border_.draw canvas 0 0 w h
      canvas.transform = old_transform
    else:
      // In the simple case, don't mess about with transforms.
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

/**
A WindowElement is like a div, but it clips any draws inside of it.  It can
  have a shadow or other drawing outside its raw x y w h area, called the
  decoration.
Because it has clipping and compositing, it can have more interesting bounds
  like rounded corners.
*/
abstract class WindowElement extends Div implements Window:
  /**
  Calls the block with x, y, w, h, which includes the decoration.
  */
  extent [block] -> none:
    if border_:
      border_.invalidation_area x_ y_ w_ h_ block
    else:
      block.call x_ y_ w_ h_

  /**
  Invalidates the whole window including the decoration.
  */
  invalidate:
    if change_tracker:
      extent: | outer_x outer_y outer_w outer_h |
        change_tracker.child_invalidated_element outer_x outer_y outer_w outer_h

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
    the things behind around this window shines through.  This is mainly used for
    rounded corners, but also for other decorations.
  For 2-color and 3-color textures this is a bitmap with 0 for transparent and
    1 for opaque.  For true-color and gray-scale textures it is a bytemap with
    0 for transparent and 0xff for opaque.  As a special case it may return a
    single-entry byte array, which means all pixels have the same transparency.
  The coordinate system of the canvas is the coordinate system of the window, so
    the top and left edges may be plotted at negative coordinates.
  */
  abstract frame_map canvas/Canvas -> ByteArray

  /**
  Returns a canvas that is an alpha map for the given area that describes where
    the window content (background of the window and children) are visible.
  For 2-color and 3-color textures this is a bitmap with 0 for transparent and
    1 for opaque.  For true-color and gray-scale textures it is a bytemap with
    0 for transparent and 0xff for opaque.  As a special case it may return a
    single-entry byte array, which means all pixels have the same transparency.
  The coordinate system of the canvas is the coordinate system of the window.
  */
  abstract content_map canvas/Canvas -> ByteArray

  constructor --x/int?=null --y/int?=null --w/int?=null --h/int?=null --background=null --border/Border?=null:
    super --x=x --y=y --w=w --h=h --background=background --border=border

  // After the textures under us have drawn themselves, we draw on top.
  draw canvas/Canvas -> none:
    // If we are outside the window and the decorations, there is nothing to do.
    extent: | x2 y2 w2 h2 |
      if (canvas.bounds_analysis x2 y2 w2 h2) == Canvas.ALL_OUTSIDE: return

    old_transform := canvas.transform
    canvas.transform = old_transform.translate x_ y_

    content_opacity := content_map canvas

    // If the window is 100% painting at these coordinates then we can draw the
    // elements of the window and no compositing is required.
    if is_all_opaque content_opacity:
      canvas.transform = old_transform
      super canvas  // Use the unclipped drawing method from Div.
      return

    frame_opacity := frame_map canvas

    if is_all_transparent frame_opacity and is_all_transparent content_opacity:
      canvas.transform = old_transform
      return

    // The complicated case where we have to composit the tile with the border and decorations.
    border_canvas := null
    if not is_all_transparent frame_opacity:
      border_canvas = canvas.create_similar
      if border_: border_.draw border_canvas 0 0 w h

    painting_canvas := canvas.create_similar
    Background.draw background_ painting_canvas 0 0 w h
    if children: children.do: it.draw painting_canvas

    canvas.composit frame_opacity border_canvas content_opacity painting_canvas

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
  constructor --x/int?=null --y/int?=null --w/int?=null --h/int?=null --background=null --border/Border?=null:
    super --x=x --y=y --w=w --h=h --background=background --border=border

  // Draws 100% opacity for the frame shape, a filled rectangle.
  // (The frame is behind the painting, so this doesn't mean we only
  // see the frame.)
  frame_map canvas/Canvas:
    if not border_: return WindowElement.ALL_TRANSPARENT  // No border visible.
    return border_.frame_map canvas w h

  // Draws 100% opacity for the window content, a filled rectangle.
  content_map canvas/Canvas:
    return (border_ or NO_BORDER_).content_map canvas w h

  draw_frame canvas/Canvas:
    if border_: border_.draw canvas 0 0 w h

  type -> string: return "simple-window"

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
