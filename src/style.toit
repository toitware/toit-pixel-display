// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import font show Font

ALIGN_LEFT ::= 0
ALIGN_CENTER ::= 1
ALIGN_RIGHT ::= 2

EMPTY_STYLE_ ::= Style

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
    if background != null:
      map_["background"] = (background is List) ? background : [background]
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
