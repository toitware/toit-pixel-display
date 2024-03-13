// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import bitmap show *
import math

import .pixel-display
import .style

class GradientSpecifier:
  color/int
  percent/int

  constructor --.color/int .percent/int:

/**
Gradients are similar to CSS linear gradients and SVG gradients.
They are given a list of $GradientSpecifier, each of which has a color and
  a percentage, indicating where in the gradient the color should appear.
  The specifiers should be ordered in increasing order of percentage.
Angles are as in CSS, with 0 degrees being up and 90 degrees being to the right
  (this is different from text orientations, which go anti-clockwise).
See https://cssgradient.io/ for a visual explanation and playground for CSS
  gradients.
Example:
```
  gradient := GradientBackground --angle=45
      --specifiers=[
          GradientSpecifier --color=0xff0000 10,    // Red from 0-10%, red-to-green from 10-50%.
          GradientSpecifier --color=0x00ff00 50,    // Green-to-blue from 50-90%.
          GradientSpecifier --color=0x0000ff 90,    // Blue from 90-100%.
      ]
```
*/
class GradientBackground implements Background:
  angle/int
  specifiers/List
  hash_/int? := null
  rendering_/GradientRendering_? := null

  constructor --angle/int --.specifiers/List:
    this.angle = normalize-angle_ angle
    validate-specifiers_ specifiers

  operator == other -> bool:
    if other is not GradientBackground: return false
    if other.angle != angle: return false
    if other.specifiers.size != specifiers.size: return false
    for i := 0; i < specifiers.size; i++:
      if other.specifiers[i].color != specifiers[i].color: return false
      if other.specifiers[i].percent != specifiers[i].percent: return false
    return true

  hash-code -> int:
    if not hash_:
      hash := 0
      specifiers.do: | it |
        hash = (hash * 31) & 0xfff_ffff
        hash += it.color + 47 * it.percent
        hash_ = hash
    return hash_

  draw canvas/Canvas x/int y/int w/int h/int --autoclipped/bool --foo=false -> none:
    print "  foo: $foo"
    if not rendering_: rendering_ = GradientRendering_.get w h this
    rendering_.draw canvas x y --autoclipped=autoclipped --foo=foo

  static normalize-angle_ angle/int -> int:
    angle %= 360
    if angle < 0: angle += 360
    return angle

  static validate-specifiers_ specifiers -> none:
    last-percent := 0
    if specifiers.size == 0: throw "INVALID_ARGUMENT"
    specifiers.do: | specifier/GradientSpecifier |
      if specifier.percent < last-percent: throw "INVALID_ARGUMENT"
      last-percent = specifier.percent
      if last-percent > 100: throw "INVALID_ARGUMENT"

class GradientSpecification_:
  w/int?
  h/int?
  gradient/GradientBackground
  hash_/int? := null

  constructor .w .h .gradient:

  operator == other -> bool:
    if other is not GradientSpecification_: return false
    if other.w != w or other.h != h: return false
    if other.hash-code != hash-code: return false
    return other.gradient == gradient

  hash-code -> int:
    if not hash_:
      hash_ = (w or 0) + 3 * (h or 0) + 71 * gradient.hash-code
    return hash_

class GradientRendering_:
  red-pixels_/ByteArray? := null
  green-pixels_/ByteArray? := null
  blue-pixels_/ByteArray? := null
  texture-length_ /int := 0
  texture-length-repeats_ /int := 1
  draw-vertical_/bool? := null
  angle_ /int
  h_ /int := 0
  w_ /int := 0

  static map_ := Map.weak

  static get w/int? h/int? gradient/GradientBackground -> GradientRendering_:
    probe := GradientSpecification_ w h gradient
    rendering := map_.get probe
    if rendering: return rendering  // Might be null because the map is weak.
    value := GradientRendering_ w h gradient
    map_[probe] = value
    return value

  constructor w/int? h/int? gradient/GradientBackground:
    angle := gradient.angle
    specifiers/List := gradient.specifiers
    if 180 <= angle < 360:
      angle -= 180
      specifiers = List specifiers.size:
        i := specifiers.size - 1 - it
        GradientSpecifier (100 - specifiers[i].percent)
            --color = specifiers[i].color
    angle_ = angle
    if h != 0 and h != null and w != 0 and w != null:
      h_ = h
      w_ = w

      // CSS gradient angles are:
      //    0 bottom to top.
      //   90 left to right.
      //  180 top to bottom.
      //  270 right to left.
      // But we normalize them to be 0-179 and reverse the colors if needed.

      // Create an angle that is between 0 and 90 degrees and has the same
      // amount of verticalness as the gradient.
      if angle >= 90: angle = 180 - angle
      // Create an angle from the center of the rectangle to the top right
      // corner.
      // This is the angle that we will use to calculate the verticalness of
      // the rectangle.
      rangle := math.atan (w.to-float / h)  // From 0 to PI/2.
      rangle *= 180.0 / math.PI            // From 0 to 90.
      draw-vertical_ = angle < rangle
      texture-length/int := ?
      texture-length-repeats_ = 1
      if draw-vertical_:
        // The gradient is more vertical than the rectangle, so we will draw
        // vertical lines on the rectangle.
        texture-length = (h + w * (math.tan (angle * math.PI / 180.0)) + 0.01).round
        if angle == 0:
          // For efficiency, repeat the gradient a few times in the buffer.
          texture-length = h
          texture-length-repeats_ = max 1 (512 / texture-length)
      else:
        // The gradient is more horizontal than the rectangle, so we will draw
        // horizontal lines on the rectangle.
        texture-length = (w + h * (math.tan ((90 - angle) * math.PI / 180.0)) + 0.01).round
        if angle == 90:
          // For efficiency, repeat the gradient a few times in the buffer.
          texture-length = w
          texture-length-repeats_ = max 1 (512 / texture-length)
      texture-length_ = texture-length

      red-pixels_ = ByteArray texture-length * texture-length-repeats_
      green-pixels_ = ByteArray texture-length * texture-length-repeats_
      blue-pixels_ = ByteArray texture-length * texture-length-repeats_
      ranges/List := extract-ranges_ specifiers
      ranges.do: | range |
        get-colors range texture-length: | index red green blue |
          red-pixels_[index] = red
          green-pixels_[index] = green
          blue-pixels_[index] = blue
        (texture-length-repeats_ - 1).repeat:
          red-pixels_.replace ((it + 1) * texture-length) red-pixels_[0..texture-length]
          green-pixels_.replace ((it + 1) * texture-length) green-pixels_[0..texture-length]
          blue-pixels_.replace ((it + 1) * texture-length) blue-pixels_[0..texture-length]

  draw canvas/Canvas x/int y/int --autoclipped/bool --foo/bool -> none:
    if not canvas.supports-8-bit: throw "UNSUPPORTED"
    angle := angle_
    w := w_
    h := h_
    analysis := canvas.bounds-analysis x y w h
    if analysis == Canvas.DISJOINT:
      if foo: print "  DISJOINT"
      return
    // Determine whether the draw operations will be automatically clipped for
    // us, or whether we need to do it ourselves by using slices for drawing
    // operations.  We could also check whether we are inside a window that will
    // use compositing to clip everything.
    if analysis == Canvas.CANVAS-IN-AREA or analysis == Canvas.COINCIDENT: autoclipped = true

    // CSS gradient angles are:
    //    0 bottom to top.
    //   90 left to right
    //  180 top to bottom
    //  270 right to left

    repeats := texture-length-repeats_
    source-width := 0
    r := null
    g := null
    b := null

    update-r-g-b-block := : | y-or-x h-or-w lines orientation offset |
      o := offset >> 16
      // Repeats != 1 implies the gradient is vertical or horizontal, which
      // means we don't need any clipping.
      if autoclipped or repeats != 1:
        source-width = texture-length_
        buf-size := texture-length_ * lines
        r = red-pixels_[..buf-size]
        g = green-pixels_[..buf-size]
        b = blue-pixels_[..buf-size]
        if orientation == ORIENTATION-90:
          y-or-x + o  // Return value.
        else:
          y-or-x - o  // Return value.
      else:
        r = red-pixels_[o .. o + h-or-w]
        g = green-pixels_[o .. o + h-or-w]
        b = blue-pixels_[o .. o + h-or-w]
        source-width = h-or-w
        y-or-x  // Return value.

    if draw-vertical_:
      // The gradient goes broadly vertically, and we draw in vertical strips.
      orientation/int := ORIENTATION-90
      // X2 and y2 are the x, y location we are drawing the gradient, but
      // adjusted for orientation.
      x2/int := x
      y2/int := y + h
      if angle >= 90:  // Top to bottom.
        orientation = ORIENTATION-270
        x2++
        y2 = y
      // Use fixed point with 16 bits after the decimal point.
      step := ((texture-length_ - h) << 16) / w
      offset := 0
      canvas.visible-x-range x2 w: | x3 r3 |
        offset += step * (x3 - x2)
        for i := x3; i < r3; i += repeats:
          lines := min repeats (r3 - i)
          skew-adjusted-y := update-r-g-b-block.call y2 h lines orientation offset
          if canvas.gray-scale:
            canvas.pixmap     i skew-adjusted-y --pixels=b        --source-width=source-width --orientation=orientation
          else:
            canvas.rgb-pixmap i skew-adjusted-y --r=r --g=g --b=b --source-width=source-width --orientation=orientation
          offset += step
    else:
      // The gradient goes broadly horizontally, and we draw in horizontal
      // strips.
      up/bool := angle >= 90
      step := ((texture-length_ - w) << 16) / h  // n.16 fixed point.
      offset := 0
      loop-body := : | i lines |
        skew-adjusted-x := update-r-g-b-block.call x w lines ORIENTATION-0 offset
        if canvas.gray-scale:
          canvas.pixmap     skew-adjusted-x i --pixels=b        --source-width=source-width
        else:
          canvas.rgb-pixmap skew-adjusted-x i --r=r --g=g --b=b --source-width=source-width
        offset += step
      if up:
        canvas.visible-y-range y (y + h): | y3 b3 |
          offset += step * (y3 - y)
          for i := y3; i < b3; i += repeats: loop-body.call i (min repeats (b3 - i))
      else:
        assert: repeats == 1
        b2 := y + h - 1
        canvas.visible-y-range y b2: | y3 b3 |
          offset += step * (b2 - b3)
          for i := b3; i >= y3; i--: loop-body.call i 1

  /// Returns a list of quadruples of the form starting-percent ending-percent start-color end-color.
  static extract-ranges_ specifiers/List -> List:
    result := []
    for i := -1; i < specifiers.size; i++:
      from := i < 0 ? 0 : specifiers[i].percent
      to := i >= specifiers.size - 1 ? 100 : specifiers[i + 1].percent
      if to != from:
        from-color := specifiers[max i 0].color
        to-color := specifiers[min (i + 1) (specifiers.size - 1)].color
        result.add [from, to, from-color, to-color]
    return result

  static get-colors range/List h/int [block] -> none:
    from-y := range[0] * h / 100
    to-y := range[1] * h / 100
    if to-y == from-y: return
    divisor := to-y - from-y
    from-color := range[2]
    // Use 8.16 fixed point arithmetic to avoid floating point.
    r := from-color & 0xff0000
    g := (from-color & 0xff00) << 8
    b := (from-color & 0xff) << 16
    to-color := range[3]
    to-r := to-color & 0xff0000
    to-g := (to-color & 0xff00) << 8
    to-b := (to-color & 0xff) << 16
    step-r := (to-r - r) / divisor
    step-g := (to-g - g) / divisor
    step-b := (to-b - b) / divisor
    for y := from-y; y < to-y; y++:
      block.call y (r >> 16) (g >> 16) (b >> 16)
      r += step-r
      g += step-g
      b += step-b
