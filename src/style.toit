// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import bitmap
import bitmap show ORIENTATION-0 ORIENTATION-90 ORIENTATION-180 ORIENTATION-270
import font show Font

import .element as element
import .one-byte_ as one-byte
import .pixel-display

ALIGN-LEFT ::= 0
ALIGN-CENTER ::= 1
ALIGN-RIGHT ::= 2

EMPTY-STYLE_ ::= Style

/**
A background is anything that can draw itself on an element as a background.
There is support for just using ints (rgb colors) as backgrounds to save
  memory and flash.
*/
interface Background:
  draw canvas/Canvas x/int y/int w/int h/int --autoclipped/bool -> none

  /**
  We also use colors (ints) as backgrounds, so this helper method will
    either just draw the plain color background, or call the draw method
    on a real Background object.
  */
  static draw background canvas/Canvas x/int y/int w/int h/int --autoclipped/bool -> none:
    if background is int:
      if autoclipped:
        canvas.set-all-pixels background
      else:
        canvas.rectangle x y --w=w --h=h --color=background
    else if background != null:
      (background as Background).draw canvas x y w h --autoclipped=autoclipped

  static check-valid background -> none:
    if background != null and background is not int and background is not Background:
      throw "INVALID_ARGUMENT"

class MultipleBackgrounds implements Background:
  list_/List

  constructor .list_:
    list_.do: if list_ is not Background: throw "INVALID_ARGUMENT"

  draw canvas/Canvas x/int y/int w/int h/int --autoclipped/bool -> none:
    list_.do:
      Background.draw it canvas x y w h --autoclipped=autoclipped

interface Border:
  /**
  Draws the border within the given rectangle.
  */
  draw canvas/Canvas x/int y/int w/int h/int -> none

  /**
  Calls the block with x, y, w, h, to indicate the area that needs to be
    redrawn if the container with this border moves.
  For example for drop shadows this will include the shadow.
  */
  invalidation-area x/int y/int w/int h/int [block] -> none

  /**
  Calls the block with the w and h after the border has been subtracted.
  */
  inner-dimensions w/int h/int [block] -> none

  /**
  Calls the block with the width of the left and top edges, indicating how much
    the content needs to be shifted to the right and down to make room for the
    border.
  */
  offsets [block] -> none

  /**
  Draws 100% opacity for the border and frame shape.
  We don't need to carve out the window content, there is assumed to be a
    different alpha map for that.
  */
  frame-map canvas/Canvas w/int h/int

  /**
  Draws 100% opacity for the window content.
  In the simplest case this is a filled rectangle.
  */
  content-map canvas/Canvas w/int h/int

/**
Borders that are not actually drawn, but you can see where they are by the
  boundary between the window content and the surroundings.
*/
abstract class InvisibleBorder implements Border:
  draw canvas x y w h:
    // Nothing to draw.

  invalidation-area x/int y/int w/int h/int [block]:
    block.call x y w h

  inner-dimensions w h [block] -> none:
    block.call w h

  offsets [block] -> none:
    block.call 0 0

  frame-map canvas w h:
    return Canvas.ALL-TRANSPARENT

  abstract content-map canvas/Canvas w/int h/int

class NoBorder extends InvisibleBorder:
  content-map canvas/Canvas w/int h/int:
    transparency-map := canvas.make-alpha-map
    transparency-map.rectangle 0 0 --w=w --h=h --color=0xff
    return transparency-map

NO-BORDER_/Border ::= NoBorder

/// A rectangular border inside the window's area, with a solid color.
class SolidBorder implements Border:
  border-width_/BorderWidth
  color_/int

  constructor --width/int --color/int:
    color_ = color
    border-width_ = BorderWidth width

  constructor --border-width/BorderWidth --color/int:
    color_ = color
    border-width_ = border-width

  invalidation-area x/int y/int w/int h/int [block]:
    block.call x y w h

  inner-dimensions w/int h/int [block] -> none:
    border-width_.inner-dimensions w h block

  offsets [block] -> none:
    border-width_.offsets block

  draw canvas/Canvas x/int y/int w/int h/int -> none:
    if border-width_.left != 0:
      canvas.rectangle x y --w=border-width_.left --h=h --color=color_
    if border-width_.right != 0:
      canvas.rectangle (x + w - border-width_.right) y --w=border-width_.right --h=h --color=color_
    if border-width_.top != 0:
      canvas.rectangle x y --w=w --h=border-width_.top --color=color_
    if border-width_.bottom != 0:
      canvas.rectangle x (y + h - border-width_.bottom) --w=w --h=border-width_.bottom --color=color_

  // Draws 100% opacity for the border and frame shape.  We don't need to carve
  // out the window content, there is assumed to be a different alpha map for
  // that.
  frame-map canvas/Canvas w/int h/int:
    if border-width_ == 0: return Canvas.ALL-TRANSPARENT  // The frame is not visible anywhere.
    // Transform inner dimensions not including border
    border-widths := border-width_.left + border-width_.right
    border-heights := border-width_.top + border-width_.bottom
    canvas.transform.xywh border-width_.left border-width_.top (w - border-widths) (h - border-heights): | x2 y2 w2 h2 |
      if x2 <= 0 and y2 <= 0 and x2 + w2 >= canvas.width_ and y2 + h2 >= canvas.height_:
        // In the middle, the window content is 100% opaque and draw on top of the
        // frame.  There is no need to provide a frame alpha map, so for efficiency we
        // just return 0 which indicates the frame is 100% transparent.
        return Canvas.ALL-TRANSPARENT
    canvas.transform.xywh 0 0 w h: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if right <= 0 or bottom <= 0 or x2 >= canvas.width_ or y2 >= canvas.height_:
        // The frame is completely outside the window, so it is 100% transparent.
        return Canvas.ALL-TRANSPARENT
    // We need to create a bitmap to describe the frame's extent.
    transparency-map := canvas.make-alpha-map
    // Declare the whole area inside the frame's extent opaque.  The window content will
    // draw on top of this as needed.
    transparency-map.rectangle 0 0
        --w = w
        --h = h
        --color = 0xff
    return transparency-map

  // Draws 100% opacity for the window content, a filled rectangle.
  content-map canvas/Canvas w/int h/int:
    border-widths := border-width_.left + border-width_.right
    border-heights := border-width_.top + border-width_.bottom
    canvas.transform.xywh border-width_.left border-width_.top (w - border-widths) (h - border-heights): | x2 y2 w2 h2 |
      if x2 <= 0 and y2 <= 0 and x2 + w2 >= canvas.width_ and y2 + h2 >= canvas.height_:
        return Canvas.ALL-OPAQUE  // The content is 100% opaque in the middle.
      right := x2 + w2
      bottom := y2 + h2
      if right <= 0 or bottom <= 0 or x2 >= canvas.width_ or y2 >= canvas.height_:
        return Canvas.ALL-TRANSPARENT  // The content is 100% transparent outside the window.
    // We need to create a bitmap to describe the content's extent.
    transparency-map := canvas.make-alpha-map
    // Declare the whole area inside the content's extent opaque.  The window content will
    // draw on top of this as needed.
    transparency-map.rectangle border-width_.left border-width_.top
        --w = w - border-widths
        --h = h - border-heights
        --color = 0xff
    return transparency-map

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
  constructor --top-and-bottom/int --left-and-right/int:
    top = bottom = top-and-bottom
    left = right = left-and-right

  /// A constructor with arbitrary thickness on all sides and zero on all unmentioned sides.
  constructor --.top/int=0 --.right/int=0 --.bottom/int=0 --.left/int=0:

  inner-dimensions w/int h/int [block]:
    block.call (w - left - right) (h - top - bottom)

  offsets [block]:
    block.call left top

/** A zero width border that gives an object rounded corners. */
class RoundedCornerBorder extends InvisibleBorder:
  radius_/int := ?
  opacities_/RoundedCornerOpacity_? := null
  shadow-palette_/ByteArray := #[]

  constructor --radius/int=5:
    if not 0 <= radius <= RoundedCornerOpacity_.TABLE-SIZE_: throw "OUT_OF_RANGE"
    radius_ = radius

  radius -> int: return radius_

  ensure-opacities_:
    if opacities_: return
    opacities_ = RoundedCornerOpacity_.get radius_

  // Draws 100% opacity for the window content, a filled rounded-corner rectangle.
  content-map canvas/Canvas w/int h/int:
    canvas.transform.xywh 0 0 w h: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if x2 >= canvas.width_ or y2 >= canvas.height_ or right <= 0 or bottom <= 0:
        return Canvas.ALL-TRANSPARENT  // The content is 100% transparent outside the window.
      if x2           <= 0 and y2 + radius_ <= 0 and right           >= canvas.width_ and bottom - radius_ >= canvas.height_ or
         x2 + radius_ <= 0 and y2           <= 0 and right - radius_ >= canvas.width_ and bottom           >= canvas.height_:
        return Canvas.ALL-OPAQUE  // The content is 100% opaque in the cross in the middle where there are no corners.
    // We need to create a bitmap to describe the content's extent.
    transparency-map := canvas.make-alpha-map
    draw-rounded-corners_ transparency-map 0 0 w h 0xff
    return transparency-map

  draw-rounded-corners_ transparency-map x2/int y2/int w2/int h2/int opacity/int -> none:
    // Part 1 of a cross of opacity (the rounded rectangle minus its corners).
    transparency-map.rectangle (x2 + radius_) y2 --w=(w2 - 2 * radius_) --h=h2 --color=opacity
    if radius_ == 0: return
    ensure-opacities_
    // Part 2 of the cross.
    transparency-map.rectangle x2 (y2 + radius_) --w=w2 --h=(h2 - 2 * radius_) --color=opacity
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
    if transparency-map.supports-8-bit:
      palette := opacity == 0xff ? #[] : shadow-palette_
      draw-corners_ x2 y2 right bottom radius_: | byte-opacity _ x y orientation |
        transparency-map.pixmap x y
            --pixels = byte-opacity
            --palette = palette
            --source-width = RoundedCornerOpacity_.PATCH-SIZE_
            --orientation = orientation
    else:
      draw-corners_ x2 y2 right bottom radius_: | _ bit-opacity x y orientation |
        transparency-map.bitmap x y
            --pixels = bit-opacity
            --alpha = ONE-ZERO-ALPHA_
            --palette = ONE-ZERO-PALETTE_
            --source-width = RoundedCornerOpacity_.PATCH-SIZE_
            --source-line-stride = (RoundedCornerOpacity_.PATCH-SIZE_ >> 3)
            --orientation = orientation

  static ONE-ZERO-PALETTE_ ::= #[0, 0, 0, 1, 1, 1]
  static ONE-ZERO-ALPHA_ ::= #[0, 0xff]

  /**
  Arguments:
  - $left, $top, $right, $bottom:  The coordinates of the rectangle with the rounded corners.
  - $corner-radius: The radius of the rounded corners.
  - $block: A block to call to draw each corner.
  Block arguments are:
  - byte-opacity: a 256 entry byte array of 16x16 opacity values, or null if the patch is fully transparent.
  - bit-opacity: a 32 entry byte array of 16x16 opacity values, or null if the patch is fully transparent.
  - x: the x coordinate of the top left corner of the patch.
  - y: the y coordinate of the top left corner of the patch.
  - orientation: the orientation to draw the patch, one of $ORIENTATION-0, $ORIENTATION-90, $ORIENTATION-180, $ORIENTATION-270.
  */
  draw-corners_ left/int top/int right/int bottom/int corner-radius/int [block]:
    for j := 0; j < corner-radius; j += RoundedCornerOpacity_.PATCH-SIZE_:
      for i := 0; i < corner-radius; i += RoundedCornerOpacity_.PATCH-SIZE_:
        byte-opacity := opacities_.get-bytes-patch i j
        if byte-opacity:
          bit-opacity := opacities_.get-bits-patch i j
          // Top left corner:
          block.call byte-opacity bit-opacity (left + corner-radius - i) (top + corner-radius - j) ORIENTATION-180
          // Top right corner:
          block.call byte-opacity bit-opacity (right + j) (top + corner-radius - i) ORIENTATION-90
          // Bottom left corner:
          block.call byte-opacity bit-opacity (left + corner-radius - j) (bottom + i) ORIENTATION-270
          // Bottom right corner:
          block.call byte-opacity bit-opacity (right + i) (bottom + j) ORIENTATION-0

class ShadowRoundedCornerBorder extends RoundedCornerBorder:
  blur-radius_/int := ?
  drop-distance-x_/int := ?
  drop-distance-y_/int := ?
  shadow-opacity-percent_/int := ?

  constructor --radius/int=5 --blur-radius/int=5 --drop-distance-x/int=10 --drop-distance-y/int=10 --shadow-opacity-percent/int=25:
    if not 0 <= blur-radius <= 6: throw "OUT_OF_RANGE"
    blur-radius_ = blur-radius
    drop-distance-x_ = drop-distance-x
    drop-distance-y_ = drop-distance-y
    shadow-opacity-percent_ = shadow-opacity-percent
    super --radius=radius
    update-shadow-palette_

  extent-helper_ [block]:
    extension-left := blur-radius_ > drop-distance-x_ ?  blur-radius_ - drop-distance-x_ : 0
    extension-top := blur-radius_ > drop-distance-y_ ?  blur-radius_ - drop-distance-y_ : 0
    extension-right := blur-radius_ > -drop-distance-x_ ? blur-radius_ + drop-distance-x_ : 0
    extension-bottom := blur-radius_ > -drop-distance-y_ ? blur-radius_ + drop-distance-y_ : 0
    block.call extension-left extension-top extension-right extension-bottom

  invalidation-area x/int y/int w/int h/int [block]:
    extent-helper_: | left top right bottom |
      block.call
          x - left
          y - top
          w + left + right
          h + top + bottom

  blur-radius -> int: return blur-radius_

  drop-distance-x -> int: return drop-distance-x_

  drop-distance-y -> int: return drop-distance-y_

  shadow-opacity-percent -> int: return shadow-opacity-percent_

  update-shadow-palette_ -> none:
    max-shadow-opacity := (shadow-opacity-percent_ * 2.5500001).to-int
    shadow-palette_ = #[]
    if max-shadow-opacity != 0xff:
      shadow-palette_ = ByteArray 0x300: ((it / 3) * max-shadow-opacity) / 0xff

  frame-map canvas/Canvas w/int h/int:
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
        return Canvas.ALL-TRANSPARENT

    // Transform outer dimensions including border to determine if the canvas
    // is wholly outside the window and its shadow.
    extent-helper_: | left top right bottom |
      canvas.transform.xywh -left -top (w + left + right) (h + top + bottom): | x2 y2 w2 h2 |
        if x2 + w2 <= 0 or y2 + h2 <= 0 or x2 >= canvas.width_ or y2 >= canvas.height_:
          return Canvas.ALL-TRANSPARENT  // The frame is not opaque outside the shadow

    // Create a bitmap to describe the frame's extent.  It needs to be padded
    // relative to the canvas size so we can use the Gaussian blur.
    transparency-map := canvas.make-alpha-map --padding=(blur-radius * 2)
    transparency-map.transform = (canvas.transform.invert.translate -blur-radius -blur-radius).invert

    max-shadow-opacity := (shadow-opacity-percent * 2.5500001).to-int
    draw-rounded-corners_ transparency-map drop-distance-x_ drop-distance-y_ w h max-shadow-opacity

    if blur-radius == 0 or transparency-map is not one-byte.OneByteCanvas_:
      return transparency-map

    one-byte-map := transparency-map as one-byte.OneByteCanvas_

    // Blur the shadow.
    bitmap.bytemap-blur one-byte-map.pixels_ transparency-map.width_ blur-radius

    // Crop off the extra that was added to blur.
    transparency-map-unpadded := canvas.make-alpha-map
    bitmap.blit
        one-byte-map.pixels_[blur-radius + blur-radius * one-byte-map.width_..]   // Source.
        (transparency-map-unpadded as one-byte.OneByteCanvas_).pixels_  // Destination.
        transparency-map-unpadded.width_   // Bytes per line.
        --source-line-stride = transparency-map.width_
    return transparency-map-unpadded

  draw-frame canvas/Canvas:
    canvas.set-all-pixels 0

class RoundedCornerOpacity_:
  byte-opacities_ := {:}  // Map from x,y to an 8x8 opacity map.
  bit-opacities_ := {:}  // Map from x,y to an 8x8 opacity map.
  radius/int
  static cache_ := Map.weak

  static OPAQUE-CORNER-PATCH_/ByteArray ::=
      ByteArray (PATCH-SIZE_ * PATCH-SIZE_): 0xff

  static get corner-radius/int -> RoundedCornerOpacity_:
    cached := cache_.get corner-radius
    if cached: return cached
    new := RoundedCornerOpacity_.private_ corner-radius
    cache_[corner-radius] = new
    return new

  static TABLE-SIZE_/int ::= 256
  // The heights of a top-right quarter circle of radius [TABLE-SIZE_].
  static QUARTER-CIRCLE_/ByteArray ::= create-quarter-circle-array_ TABLE-SIZE_

  static create-quarter-circle-array_ size -> ByteArray:
    array := ByteArray size
    hypotenuse := (size - 1) * (size - 1)
    size.repeat:
      // Pythagoras.
      array[it] = (hypotenuse - it * it).sqrt.to-int
    return array

  get-bytes-patch i/int j/int -> ByteArray?:
    return byte-opacities_[(i << 16) + j]

  get-bits-patch i/int j/int -> ByteArray?:
    return bit-opacities_[(i << 16) + j]

  static PATCH-SIZE_ ::= 16

  constructor.private_ .radius:
    // We have a quarter circle in a 256x256 square that we downsample to the
    //   radius.  The quarter circle is represented by QUARTER-CIRCLE, a
    //   256-entry table of column heights.
    // For example if the radius is 5 then the downsample is 256/5=51, which
    //   means each 51x51 square within the 256x256 square is reduced to
    //   a single pixel in the 5x5 map we are producing.
    downsample := TABLE-SIZE_ / radius
    // The steps are a list of the offsets of the pixels we are producing
    //   in the original 256x256 square.  For example, for a radius of 5 the
    //   steps are [0, 51, 102, 153, 204].  We pad it up by PATCH-SIZE_ to make
    //   the code below simpler.
    steps := List (radius + PATCH-SIZE_): (it * TABLE-SIZE_) / radius
    for j := 0; j < radius; j += PATCH-SIZE_:
      for i := 0; i < radius; i += PATCH-SIZE_:
        max-b := steps[j + PATCH-SIZE_]
        min-b := steps[j]
        max-a := steps[i + PATCH-SIZE_]
        min-a := steps[i]
        column-height-index := max-b + downsample - 1
        column-height := column-height-index >= QUARTER-CIRCLE_.size ? -1 : QUARTER-CIRCLE_[column-height-index]
        // Set the opacity according to whether the downsample x downsample
        // square is fully outside the circle, fully inside the circle or on
        // the edge.
        opacity-key := (i << 16) + j
        if column-height >= max-a + downsample:
          byte-opacities_[opacity-key] = OPAQUE-CORNER-PATCH_
        else if QUARTER-CIRCLE_[min-b] < min-a:
          byte-opacities_[opacity-key] = null
        else:
          // Edge of quarter circle, we have to make an 8x8 patch of
          // opacity.
          byte-opacity := ByteArray (PATCH-SIZE_ * PATCH-SIZE_)
          (min PATCH-SIZE_ (radius - j)).repeat: | small-j |
            b := steps[j + small-j]
            (min PATCH-SIZE_ (radius - i)).repeat: | small-i |
              idx := small-j * PATCH-SIZE_ + small-i
              a := steps[i + small-i]
              if QUARTER-CIRCLE_[b + downsample - 1] >= a + downsample:
                byte-opacity[idx] = 0xff  // Inside quarter circle.
              else if QUARTER-CIRCLE_[b] < a:
                byte-opacity[idx] = 0  // Outside quarter circle.
              else:
                total := 0
                downsample.repeat: | small-y |
                  extent := QUARTER-CIRCLE_[b + small-y]
                  if extent >= a + downsample:
                    total += downsample
                  else if extent > a:
                    total += extent - a
                byte-opacity[idx] = (0xff * total) / (downsample * downsample)
          byte-opacities_[opacity-key] = byte-opacity
    // Generate bit versions of the opacities in case we have to use it on a
    // 2-color or 3-color display.
    byte-opacities_.do: | key/int byte-opacity |
      if byte-opacity == null:
        bit-opacities_[key] = null
      else:
        bit-opacity := ByteArray (byte-opacity.size >> 3): | part |
          mask := 0
          idx := part * 8
          8.repeat: | bit |
            mask = mask << 1
            mask |= (byte-opacity[idx + bit] < 128 ? 0 : 1)
          mask  // Initialize byte array with last value in block.
        bit-opacities_[key] = bit-opacity

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
  id-map_/Map? := ?
  class-map_/Map? := ?
  type-map_/Map? := ?

  constructor.empty: return EMPTY-STYLE_

  constructor
      --x/int?=null
      --y/int?=null
      --w/int?=null
      --h/int?=null
      --color/int?=null
      --font/Font?=null
      --background=null
      --border/Border?=null
      --class-map/Map?=null
      --id-map/Map?=null
      --type-map/Map?=null
      --align-right/bool=false
      --align-center/bool=false
      .map_={:}:
    if x != null: map_["x"] = x
    if y != null: map_["y"] = y
    if w != null: map_["w"] = w
    if h != null: map_["h"] = h
    if color != null: map_["color"] = color
    if font != null: map_["font"] = font
    if border != null: map_["border"] = border
    if align-right and align-center: throw "INVALID_ARGUMENT"
    if align-right: map_["alignment"] = ALIGN-RIGHT
    if align-center: map_["alignment"] = ALIGN-CENTER
    Background.check-valid background
    if background: map_["background"] = background
    class-map_ = class-map
    id-map_ = id-map
    type-map_ = type-map

  iterate-properties [block]:
    map_.do: | key/string value |
      block.call key value

  matching-styles --type/string? --classes/List? --id/string? [block]:
    if type-map_ and type:
      type-map_.get type --if-present=: | style/Style |
        block.call style
    if class-map_ and classes and classes.size != 0:
      if classes.size == 1:
        class-map_.get classes[0] --if-present=: | style/Style |
          block.call style
      else:
        class-map_.do: | key/string style/Style |
          if classes.contains key:
            block.call style
    if id-map_ and id:
      id-map_.get id --if-present=: | style/Style |
        block.call style
