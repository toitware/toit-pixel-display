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
import font show Font
import math

/**
Something that can be placed on a display.  They can contain other
  elements, and draw themselves on Canvases.
They can be stacked up and will be drawn from back to front, with transparency.
*/
abstract class Element implements Window:
  hash_code/int ::= generate_hash_code_
  change_tracker/Window? := null
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
    if children: children.do: | child/Element |
      child.change_tracker = this

  static HASH_CODE_COUNTER_ := 0
  static generate_hash_code_ -> int:
    HASH_CODE_COUNTER_ += 13
    return HASH_CODE_COUNTER_

  abstract invalidate -> none

  get_element_by_id id/string -> Element?:
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

  abstract draw canvas/Canvas -> none

  child_invalidated x/int y/int w/int h/int -> none:
    if change_tracker:
      x2 := max x_ (x_ + x)
      y2 := max y_ (y_ + y)
      right := min (x_ + this.w) (x_ + x + w)
      bottom := min (y_ + this.h) (y_ + y + h)
      if x2 < right and y2 < bottom:
        change_tracker.child_invalidated x2 y2 (right - x2) (bottom - y2)

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
        invalidate
    else if key == "border":
      if border_ != value:
        invalidate
        border_ = value
        invalidate

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
      change_tracker.child_invalidated x y w h

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

  set_attribute key/string value -> none:
    if key == "width":
      w = value
    else if key == "height":
      h = value
    else:
      super key value

  draw canvas/Canvas -> none:
    old_transform := canvas.transform
    canvas.transform = old_transform.translate x_ y_
    Background.draw background_ canvas 0 0 w h --no-autocropped
    custom_draw canvas
    if border_: border_.draw canvas 0 0 w h
    canvas.transform = old_transform

  custom_draw canvas/Canvas -> none:
    if children: children.do: it.draw canvas

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
      left_ = null  // Trigger recalculation.
      invalidate

  constructor --x/int?=null --y/int?=null --color/int=0 --label/string="" --font/Font?=null --orientation/int=ORIENTATION_0 --alignment/int=ALIGN_LEFT:
    color_ = color
    label_ = label
    alignment_ = alignment
    orientation_ = orientation
    font_ = font
    super --x=x --y=y

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
    if change_tracker and x and y and font_ and label_:
      xywh_: | x y w h |
        change_tracker.child_invalidated x y w h

  label= value/string -> none:
    if value == label_: return
    if orientation_ == ORIENTATION_0 and change_tracker and x and y:
      text_get_bounding_boxes_ label_ value alignment_ font_: | old/TextExtent_ new/TextExtent_ |
        change_tracker.child_invalidated (x_ + old.x) (y_ + old.y) old.w old.h
        change_tracker.child_invalidated (x_ + new.x) (y_ + new.y) new.w new.h
        label_ = value
        left_ = null  // Trigger recalculation.
        return
    invalidate
    label_ = value
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
  $custom_draw method in your subclass to draw on the canvas.  The $w
  and $h methods/fields are used to determine the size of the element
  for redrawing purposes.
The background is drawn before $custom_draw is called, and the border
  is drawn after.
Drawing operations are automatically clipped to w and h.
*/
abstract class CustomElement extends ClippingDiv:
  abstract w -> int?
  abstract h -> int?

  constructor --x/int?=null --y/int?=null --w/int?=null --h/int?=null:
    super --x=x --y=y --w=w --h=h

  invalidate:
    if change_tracker and x and y and w and h:
      change_tracker.child_invalidated x y w h

  draw canvas/Canvas -> none:
    if not (x and y): return
    analysis := canvas.bounds_analysis x y w h
    if analysis == Canvas.DISJOINT: return
    autocropped := analysis == Canvas.CANVAS_IN_AREA or analysis == Canvas.COINCIDENT
    old_transform := canvas.transform
    canvas.transform = old_transform.translate x_ y_
    Background.draw background_ canvas 0 0 w h --autocropped=autocropped
    custom_draw canvas
    if border_: border_.draw canvas 0 0 w h
    canvas.transform = old_transform

  /**
  Override this to draw your custom element.  The coordinate system is
    the coordinate system of your element.  That is, the top left is 0, 0.
  The background has already been drawn when this is called, and the
    frame will be drawn afterwards.
  */
  abstract custom_draw canvas/Canvas -> none

/**
A ClippingDiv is like a div, but it clips any draws inside of it.  It can
  have a shadow or other drawing outside its raw x y w h area, called the
  decoration.
For style purposes it has the type "div", not "clipping-div".
Because it has clipping and compositing, it can have more interesting borders
  like rounded corners.
*/
class ClippingDiv extends Div:
  /**
  Calls the block with x, y, w, h, which includes the decoration.
  */
  extent --x=x_ --y=y_ --w=w_ --h=h_ [block] -> none:
    if border_:
      border_.invalidation_area x y w h block
    else:
      block.call x y w h

  /**
  Invalidates the whole window including the decoration.
  */
  invalidate --x=x_ --y=y_ --w=w_ --h=h_ -> none:
    if change_tracker:
      extent --x=x --y=y --w=w --h=h: | outer_x outer_y outer_w outer_h |
        change_tracker.child_invalidated outer_x outer_y outer_w outer_h

  static ALL_TRANSPARENT ::= #[0]
  static ALL_OPAQUE ::= #[0xff]

  static is_all_transparent opacity -> bool:
    if opacity is not ByteArray: return false
    return opacity.size == 1 and opacity[0] == 0

  static is_all_opaque opacity -> bool:
    if opacity is not ByteArray: return false
    return opacity.size == 1 and opacity[0] == 0xff

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
    super --x=x --y=y --w=w --h=h --style=style --element_class=element_class --classes=classes --id=id --background=background --border=border children

  // After the textures under us have drawn themselves, we draw on top.
  draw canvas/Canvas -> none:
    // If we are outside the window and the decorations, there is nothing to do.
    extent: | x2 y2 w2 h2 |
      if (canvas.bounds_analysis x2 y2 w2 h2) == Canvas.DISJOINT: return

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
    Background.draw background_ painting_canvas 0 0 w h --autocropped
    custom_draw painting_canvas

    canvas.composit frame_opacity border_canvas content_opacity painting_canvas

    canvas.transform = old_transform

  type -> string: return "div"

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
  frame_map canvas/Canvas:
    if not border_: return ClippingDiv.ALL_TRANSPARENT  // No border visible.
    return border_.frame_map canvas w h

  /**
  Returns a canvas that is an alpha map for the given area that describes where
    the window content (background of the window and children) are visible.
  For 2-color and 3-color textures this is a bitmap with 0 for transparent and
    1 for opaque.  For true-color and gray-scale textures it is a bytemap with
    0 for transparent and 0xff for opaque.  As a special case it may return a
    single-entry byte array, which means all pixels have the same transparency.
  The coordinate system of the canvas is the coordinate system of the window.
  */
  content_map canvas/Canvas:
    return (border_ or NO_BORDER_).content_map canvas w h

  draw_frame canvas/Canvas:
    if border_: border_.draw canvas 0 0 w h
