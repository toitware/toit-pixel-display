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

/** A zero width border that gives an object rounded corners. */
class RoundedCornerBorder extends NoBorder:
  radius_/int := ?
  opacities_/RoundedCornerOpacity_? := null
  shadow_palette_/ByteArray := #[]

  constructor --radius/int=5:
    if not 0 <= radius <= RoundedCornerOpacity_.TABLE_SIZE_: throw "OUT_OF_RANGE"
    radius_ = radius

  needs_clipping -> bool: return true

  radius -> int: return radius_

  extent x/int y/int w/int h/int [block]:
    block.call x y w h   // Does not protrude beyond the inner bounds.

  ensure_opacities_:
    if opacities_: return
    opacities_ = RoundedCornerOpacity_.get radius_

  frame_map canvas/Canvas w/int h/int:
    return element.ClippingDiv.ALL_TRANSPARENT  // No frame on these windows.

  // Draws 100% opacity for the window content, a filled rounded-corner rectangle.
  content_map canvas/Canvas w/int h/int:
    canvas.transform.xywh 0 0 w h: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if x2 >= canvas.width_ or y2 >= canvas.height_ or right <= 0 or bottom <= 0:
        return element.ClippingDiv.ALL_TRANSPARENT  // The content is 100% transparent outside the window.
      if x2           <= 0 and y2 + radius_ <= 0 and right           >= canvas.width_ and bottom - radius_ >= canvas.height_ or
         x2 + radius_ <= 0 and y2           <= 0 and right - radius_ >= canvas.width_ and bottom           >= canvas.height_:
        return element.ClippingDiv.ALL_OPAQUE  // The content is 100% opaque in the cross in the middle where there are no corners.
    // We need to create a bitmap to describe the content's extent.
    transparency_map := canvas.make_alpha_map
    draw_rounded_corners_ transparency_map 0 0 w h 0xff
    return transparency_map

  draw_rounded_corners_ transparency_map x2/int y2/int w2/int h2/int opacity/int -> none:
    // Part 1 of a cross of opacity (the rounded rectangle minus its corners).
    transparency_map.rectangle (x2 + radius_) y2 --w=(w2 - 2 * radius_) --h=h2 --color=opacity
    if radius_ == 0: return
    ensure_opacities_
    // Part 2 of the cross.
    transparency_map.rectangle x2 (y2 + radius_) --w=w2 --h=(h2 - 2 * radius_) --color=opacity
    // The rounded corners.
    // opacity_ has an alpha map shaped like this (only rounder).
    // ______
    // |    |
    // |    /
    // |___/

    left := x2 + radius_ - 1
    right := x2 + w2 - radius_
    top := y2 + radius_ - 1
    bottom := y2 + h2 - radius_
    if transparency_map is one_byte.OneByteCanvas_:
      palette := opacity == 0xff ? #[] : shadow_palette_
      draw_corners_ x2 y2 right bottom radius_: | x y orientation |
        transparency_map.pixmap x y --pixels=opacities_.byte_opacity --palette=palette --source_width=radius_ --orientation=orientation
    else:
      draw_corners_ x2 y2 right bottom radius_: | x y orientation |
        stride := (round_up radius_ 8) >> 3
        transparency_map.bitmap x y --pixels=opacities_.bit_opacity --alpha=ONE_ZERO_ALPHA_ --palette=ONE_ZERO_PALETTE_ --source_width=radius_ --source_line_stride=stride --orientation=orientation

  static ONE_ZERO_PALETTE_ ::= #[0, 0, 0, 1, 1, 1]
  static ONE_ZERO_ALPHA_ ::= #[0, 0xff]

  draw_corners_ left/int top/int right/int bottom/int corner_radius/int [block]:
    // Top left corner:
    block.call (left + corner_radius) (top + corner_radius) ORIENTATION_180
    // Top right corner:
    block.call right (top + corner_radius) ORIENTATION_90
    // Bottom left corner:
    block.call (left + corner_radius) bottom ORIENTATION_270
    // Bottom right corner:
    block.call right bottom ORIENTATION_0

class ShadowRoundedCornerBorder extends RoundedCornerBorder:
  blur_radius_/int := ?
  drop_distance_x_/int := ?
  drop_distance_y_/int := ?
  shadow_opacity_percent_/int := ?

  constructor --radius/int=5 --blur_radius/int=5 --drop_distance_x/int=10 --drop_distance_y/int=10 --shadow_opacity_percent/int=25:
    if not 0 <= blur_radius <= 6: throw "OUT_OF_RANGE"
    blur_radius_ = blur_radius
    drop_distance_x_ = drop_distance_x
    drop_distance_y_ = drop_distance_y
    shadow_opacity_percent_ = shadow_opacity_percent
    super --radius=radius
    update_shadow_palette_

  extent_helper_ [block]:
    extension_left := blur_radius_ > drop_distance_x_ ?  blur_radius_ - drop_distance_x_ : 0
    extension_top := blur_radius_ > drop_distance_y_ ?  blur_radius_ - drop_distance_y_ : 0
    extension_right := blur_radius_ > -drop_distance_x_ ? blur_radius_ + drop_distance_x_ : 0
    extension_bottom := blur_radius_ > -drop_distance_y_ ? blur_radius_ + drop_distance_y_ : 0
    block.call extension_left extension_top extension_right extension_bottom

  invalidation_area x/int y/int w/int h/int [block]:
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

  update_shadow_palette_ -> none:
    max_shadow_opacity := (shadow_opacity_percent_ * 2.5500001).to_int
    shadow_palette_ = #[]
    if max_shadow_opacity != 0xff:
      shadow_palette_ = ByteArray 0x300: ((it / 3) * max_shadow_opacity) / 0xff

  frame_map canvas/Canvas w/int h/int:
    // Transform inner dimensions excluding shadow to determine if the canvas
    // is wholly inside the window.
    canvas.transform.xywh 0 0 w h: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if x2           <= 0 and y2 + radius_ <= 0 and right           >= canvas.width_ and bottom - radius_ >= canvas.height_ or
         x2 + radius_ <= 0 and y2           <= 0 and right - radius_ >= canvas.width_ and bottom           >= canvas.height_:
        // In the middle, the window content is 100% opaque and draw on top of the
        // frame.  There is no need to provide a frame alpha map, so for efficiency we
        // just return 0 which indicates the frame is 100% transparent.
        return element.ClippingDiv.ALL_TRANSPARENT

    // Transform outer dimensions including border to determine if the canvas
    // is wholly outside the window and its shadow.
    extent_helper_: | left top right bottom |
      canvas.transform.xywh -left -top (w + left + right) (h + top + bottom): | x2 y2 w2 h2 |
        if x2 + w2 <= 0 or y2 + h2 <= 0 or x2 >= canvas.width_ or y2 >= canvas.height_:
          return element.ClippingDiv.ALL_TRANSPARENT  // The frame is not opaque outside the shadow

    // Create a bitmap to describe the frame's extent.  It needs to be padded
    // relative to the canvas size so we can use the Gaussian blur.
    transparency_map := canvas.make_alpha_map --padding=(blur_radius * 2)
    transparency_map.transform = (canvas.transform.invert.translate -blur_radius -blur_radius).invert

    max_shadow_opacity := (shadow_opacity_percent * 2.5500001).to_int
    draw_rounded_corners_ transparency_map drop_distance_x_ drop_distance_y_ w h max_shadow_opacity

    if blur_radius == 0 or transparency_map is not one_byte.OneByteCanvas_:
      return transparency_map

    one_byte_map := transparency_map as one_byte.OneByteCanvas_

    // Blur the shadow.
    bitmap.bytemap_blur one_byte_map.pixels_ transparency_map.width_ blur_radius

    // Crop off the extra that was added to blur.
    transparency_map_unpadded := canvas.make_alpha_map
    bitmap.blit
        one_byte_map.pixels_[blur_radius + blur_radius * one_byte_map.width_..]   // Source.
        (transparency_map_unpadded as one_byte.OneByteCanvas_).pixels_  // Destination.
        transparency_map_unpadded.width_   // Bytes per line.
        --source_line_stride=transparency_map.width_
    return transparency_map_unpadded

  draw_frame canvas/Canvas:
    canvas.set_all_pixels 0

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
      bitmap.blit byte_opacity[bit..] bit_opacity ((radius + 7 - bit) >> 3)
          --source_pixel_stride=8
          --source_line_stride=radius
          --destination_line_stride=destination_line_stride
          --shift=bit
          --mask=(0x80 >> bit)
          --operation=bitmap.OR

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
  descendants of a particular element.  In Toit we use nesting and
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

Since an element can have more than one element class, it may be better to make
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
