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

Styles are generally immutable, but their parent pointer is set late (by the
  constructor of the parent), so that we can use constructors with literal maps
  to build up the style.

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
  In Toit you have to create a named style to do this, and it has to have the
  same parent everywhere it appears.

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

Since an element can have more than one class, it's often better to make
  a new class for the combination, and use that instead.

```toit
style := Style
    --class-map={
        "fish-or-fowl": Style --color=0xffffff --background=0x606060,
    }
```
*/
class Style:
  map_/Map := {:}
  id_map_/Map := {:}
  class_map_/Map := {:}
  type_map_/Map := {:}
  parent/Style?                 // Set by parent.

  constructor.empty: return EMPTY_STYLE_

  constructor --.parent=null
      --color/int?=null
      --font/Font?=null
      --background/List?=null
      --class_map/Map?=null
      --id_map/Map?=null:
    if color != null: color= color
    if font != null: font= font
    if background != null: background= background
    if class_map != null: class_map= class_map
    if id_map != null: id_map= id_map

  get_ --type/string --classes/List? --id/string? key/string:
    return get_helper_ parent type classes id key this

  static get_helper_ parent/Style? type/string classes/List? id/string? key/string child/Style:
    leaf_lookup := : | style/Style key/string |
      value := style.map_.get key
      if value: return value

    leaf_lookup.call child key
    if not parent: return null
    if id:
      id_style := parent.id_map_.get id
      if id_style and id_style != child:
        leaf_lookup.call id_style key
    if classes:
      classes.do: | element_class/string |
        class_style := parent.class_map_.get element_class
        if class_style and class_style != child:
          leaf_lookup.call class_style key
    type_style := parent.type_map_.get type
    if type_style and type_style != child:
      leaf_lookup.call type_style key
    default_style := parent.type_map_.get "*"
    if default_style and default_style != child:
      leaf_lookup.call default_style key
    return get_helper_ parent.parent type classes id key parent

  color --type/string --classes/List?=null --id/string?=null -> int?:
    return get_ --type=type --classes=classes --id=id "color"

  font --type/string --classes/List?=null --id/string?=null -> Font?:
    return get_ --type=type --classes=classes --id=id "font"

  background --type/string --classes/List?=null --id/string?=null -> List?:
    return get_ --type=type --classes=classes --id=id "background"

  get key/string --type/string --classes/List?=null --id/string?=null:
    return get_ --type=type --classes=classes --id=id key
