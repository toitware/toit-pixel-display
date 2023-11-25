// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import font show Font
import .common

ALIGN_LEFT ::= 0
ALIGN_CENTER ::= 1
ALIGN_RIGHT ::= 2

EMPTY_STYLE_ ::= Style

/**
A background is anything that can draw itself on an element as a background.
*/
interface Background:
  draw canvas/Canvas x/int y/int w/int h/int -> none

  /**
  We also use colors (ints) as backgrounds, so this helper method will
    either just draw the plain color background, or call the draw method
    on a real Background object.
  */
  static draw background canvas/Canvas x/int y/int w/int h/int -> none:
    if background is int:
      canvas.rectangle x y --w=w --h=h --color=background
    else if background != null:
      (background as Background).draw canvas x y w h

  static check_valid background -> none:
    if background != null and background is not int and background is not Background:
      throw "INVALID_ARGUMENT"

class MultipleBackgrounds implements Background:
  list_/List

  constructor .list_:
    list_.do: if list_ is not Background: throw "INVALID_ARGUMENT"

  draw canvas/Canvas x/int y/int w/int h/int -> none:
    list_.do:
      Background.draw it canvas x y w h

abstract class Border:
  border_width_/BorderWidth

  /// Draws the border within the given rectangle.
  abstract draw canvas/Canvas x/int y/int w/int h/int -> none

  inner_dimensions w/int h/int [block] -> none:
    border_width_.inner_dimensions w h block

  offsets [block] -> none:
    border_width_.offsets block

  constructor .border_width_/BorderWidth:

class SolidBorder extends Border:
  color_/int

  constructor --width/int --color/int:
    color_ = color
    super (BorderWidth width)

  constructor --border_width/BorderWidth --color/int:
    color_ = color
    super border_width

  draw canvas/Canvas x/int y/int w/int h/int -> none:
    if border_width_.left != 0:
      canvas.rectangle x y --w=border_width_.left --h=h --color=color_
    if border_width_.right != 0:
      canvas.rectangle (x + w - border_width_.right) y --w=border_width_.right --h=h --color=color_
    if border_width_.top != 0:
      canvas.rectangle x y --w=w --h=border_width_.top --color=color_
    if border_width_.bottom != 0:
      canvas.rectangle x (y + h - border_width_.bottom) --w=w --h=border_width_.bottom --color=color_

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
  border-color: #ff0000;
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
        "box": Style --border-color=0xff0000,
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
      --border_color/int?=null
      --class_map/Map?=null
      --id_map/Map?=null
      --type_map/Map?=null
      .map_={:}:
    if color != null: map_["color"] = color
    if font != null: map_["font"] = font
    if border_color != null: map_["border-color"] = border_color
    Background.check_valid background
    map_["background"] = background
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
