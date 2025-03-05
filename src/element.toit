// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import binary show LITTLE-ENDIAN
import bitmap show *
import .style show *
import .pixel-display
import font show Font
import icons show Icon
import math

/**
An element that can be placed on a display.  They can contain other
  elements, and draw themselves on Canvases.
Elements can be stacked up and are drawn from back to front, with transparency.
*/
abstract class Element implements Window:
  hash-code/int ::= generate-hash-code_
  change-tracker/Window? := null
  style_/Style? := ?
  classes/List? := ?
  id/string? := ?
  children/List? := ?
  children-styles_/List? := null
  background_ := null
  border_/Border? := null

  x_ /int? := null
  y_ /int? := null

  x -> int?: return x_
  y -> int?: return y_

  /**
  Constructs an Element.
  The x and y coordinates are relative to the parent element.
  The $style can be used to apply a custom Style object to this element
    alone.  Normally, you would apply a style to the whole tree of elements
    using $PixelDisplay.set-styles method.
  The $classes are strings that can be used to identify the element
    in the style sheet.  You can give an element multiple classes.
  The $id is a string that can be used to identify the element in the style
    sheet.  It should be unique in the whole tree of elements.  It is also used
    for $PixelDisplay.get-element-by-id.
  The $background is an integer color (0xRRGGBB) or a $Background object.
    It can be set using styles instead of here in the constructor.
  The children are a $List of elements that should be contained in this element.
  */
  constructor
      --x/int?=null
      --y/int?=null
      --style/Style?=null
      --.classes/List?=null
      --.id/string?=null
      --background=null
      --border/Border?=null
      .children/List?=null:
    x_ = x
    y_ = y
    style_ = style
    background_ = background
    border_ = border
    if children: children.do: | child/Element |
      child.change-tracker = this

    if style: set-styles [style]

  static HASH-CODE-COUNTER_ := 0
  static generate-hash-code_ -> int:
    HASH-CODE-COUNTER_ += 13
    return HASH-CODE-COUNTER_

  abstract invalidate -> none

  is-mounted -> bool:
    return change-tracker != null and change-tracker.is-mounted

  /**
  Finds an Element in the tree with the given id.
  Returns null if no element is found.
  The return type is any because you want to be able to assign the result
    to a variable of type Div, which is a subtype of Element.
  */
  get-element-by-id id/string -> any:
    if id == this.id: return this
    if children:
      children.do: | child/Element |
        found := child.get-element-by-id id
        if found: return found
    return null

  add element/Element -> none:
    if not children: children = []
    children.add element
    if children-styles_: element.set-styles children-styles_
    element.change-tracker = this
    element.invalidate

  remove element/Element -> none:
    if children:
      children.remove element
      element.invalidate
      element.change-tracker = null

  remove-all -> none:
    children.do:
      it.invalidate
      it.change-tracker = null
    children = null

  x= value/int -> none:
    if x_ != value:
      invalidate
      x_ = value
      invalidate

  y= value/int -> none:
    if y_ != value:
      invalidate
      y_ = value
      invalidate

  move-to x/int y/int:
    if x_ != x or y_ != y:
      invalidate
      x_ = x
      y_ = y
      invalidate

  border= value/Border?:
    if value != border_:
      invalidate
      border_ = value
      invalidate

  background -> any:
    return background_

  background= value:
    if value != background_:
      invalidate
      background_ = value
      invalidate

  abstract draw canvas/Canvas -> none

  child-invalidated x/int y/int w/int h/int -> none:
    if change-tracker:
      x2 := max x_ (x_ + x)
      y2 := max y_ (y_ + y)
      right := min (x_ + this.w) (x_ + x + w)
      bottom := min (y_ + this.h) (y_ + y + h)
      if x2 < right and y2 < bottom:
        change-tracker.child-invalidated x2 y2 (right - x2) (bottom - y2)

  abstract w -> int?
  abstract h -> int?

  set-styles styles/List -> none:
    styles-for-children := null
    install-style := : | style/Style |
      style.matching-styles --type=type --classes=classes --id=id: | style/Style |
        style.iterate-properties: | key/string value |
          set-attribute_ key value
        if not styles-for-children: styles-for-children = styles.copy
        styles-for-children.add style
    styles.do install-style
    if style_:
      style_.iterate-properties: | key/string value |
        set-attribute_ key value
      install-style.call style_
    children-styles_ = styles-for-children or styles
    if children:
      children.do: | child/Element |
        child.set-styles (styles-for-children or styles)

  set-attribute_ key/string value -> none:
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
    else if key == "x":
      x = value
    else if key == "y":
      y = value
    else:
      print "Unknown style key: '$key'"

  abstract type -> string

interface ColoredElement:
  color -> int?
  color= value/int -> none

/**
A rectangular element that can be placed on a display.
It can contain other elements, and draws itself on Canvases.
*/
class Div extends Element:
  w_ /int? := null
  h_ /int? := null

  type -> string: return "div"

  /**
  Constructs a Div.
  A Div is an element that does not layout its children.  They should all
    have explicit x and y positions, that will be relative to this Div.
  A Div constructed with this constructor does not automatically clip its
    children, so they can accidentally extend beyond the bounds of the Div.
    This is a efficiency win, but if you want clipping, use the $Div.clipping
    constructor.
  The $background or $border is only drawn if the div has a width and height.
    To provide these values, pass $w and $h parameters, call the corresponding
    setters, or apply a style.
  Because it has no clipping and compositing, it is restricted to simple
    borders without rounded corners and shadows.
  See $Element.constructor for a description of the other parameters.
  */
  constructor
      --x/int?=null
      --y/int?=null
      --w/int?=null
      --h/int?=null
      --style/Style?=null
      --classes/List?=null
      --id/string?=null
      --background=null
      --border/Border?=null
      children/List?=null:
    w_ = w
    h_ = h
    super
        --x = x
        --y = y
        --style = style
        --classes = classes
        --id = id
        --background = background
        --border = border
        children

  /**
  Variant of $Div.constructor.
  Constructs a Div that clips any draws inside of it.  It can
    have a shadow or other drawing outside its raw x y w h area, depending
    on its border style.
  Because it has clipping and compositing, it can have more interesting borders
    like rounded corners.
  */
  constructor.clipping
      --x/int?=null
      --y/int?=null
      --w/int?=null
      --h/int?=null
      --style/Style?=null
      --classes/List?=null
      --id/string?=null
      --background=null
      --border/Border?=null
      children/List?=null:
    return ClippingDiv_
        --x = x
        --y = y
        --w = w
        --h = h
        --style = style
        --classes = classes
        --id = id
        --background = background
        --border = border
        children

  invalidate:
    if change-tracker and w_ and h_:
      change-tracker.child-invalidated (x_ or 0) (y_ or 0) w_ h_

  child-invalidated x/int y/int w/int h/int --clip/bool=false -> none:
    if clip:
      super x y w h
    else if change-tracker:
      x2 := (x_ or 0) + x
      y2 := (y_ or 0) + y
      change-tracker.child-invalidated x2 y2 w h

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

  set-size w/int h/int -> none:
    if w_ != w or h_ != h:
      if w_ and h_: invalidate
      w_ = w
      h_ = h
      invalidate

  set-attribute_ key/string value -> none:
    if key == "w":
      w = value
    else if key == "h":
      h = value
    else:
      super key value

  draw canvas/Canvas -> none:
    old-transform := canvas.transform
    if x_ or y_:
      canvas.transform = old-transform.translate (x_ or 0) (y_ or 0)
    if background_ and w_ and h_:
      Background.draw background_ canvas 0 0 w_ h_ --no-autoclipped
    custom-draw canvas
    if border_ and w_ and h_: border_.draw canvas 0 0 w_ h_
    canvas.transform = old-transform

  custom-draw canvas/Canvas -> none:
    if children: children.do: it.draw canvas

/**
An element that is a single line of text.
Like other elements it can have a background, but it is not intended to have
  children contained in it.
*/
class Label extends Element implements ColoredElement:
  color_/int := ?
  text_/string := ?
  alignment_/int := ?
  orientation_/int := ?
  font_/Font? := ?
  left_/int? := null
  top_/int? := null
  width_/int? := null
  height_/int? := null

  type -> string: return "label"

  set-attribute_ key/string value -> none:
    if key == "color":
      color = value
    else if key == "font":
      font = value
    else if key == "orientation":
      orientation = value
    else if key == "alignment":
      alignment = value
    else if key == "text" or key == "label":
      text = value
    else if key == "icon":
      icon = value
    else:
      super key value

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

  icon= value/Icon -> none:
    font = value.font_
    text = value.stringify

  /**
  Constructs a Label.
  An Label is an element that is a single line of text.
  Unlike other elements it does not have a background and a border - the
    background is always transparent and the border is always invisible.
  The $alignment is one of $ALIGN-LEFT, $ALIGN-CENTER, or $ALIGN-RIGHT.
  The $orientation is one of $ORIENTATION-0, $ORIENTATION-90, $ORIENTATION-180,
    or $ORIENTATION-270.
  The $label argument is equivalent to the $text argument.  The $text
    argument is preferred.
  The $color, $font, $orientation, and $alignment can be set using styles
    instead of here in the constructor.  The $text can be set and
    changed later with the text setter.  Like any change of appearance
    in an element, it doesn't become visible until the $PixelDisplay.draw
    method is called.
  See $Element.constructor for the other arguments.
  */
  constructor
      --x/int?=null
      --y/int?=null
      --style/Style?=null
      --classes/List?=null
      --id/string?=null
      --color/int=0
      --label/string?=null
      --text/string?=null
      --font/Font?=null
      --icon/Icon?=null
      --orientation/int=ORIENTATION-0
      --alignment/int=ALIGN-LEFT:
    color_ = color
    if label and text: throw "INVALID_ARGUMENT"
    text_ = text or label or ""
    alignment_ = alignment
    orientation_ = orientation
    font_ = font
    super
        --x = x
        --y = y
        --style = style
        --classes = classes
        --id = id
    if icon:
      if font: throw "INVALID_ARGUMENT"
      this.icon = icon

  /**
  Calls the block with the left, top, width, and height.
  */
  xywh_ [block]:
    if not left_:
      extent/List := font_.text-extent text_
      displacement := 0
      if alignment_ != ALIGN-LEFT:
        displacement = (font_.pixel-width text_)
        if alignment_ == ALIGN-CENTER: displacement >>= 1
      l := extent[2] - displacement
      r := extent[2] - displacement + extent[0]
      t := -extent[1] - extent[3]
      b := extent[3]
      if orientation_ == ORIENTATION-0:
        left_   = l
        top_    = t
        width_  = extent[0]
        height_ = extent[1]
      else if orientation_ == ORIENTATION-90:
        left_   = t
        top_    = -r
        width_  = extent[1]
        height_ = extent[0]
      else if orientation_ == ORIENTATION-180:
        left_   = -r
        top_    = b
        width_  = extent[0]
        height_ = extent[1]
      else:
        assert: orientation_ == ORIENTATION-270
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
    if change-tracker and x and y and font_ and text_:
      xywh_: | x y w h |
        change-tracker.child-invalidated x y w h

  label= value/string -> none:
    text = value

  text= value/string -> none:
    if value == text_: return
    if not is-mounted:
      text_ = value
      left_ = null  // Trigger recalculation.
      return
    if orientation_ == ORIENTATION-0 and change-tracker and x and y and font_ and text_:
      text-get-bounding-boxes_ text_ value alignment_ font_: | old/TextExtent_ new/TextExtent_ |
        change-tracker.child-invalidated (x_ + old.x) (y_ + old.y) old.w old.h
        change-tracker.child-invalidated (x_ + new.x) (y_ + new.y) new.w new.h
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

  draw canvas /Canvas -> none:
    x := x_
    y := y_
    if not (x and y): return
    if alignment_ != ALIGN-LEFT:
      text-width := font_.pixel-width text_
      if alignment_ == ALIGN-CENTER: text-width >>= 1
      if orientation_ == ORIENTATION-0:
        x -= text-width
      else if orientation_ == ORIENTATION-90:
        y += text-width
      else if orientation_ == ORIENTATION-180:
        x += text-width
      else:
        assert: orientation_ == ORIENTATION-270
        y -= text-width
    canvas.text x y --text=text_ --color=color_ --font=font_ --orientation=orientation_

/**
A superclass for elements that can draw themselves.  Override the
  $custom-draw method in your subclass to draw on the canvas.  The $w
  and $h methods/fields are used to determine the size of the element
  for redrawing purposes.
The background is drawn before $custom-draw is called, and the border
  is drawn after.
Drawing operations are automatically clipped to w and h.
*/
abstract class CustomElement extends ClippingDiv_:
  abstract w -> int?
  abstract h -> int?

  constructor
      --x/int?=null
      --y/int?=null
      --w/int?=null
      --h/int?=null
      --style/Style?=null
      --classes/List?=null
      --id/string?=null
      --background=null
      --border/Border?=null:
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

  invalidate:
    if change-tracker and x and y and w and h:
      change-tracker.child-invalidated x y w h

  draw canvas/Canvas -> none:
    if not (x and y and w and h): return
    analysis := canvas.bounds-analysis x y w h
    if analysis == Canvas.DISJOINT: return
    autoclipped := analysis == Canvas.CANVAS-IN-AREA or analysis == Canvas.COINCIDENT
    old-transform := canvas.transform
    canvas.transform = old-transform.translate x_ y_
    Background.draw background_ canvas 0 0 w h --autoclipped=autoclipped
    custom-draw canvas
    if border_: border_.draw canvas 0 0 w h
    canvas.transform = old-transform

  /**
  Override this to draw your custom element.  The coordinate system is
    the coordinate system of your element.  That is, the top left is 0, 0.
  The background has already been drawn when this is called, and the
    frame will be drawn afterwards.
  */
  abstract custom-draw canvas/Canvas -> none

/**
A ClippingDiv_ is like a div, but it clips any draws inside of it.  It can
  have a shadow or other drawing outside its raw x y w h area, called the
  decoration.
For style purposes it has the type "div", not "clipping-div".
Because it has clipping and compositing, it can have more interesting borders
  like rounded corners.
*/
class ClippingDiv_ extends Div:
  /**
  Calls the block with x, y, w, h, which includes the decoration.
  */
  extent --x=x_ --y=y_ --w=w_ --h=h_ [block] -> none:
    if border_:
      border_.invalidation-area x y w h block
    else:
      block.call x y w h

  /**
  Invalidates the whole window including the decoration.
  */
  invalidate --x=x_ --y=y_ --w=w_ --h=h_ -> none:
    if change-tracker and x and y and w and h:
      extent --x=x --y=y --w=w --h=h: | outer-x outer-y outer-w outer-h |
        change-tracker.child-invalidated outer-x outer-y outer-w outer-h

  child-invalidated x/int y/int w/int h/int -> none:
    super x y w h --clip

  static is-all-transparent opacity -> bool:
    if opacity is not ByteArray: return false
    return opacity.size == 1 and opacity[0] == 0

  static is-all-opaque opacity -> bool:
    if opacity is not ByteArray: return false
    return opacity.size == 1 and opacity[0] == 0xff

  constructor
      --x/int?=null
      --y/int?=null
      --w/int?=null
      --h/int?=null
      --style/Style?=null
      --classes/List?=null
      --id/string?=null
      --background=null
      --border/Border?=null
      children/List?=null:
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
        children

  // After the textures under us have drawn themselves, we draw on top.
  draw canvas/Canvas -> none:
    // If we are outside the window and the decorations, there is nothing to do.
    extent: | x2 y2 w2 h2 |
      if (canvas.bounds-analysis x2 y2 w2 h2) == Canvas.DISJOINT: return

    old-transform := canvas.transform
    canvas.transform = old-transform.translate x_ y_

    content-opacity := content-map canvas

    // If the window is 100% painting at these coordinates then we can draw the
    // elements of the window and no compositing is required.
    if is-all-opaque content-opacity:
      canvas.transform = old-transform
      super canvas  // Use the unclipped drawing method from Div.
      return

    frame-opacity := frame-map canvas

    if is-all-transparent frame-opacity and is-all-transparent content-opacity:
      canvas.transform = old-transform
      return

    // The complicated case where we have to composit the tile with the border and decorations.
    border-canvas := null
    if not is-all-transparent frame-opacity:
      border-canvas = canvas.create-similar
      if border_: border_.draw border-canvas 0 0 w h

    painting-canvas := canvas.create-similar
    Background.draw background_ painting-canvas 0 0 w h --autoclipped
    custom-draw painting-canvas

    canvas.composit frame-opacity border-canvas content-opacity painting-canvas

    canvas.transform = old-transform

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
  frame-map canvas/Canvas:
    if not border_: return Canvas.ALL-TRANSPARENT  // No border visible.
    return border_.frame-map canvas w h

  /**
  Returns a canvas that is an alpha map for the given area that describes where
    the window content (background of the window and children) are visible.
  For 2-color and 3-color textures this is a bitmap with 0 for transparent and
    1 for opaque.  For true-color and gray-scale textures it is a bytemap with
    0 for transparent and 0xff for opaque.  As a special case it may return a
    single-entry byte array, which means all pixels have the same transparency.
  The coordinate system of the canvas is the coordinate system of the window.
  */
  content-map canvas/Canvas:
    return (border_ or NO-BORDER_).content-map canvas w h

  draw-frame canvas/Canvas:
    if border_: border_.draw canvas 0 0 w h
