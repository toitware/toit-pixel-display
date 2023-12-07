// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import bitmap show *
import math

import .common
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
    this.angle = normalize_angle_ angle
    validate_specifiers_ specifiers

  operator == other -> bool:
    if other is not GradientBackground: return false
    if other.angle != angle: return false
    if other.specifiers.size != specifiers.size: return false
    for i := 0; i < specifiers.size; i++:
      if other.specifiers[i].color != specifiers[i].color: return false
      if other.specifiers[i].percent != specifiers[i].percent: return false
    return true

  hash_code -> int:
    if not hash_:
      hash := 0
      specifiers.do: | it |
        hash = (hash * 31) & 0xfff_ffff
        hash += it.color + 47 * it.percent
        hash_ = hash
    return hash_

  draw canvas/Canvas x/int y/int w/int h/int --autocropped/bool -> none:
    if not rendering_: rendering_ = GradientRendering_.get w h this
    rendering_.draw canvas x y --autocropped=autocropped

  static normalize_angle_ angle/int -> int:
    angle %= 360
    if angle < 0: angle += 360
    return angle

  static validate_specifiers_ specifiers -> none:
    last_percent := 0
    if specifiers.size == 0: throw "INVALID_ARGUMENT"
    specifiers.do: | specifier/GradientSpecifier |
      if specifier.percent < last_percent: throw "INVALID_ARGUMENT"
      last_percent = specifier.percent
      if last_percent > 100: throw "INVALID_ARGUMENT"

class GradientSpecification_:
  w/int?
  h/int?
  gradient/GradientBackground
  hash_/int? := null

  constructor .w .h .gradient:

  operator == other -> bool:
    if other is not GradientSpecification_: return false
    if other.w != w or other.h != h: return false
    if other.hash_code != hash_code: return false
    return other.gradient == gradient

  hash_code -> int:
    if not hash_:
      hash_ = (w or 0) + 3 * (h or 0) + 71 * gradient.hash_code
    return hash_

class GradientRendering_:
  red_pixels_/ByteArray? := null
  green_pixels_/ByteArray? := null
  blue_pixels_/ByteArray? := null
  texture_length_ /int := 0
  texture_length_repeats_ /int := 1
  draw_vertical_/bool? := null
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
      rangle := math.atan (w.to_float / h)  // From 0 to PI/2.
      rangle *= 180.0 / math.PI            // From 0 to 90.
      draw_vertical_ = angle < rangle
      texture_length/int := ?
      texture_length_repeats_ = 1
      if draw_vertical_:
        // The gradient is more vertical than the rectangle, so we will draw
        // vertical lines on the rectangle.
        texture_length = (h + w * (math.tan (angle * math.PI / 180.0)) + 0.01).round
        if angle == 0:
          // For efficiency, repeat the gradient a few times in the buffer.
          texture_length = h
          texture_length_repeats_ = max 1 (512 / texture_length)
      else:
        // The gradient is more horizontal than the rectangle, so we will draw
        // horizontal lines on the rectangle.
        texture_length = (w + h * (math.tan ((90 - angle) * math.PI / 180.0)) + 0.01).round
        if angle == 90:
          // For efficiency, repeat the gradient a few times in the buffer.
          texture_length = w
          texture_length_repeats_ = max 1 (512 / texture_length)
      texture_length_ = texture_length

      red_pixels_ = ByteArray texture_length * texture_length_repeats_
      green_pixels_ = ByteArray texture_length * texture_length_repeats_
      blue_pixels_ = ByteArray texture_length * texture_length_repeats_
      ranges/List := extract_ranges_ specifiers
      ranges.do: | range |
        get_colors range texture_length: | index red green blue |
          red_pixels_[index] = red
          green_pixels_[index] = green
          blue_pixels_[index] = blue
        (texture_length_repeats_ - 1).repeat:
          red_pixels_.replace ((it + 1) * texture_length) red_pixels_[0..texture_length]
          green_pixels_.replace ((it + 1) * texture_length) green_pixels_[0..texture_length]
          blue_pixels_.replace ((it + 1) * texture_length) blue_pixels_[0..texture_length]

  draw canvas/Canvas x/int y/int --autocropped/bool -> none:
    if not canvas.supports_8_bit: throw "UNSUPPORTED"
    angle := angle_
    w := w_
    h := h_
    analysis := canvas.bounds_analysis x y w h
    if analysis == Canvas.DISJOINT: return
    // Determine whether the draw operations will be automatically clipped for
    // us, or whether we need to do it ourselves by using slices for drawing
    // operations.  We could also check whether we are inside a window that will
    // use compositing to clip everything.
    if analysis == Canvas.CANVAS_IN_AREA or analysis == Canvas.COINCIDENT: autocropped = true

    // CSS gradient angles are:
    //    0 bottom to top.
    //   90 left to right
    //  180 top to bottom
    //  270 right to left

    repeats := texture_length_repeats_
    source_width := 0
    r := null
    g := null
    b := null

    update_r_g_b_block := : | y_or_x h_or_w lines orientation offset |
      o := offset >> 16
      // Repeats != 1 implies the gradient is vertical or horizontal, which
      // means we don't need any clipping.
      if autocropped or repeats != 1:
        source_width = texture_length_
        buf_size := texture_length_ * lines
        r = red_pixels_[..buf_size]
        g = green_pixels_[..buf_size]
        b = blue_pixels_[..buf_size]
        if orientation == ORIENTATION_90:
          y_or_x + o  // Return value.
        else:
          y_or_x - o  // Return value.
      else:
        r = red_pixels_[o .. o + h_or_w]
        g = green_pixels_[o .. o + h_or_w]
        b = blue_pixels_[o .. o + h_or_w]
        source_width = h_or_w
        y_or_x  // Return value.

    if draw_vertical_:
      // The gradient goes broadly vertically, and we draw in vertical strips.
      orientation/int := ORIENTATION_90
      // X2 and y2 are the x, y location we are drawing the gradient, but
      // adjusted for orientation.
      x2/int := x
      y2/int := y + h
      if angle >= 90:  // Top to bottom.
        orientation = ORIENTATION_270
        x2++
        y2 = y
      // Use fixed point with 16 bits after the decimal point.
      step := ((texture_length_ - h) << 16) / w
      offset := 0
      for i := 0; i < w; i += repeats:
        lines := min repeats (w - i)
        skew_adjusted_y := update_r_g_b_block.call y2 h lines orientation offset
        if canvas.gray_scale:
          canvas.pixmap     (i + x2) skew_adjusted_y --pixels=b        --source_width=source_width --orientation=orientation
        else:
          canvas.rgb_pixmap (i + x2) skew_adjusted_y --r=r --g=g --b=b --source_width=source_width --orientation=orientation
        offset += step
    else:
      // The gradient goes broadly horizontally, and we draw in horizontal
      // strips.
      up/bool := angle >= 90
      step := ((texture_length_ - w) << 16) / h  // n.16 fixed point.
      offset := 0
      loop_body := : | i lines |
        skew_adjusted_x := update_r_g_b_block.call x w lines ORIENTATION_0 offset
        if canvas.gray_scale:
          canvas.pixmap     skew_adjusted_x (i + y) --pixels=b        --source_width=source_width
        else:
          canvas.rgb_pixmap skew_adjusted_x (i + y) --r=r --g=g --b=b --source_width=source_width
        offset += step
      if up:
        for i := 0; i < h; i += repeats: loop_body.call i (min repeats (h - i))
      else:
        assert: repeats == 1
        for i := h - 1; i >= 0; i--: loop_body.call i 1

  /// Returns a list of quadruples of the form starting-percent ending-percent start-color end-color.
  static extract_ranges_ specifiers/List -> List:
    result := []
    for i := -1; i < specifiers.size; i++:
      from := i < 0 ? 0 : specifiers[i].percent
      to := i >= specifiers.size - 1 ? 100 : specifiers[i + 1].percent
      if to != from:
        from_color := specifiers[max i 0].color
        to_color := specifiers[min (i + 1) (specifiers.size - 1)].color
        result.add [from, to, from_color, to_color]
    return result

  static get_colors range/List h/int [block] -> none:
    from_y := range[0] * h / 100
    to_y := range[1] * h / 100
    if to_y == from_y: return
    divisor := to_y - from_y
    from_color := range[2]
    // Use 8.16 fixed point arithmetic to avoid floating point.
    r := from_color & 0xff0000
    g := (from_color & 0xff00) << 8
    b := (from_color & 0xff) << 16
    to_color := range[3]
    to_r := to_color & 0xff0000
    to_g := (to_color & 0xff00) << 8
    to_b := (to_color & 0xff) << 16
    step_r := (to_r - r) / divisor
    step_g := (to_g - g) / divisor
    step_b := (to_b - b) / divisor
    for y := from_y; y < to_y; y++:
      block.call y (r >> 16) (g >> 16) (b >> 16)
      r += step_r
      g += step_g
      b += step_b
