// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import bitmap
import bitmap show ORIENTATION_0 ORIENTATION_90 ORIENTATION_180 ORIENTATION_270
import font show Font

import .common
import .element as element
import .one_byte as one_byte

ALIGN_LEFT ::= 0
ALIGN_CENTER ::= 1
ALIGN_RIGHT ::= 2

EMPTY_STYLE_ ::= Style

/**
A background is anything that can draw itself on an element as a background.
There is support for just using ints (rgb colors) as backgrounds to save
  memory and flash.
*/
interface Background:
  draw canvas/Canvas x/int y/int w/int h/int --autocropped/bool -> none

  /**
  We also use colors (ints) as backgrounds, so this helper method will
    either just draw the plain color background, or call the draw method
    on a real Background object.
  */
  static draw background canvas/Canvas x/int y/int w/int h/int --autocropped/bool -> none:
    if background is int:
      if autocropped:
        canvas.set_all_pixels background
      else:
        canvas.rectangle x y --w=w --h=h --color=background
    else if background != null:
      (background as Background).draw canvas x y w h --autocropped=autocropped

  static check_valid background -> none:
    if background != null and background is not int and background is not Background:
      throw "INVALID_ARGUMENT"

class MultipleBackgrounds implements Background:
  list_/List

  constructor .list_:
    list_.do: if list_ is not Background: throw "INVALID_ARGUMENT"

  draw canvas/Canvas x/int y/int w/int h/int --autocropped/bool -> none:
    list_.do:
      Background.draw it canvas x y w h --autocropped=autocropped

interface Border:
  /// Draws the border within the given rectangle.
  draw canvas/Canvas x/int y/int w/int h/int -> none

  invalidation_area x/int y/int w/int h/int [block] -> none

  inner_dimensions w/int h/int [block] -> none

  offsets [block] -> none

  // Draws 100% opacity for the border and frame shape.  We don't need to carve
  // out the window content, there is assumed to be a different alpha map for
  // that.
  frame_map canvas/Canvas w/int h/int

  // Draws 100% opacity for the window content, a filled rectangle.
  content_map canvas/Canvas w/int h/int

class NoBorder implements Border:
  needs_clipping -> bool: return false

  draw canvas x y w h:
    // Nothing to draw.

  invalidation_area x/int y/int w/int h/int [block]:
    block.call x y w h

  inner_dimensions w h [block] -> none:
    block.call w h

  offsets [block] -> none:
    block.call 0 0

  frame_map canvas w h:
    return element.ClippingDiv.ALL_TRANSPARENT

  content_map canvas/Canvas w/int h/int:
    transparency_map := canvas.make_alpha_map
    transparency_map.rectangle 0 0 --w=w --h=h --color=0xff
    return transparency_map

NO_BORDER_/Border ::= NoBorder

/// A rectangular border inside the window's area, with a solid color.
class SolidBorder implements Border:
  border_width_/BorderWidth
  color_/int

  constructor --width/int --color/int:
    color_ = color
    border_width_ = BorderWidth width

  constructor --border_width/BorderWidth --color/int:
    color_ = color
    border_width_ = border_width

  needs_clipping -> bool: return false

  invalidation_area x/int y/int w/int h/int [block]:
    block.call x y w h

  inner_dimensions w/int h/int [block] -> none:
    border_width_.inner_dimensions w h block

  offsets [block] -> none:
    border_width_.offsets block

  draw canvas/Canvas x/int y/int w/int h/int -> none:
    if border_width_.left != 0:
      canvas.rectangle x y --w=border_width_.left --h=h --color=color_
    if border_width_.right != 0:
      canvas.rectangle (x + w - border_width_.right) y --w=border_width_.right --h=h --color=color_
    if border_width_.top != 0:
      canvas.rectangle x y --w=w --h=border_width_.top --color=color_
    if border_width_.bottom != 0:
      canvas.rectangle x (y + h - border_width_.bottom) --w=w --h=border_width_.bottom --color=color_

  // Draws 100% opacity for the border and frame shape.  We don't need to carve
  // out the window content, there is assumed to be a different alpha map for
  // that.
  frame_map canvas/Canvas w/int h/int:
    if border_width_ == 0: return element.ClippingDiv.ALL_TRANSPARENT  // The frame is not visible anywhere.
    // Transform inner dimensions not including border
    border_widths := border_width_.left + border_width_.right
    border_heights := border_width_.top + border_width_.bottom
    canvas.transform.xywh border_width_.left border_width_.top (w - border_widths) (h - border_heights): | x2 y2 w2 h2 |
      if x2 <= 0 and y2 <= 0 and x2 + w2 >= canvas.width_ and y2 + h2 >= canvas.height_:
        // In the middle, the window content is 100% opaque and draw on top of the
        // frame.  There is no need to provide a frame alpha map, so for efficiency we
        // just return 0 which indicates the frame is 100% transparent.
        return element.ClippingDiv.ALL_TRANSPARENT
    canvas.transform.xywh 0 0 w h: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if right <= 0 or bottom <= 0 or x2 >= canvas.width_ or y2 >= canvas.height_:
        // The frame is completely outside the window, so it is 100% transparent.
        return element.ClippingDiv.ALL_TRANSPARENT
    // We need to create a bitmap to describe the frame's extent.
    transparency_map := canvas.make_alpha_map
    // Declare the whole area inside the frame's extent opaque.  The window content will
    // draw on top of this as needed.
    transparency_map.rectangle 0 0
        --w = w
        --h = h
        --color = 0xff
    return transparency_map

  // Draws 100% opacity for the window content, a filled rectangle.
  content_map canvas/Canvas w/int h/int:
    border_widths := border_width_.left + border_width_.right
    border_heights := border_width_.top + border_width_.bottom
    canvas.transform.xywh border_width_.left border_width_.top (w - border_widths) (h - border_heights): | x2 y2 w2 h2 |
      if x2 <= 0 and y2 <= 0 and x2 + w2 >= canvas.width_ and y2 + h2 >= canvas.height_:
        return element.ClippingDiv.ALL_OPAQUE  // The content is 100% opaque in the middle.
      right := x2 + w2
      bottom := y2 + h2
      if right <= 0 or bottom <= 0 or x2 >= canvas.width_ or y2 >= canvas.height_:
        return element.ClippingDiv.ALL_TRANSPARENT  // The content is 100% transparent outside the window.
    // We need to create a bitmap to describe the content's extent.
    transparency_map := canvas.make_alpha_map
    // Declare the whole area inside the content's extent opaque.  The window content will
    // draw on top of this as needed.
    transparency_map.rectangle border_width_.left border_width_.top
        --w = w - border_widths
        --h = h - border_heights
        --color = 0xff
    return transparency_map

/// For use with $SolidBorder.
class BorderWidth:
  left/int
  top/int
  right/int
  bottom/int

  /// A border that has the same thickness on all sides.
  constructor width/int:
    left = top = right = bottom = width

  /// A constructor with a different thickness on the top and bottom vs. the sides.
  constructor --top_and_bottom/int --left_and_right/int:
    top = bottom = top_and_bottom
    left = right = left_and_right

  /// A constructor with arbitrary thickness on all sides and zero on all unmentioned sides.
  constructor --.top/int=0 --.right/int=0 --.bottom/int=0 --.left/int=0:

  inner_dimensions w/int h/int [block]:
    block.call (w - left - right) (h - top - bottom)

  offsets [block]:
    block.call left top

/**
A container (starting with a PixelDisplay) has a Style associated with it.

That style has general rules, but also rules that only apply to a particular id,
  style-class (called 'class' in CSS), or type.  Like in CSS, id is for one
  element, while style-class is for a group of elements.  Type is for instances
  of a particular Toit class.  All are represented as strings, but we do not
  use the CSS prefixes '#' and '.' for id and class, preferring to use the same
  syntax, but different maps.

Styles are generally immutable, so that we can use constructors with literal
  maps to build up the style.

```css
/* Styling for the button type. */
button {
  color: #ffffff;
  background: #606060;
}

/* Styling for the box class. */
.box {
  background: #ff0000;
}

/* Styling for the fish id. */
#fish {
  color: #00ff00;
}
```

In Toit this would be written as:
```toit
style := Style
    --type-map={
        "button": Style --color=0xffffff --background=0x606060,
    }
    --class-map={
        "box": Style --background=0xff0000,
    }
    --id-map={
        "fish": Style --color=0x00ff00,
    }
```

Descendant combinators in CSS are used to restict a style to the
  descendents of a particular element.  In toit we use nesting and
  indentation:

```css
/* Paragraphs, but only when inside the box class. */
.box p {
  color: #ffffff;
}
```

In Toit this would be written as:
```toit
style := Style
    --class-map={
        "box": Style
            --type-map={
                "p": Style --color=0xffffff,
            },
    }
```

In CSS you can have several selectors for the same style, separated by commas.
  In Toit you have to create a named style to do this.

```css
/* Styling for things with classes 'fish' and 'fowl'. */
.fish, .fowl {
  color: #ffffff;
  background: #606060;
}
```

```toit
FISH-OR-FOWL-STYLE ::= Style --color=0xffffff --background=0x606060

style := Style
    --class-map={
        "fish": FISH-OR-FOWL-STYLE,
        "fowl": FISH-OR-FOWL-STYLE,
    }
```

Since an element can have more than one element class, it's often better to make
  a new element class for the combination, and use that instead.

```toit
style := Style
    --class-map={
        "fish-or-fowl": Style --color=0xffffff --background=0x606060,
    }
```
*/
class Style:
  map_/Map
  id_map_/Map? := ?
  class_map_/Map? := ?
  type_map_/Map? := ?

  constructor.empty: return EMPTY_STYLE_

  constructor
      --color/int?=null
      --font/Font?=null
      --background=null
      --border/Border?=null
      --class_map/Map?=null
      --id_map/Map?=null
      --type_map/Map?=null
      .map_={:}:
    if color != null: map_["color"] = color
    if font != null: map_["font"] = font
    if border != null: map_["border"] = border
    Background.check_valid background
    if background: map_["background"] = background
    class_map_ = class_map
    id_map_ = id_map
    type_map_ = type_map

  iterate_properties [block]:
    map_.do: | key/string value |
      block.call key value

  matching_styles --type/string? --classes/List? --id/string? [block]:
    if type_map_ and type:
      type_map_.get type --if_present=: | style/Style |
        block.call style
    if class_map_ and classes and classes.size != 0:
      if classes.size == 1:
        class_map_.get classes[0] --if_present=: | style/Style |
          block.call style
      else:
        class_map_.do: | key/string style/Style |
          if classes.contains key:
            block.call style
    if id_map_ and id:
      id_map_.get id --if_present=: | style/Style |
        block.call style
