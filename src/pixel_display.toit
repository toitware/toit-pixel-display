// Copyright (C) 2018 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
A library for rendering on pixel-based displays attached to devices.
See https://docs.toit.io/language/sdk/display
*/

import bitmap show *
import font show Font
import icons show Icon

import .bar_code
import .common
import .element
import .two_color as two_color
import .three_color as three_color
import .two_bit_texture as two_bit
import .four_gray as four_gray
import .true_color as true_color
import .gray_scale as gray_scale
import .several_color as several_color
import .one_byte as one_byte
import .style

FLAG_2_COLOR ::=         0b1
FLAG_3_COLOR ::=         0b10
FLAG_4_COLOR ::=         0b100
FLAG_GRAY_SCALE ::=      0b1000
FLAG_SEVERAL_COLOR ::=   0b10000
FLAG_TRUE_COLOR ::=      0b100000
FLAG_PARTIAL_UPDATES ::= 0b1000000

/**
Abstract superclass for all pixel display drivers.
For example, implemented by the drivers in
  https://pkg.toit.io/package/color_tft&url=github.com%2Ftoitware%2Ftoit-color-tft&index=latest
  and
  https://pkg.toit.io/package/ssd1306&url=github.com%2Ftoitware%2Ftoit-ssd1306&index=latest
*/
abstract class AbstractDriver:
  abstract width -> int
  abstract height -> int
  abstract flags -> int
  x_rounding -> int: return 8
  y_rounding -> int: return 8
  start_partial_update speed/int -> none:
  start_full_update speed/int -> none:
  clean left/int top/int right/int bottom/int -> none:
  commit left/int top/int right/int bottom/int -> none:
  draw_two_color l/int t/int r/int b/int pixels/ByteArray -> none:
    throw "Not a two-color driver"
  draw_two_bit l/int t/int r/int b/int plane0/ByteArray plane1/ByteArray -> none:
    throw "Not a two-bit driver"
  draw_gray_scale l/int t/int r/int b/int pixels/ByteArray -> none:
    throw "Not a gray-scale driver"
  draw_several_color l/int t/int r/int b/int pixels/ByteArray -> none:
    throw "Not a several-color driver"
  draw_true_color l/int t/int r/int b/int red/ByteArray green/ByteArray blue/ByteArray -> none:
    throw "Not a true-color driver"
  close -> none:

/**
Common code for pixel-based displays connected to devices.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
abstract class PixelDisplay implements Window:
  // The image to display.
  elements_ := {}
  background_ := null
  width: return driver_.width
  height: return driver_.width
  inner_width: return driver_.width
  inner_height: return driver_.width

  // Need-to-redraw is tracked as a bit array of dirty bits, arranged in
  // SSD1306 layout so we can use bitmap_rectangle to invalidate areas.
  // One bit in the dirty map covers an area of 8x8 pixels of the display.
  static CLEAN_ ::= 0
  static DIRTY_ ::= 1
  dirty_bytes_per_line_ := 0
  dirty_ := null
  dirty_left_ := 0
  dirty_top_ := 0
  dirty_right_ := 0
  dirty_bottom_ := 0

  dirty_accumulator_ := ByteArray 1

  x_rounding_ := 1
  y_rounding_ := 1

  driver_ /AbstractDriver := ?
  speed_ := 50  // Speed-quality of current screen update.

  transform_ /Transform

  /**
  By default the orientation is the natural orientation of the display driver.
  If $portrait is false, then a landscape orientation is used.
  If $portrait is true, then a portrait orientation is used, or in the case
     that the display driver is exactly square, a rotated orientation is used.
  The orientation is rotated by 180 degrees if $inverted is true.
  */
  constructor .driver_ --transform/Transform?=null --portrait/bool?=null --inverted/bool=false:
    x_rounding_ = driver_.x_rounding
    y_rounding_ = driver_.y_rounding
    height := round_up driver_.height y_rounding_
    if driver_.flags & FLAG_PARTIAL_UPDATES != 0:
      dirty_bytes_per_line_ = (driver_.width >> 3) + 1
      dirty_strips := (height >> 6) + 1  // 8-tall strips of dirty bits.
      dirty_ = ByteArray dirty_bytes_per_line_ * dirty_strips

    if transform:
      if portrait != null or inverted: throw "INVALID_ARGUMENT"
      transform_ = transform
    else:
      rotation := 0
      if portrait != null:
        if portrait == (driver_.width < driver_.height):
          rotation = inverted ? 180 : 0
        else:
          rotation = inverted ? 270 : 90
      else if inverted:
        rotation = 180
      if rotation == 0:
        transform_ = Transform.identity
      else if rotation == 90:
        transform_ = (Transform.identity.translate 0 driver_.height).rotate_left
      else if rotation == 180:
        transform_ = (Transform.identity.translate driver_.width driver_.height).rotate_left.rotate_left
      else:
        transform_ = (Transform.identity.translate driver_.width 0).rotate_right

    if driver_.flags & FLAG_PARTIAL_UPDATES != 0:
      all_is_dirty_

  abstract default_draw_color_ -> int
  abstract default_background_color_ -> int

  /** Returns a transform that uses the display in portrait mode.  */
  portrait -> Transform:
    if not portrait_:
      if driver_.height >= driver_.width:
        portrait_ = Transform.identity
      else:
        portrait_ = (Transform.identity.translate 0 driver_.height).rotate_left
    return portrait_
  portrait_ := null

  /**
  Returns a transform that uses the display in portrait mode, but rotated
    180 degrees relative to the portrait method.
  */
  inverted_portrait -> Transform:
    if not inverted_portrait_:
      if driver_.height >= driver_.width:
        inverted_portrait_ = (Transform.identity.translate driver_.width driver_.height).rotate_left.rotate_left
      else:
        inverted_portrait_ = (Transform.identity.translate driver_.width 0).rotate_right
    return inverted_portrait_
  inverted_portrait_ := null

  /** Returns a transform that uses the display in landscape mode.  */
  landscape -> Transform:
    if not landscape_:
      if driver_.height < driver_.width:
        landscape_ = Transform.identity
      else:
        landscape_ = (Transform.identity.translate 0 driver_.height).rotate_left
    return landscape_
  landscape_ := null

  /**
  Returns a transform that uses the display in landscape mode, but rotated
    180 degrees relative to the landscape method.  Sometimes called 'seascape'.
  */
  inverted_landscape -> Transform:
    if not inverted_landscape_:
      if driver_.height < driver_.width:
        inverted_landscape_ = (Transform.identity.translate driver_.width driver_.height).rotate_left.rotate_left
      else:
        inverted_landscape_ = (Transform.identity.translate driver_.width 0).rotate_right
    return inverted_landscape_
  inverted_landscape_ := null

  abstract background= color/int -> none

  set_styles styles/List -> none:
    elements_.do:
      if it is Element:
        element := it as Element
        element.set_styles styles

  /**
  Adds an element to a display.  The next time the display is refreshed, this
    element will be drawn.  Elements added to this display are drawn in the
    order they were added, so the first-added elements are at the back and the
    last-added are at the front.  However elements can have children.
    This enables you to later add elements that are not at the
    front, by adding them as children of an Element that is not at the front.
  */
  add element/Element -> none:
    elements_.add element
    element.change_tracker = this
    element.invalidate

  /**
  Removes an element that was previously added.
  */
  remove element/Element -> none:
    elements_.remove element
    element.invalidate
    element.change_tracker = null

  /** Removes all elements.  */
  remove_all:
    elements_.do: it.change_tracker = null
    if elements_.size != 0: child_invalidated_element 0 0 driver_.width driver_.height
    elements_ = {}

  child_invalidated_element x/int y/int w/int h/int -> none:
    transform_.xywh x y w h: | x2 y2 w2 h2 |
      child_invalidated_ x2 y2 w2 h2

  child_invalidated_ x/int y/int w/int h/int -> none:
    if not dirty_: return  // Some devices don't use the dirty array to track changes.
    dirty_left_ = min dirty_left_ x
    dirty_right_ = max dirty_right_ (x + w)
    dirty_top_ = min dirty_top_ y
    dirty_bottom_ = max dirty_bottom_ (y + h)

    // Round up the invalidated area.
    rx := x & 7
    x = (x - rx) >> 3
    w = (w + rx + 7) >> 3
    ry := y & 7
    y = (y - ry) >> 3
    h = (h + ry + 7) >> 3

    // x, y, w, h now measured in 8x8 blocks.
    bitmap_rectangle x y DIRTY_ w h dirty_ dirty_bytes_per_line_

  line_is_clean_ y:
    idx := (y >> 6) * dirty_bytes_per_line_
    mask := 1 << ((y >> 3) & 0b111)
    dirty_accumulator_[0] = CLEAN_
    blit dirty_[idx..idx+dirty_bytes_per_line_] dirty_accumulator_ dirty_bytes_per_line_ --destination_pixel_stride=0 --operation=OR
    return dirty_accumulator_[0] & mask == CLEAN_  // Only works because CLEAN_ == 0

  is_dirty_ x y:
    idx := (y >> 6) * dirty_bytes_per_line_
    mask := 1 << ((y >> 3) & 0b111)
    byte := x >> 3
    return dirty_[idx + byte] & mask != CLEAN_  // Only works because CLEAN_ == 0

  /// For displays that don't support any form of partial update.
  draw_entire_display_:
    driver_.start_full_update speed_
    w := driver_.width
    step := round_up
        max_canvas_height_ driver_.width
        y_rounding_
    canvas := create_canvas_ w step
    List.chunk_up 0 (round_up driver_.height y_rounding_) step: | top bottom |
      // For the Elements.
      // To get the translation for this tile in the driver coordinates instead
      // of the display coordinates, we invert the 2d transform, then translate
      // it, then invert it again.
      canvas.transform = (transform_.invert.translate 0 top).invert
      canvas.set_all_pixels background_
      elements_.do:
        it.draw canvas
      draw_ 0 top driver_.width bottom canvas
    driver_.commit 0 0 driver_.width driver_.height

  /**
  Draws the elements.

  After changing the display, for example by adding, removing or moving
    elements, call this to refresh the screen.  Optionally give a $speed
    between 0 and 100 to indicate the speed-image quality tradeoff.
  */
  draw --speed/int=50 -> none:
    speed_ = speed
    if speed < 10 or driver_.flags & FLAG_PARTIAL_UPDATES == 0:
      draw_entire_display_
      if dirty_: bitmap_zap dirty_ CLEAN_
      return

    // Send data for the whole screen, even if only part of it changed.
    if speed < 50: all_is_dirty_

    driver_.start_partial_update speed
    refreshed := false
    try:
      refresh_dimensions ::= [driver_.width, 0, driver_.height, 0]
      update_frame_buffer false refresh_dimensions
      refresh_ refresh_dimensions[0] refresh_dimensions[2] refresh_dimensions[1] refresh_dimensions[3]
      refreshed = true
    finally:
      if not refreshed: refresh_ 0 0 0 0

    all_is_clean_

  all_is_clean_ -> none:
    bitmap_zap dirty_ CLEAN_
    dirty_left_ = driver_.width
    dirty_right_ = 0
    dirty_top_ = driver_.height
    dirty_bottom_ = 0

  all_is_dirty_ -> none:
    bitmap_zap dirty_ DIRTY_
    dirty_left_ = 0
    dirty_right_ = driver_.width
    dirty_top_ = 0
    dirty_bottom_ = driver_.height

  // Clean determines if we should clean or draw the dirty area.
  update_frame_buffer clean/bool refresh_dimensions -> none:
    redraw := : | l t r b |
      if clean:
        clean_rect_ l t r b
      else:
        redraw_rect_ l t r b

    // Perhaps we can do it all with one canvas.
    l := round_down (max 0 dirty_left_) x_rounding_
    r := round_up (min driver_.width dirty_right_) x_rounding_
    t := round_down (max 0 dirty_top_) y_rounding_
    b := round_up (min driver_.height dirty_bottom_) y_rounding_

    if l >= r or t >= b: return

    if (max_canvas_height_ (r - l)) >= b - t:
      redraw.call l t r b
      return

    // Perhaps we can do it in two canvases, split to be as square as
    // possible.
    if r - l > b - t and r - l >= x_rounding_ * 2:
      w := round_up ((r - l) >> 1) x_rounding_
      if (max_canvas_height_ w) >= b - t:
        redraw.call l t (l + w) b
        redraw.call (l + w) t r b
        return
    // Perhaps we can do it in two canvases, split vertically.
    else if b - t >= y_rounding_ * 2:
      h := round_up ((b - t) >> 1) y_rounding_
      if (max_canvas_height_ (r - l)) >= h:
        redraw.call l t r (t + h)
        redraw.call l (t + h) r b
        return

    // Start with a width target of (slightly less than) 64 pixels, but ask
    // the canvas how tall the patches can be. It will normally try pick a
    // height that keeps things inside a 4k page.
    width_target := 64
    width := ?
    max_height := ?
    while true:
      // Canvas sizes must often be slightly less than 4k in order to fit into
      // a 4k page with object header overhead. By subtracting 8 here we get nice
      // heights like 8, 16, 24, 32 that almost fill the max canvas size.
      width = min driver_.width (width_target - 8)
      max_height = max
          round_down (max_canvas_height_ width) y_rounding_
          y_rounding_
      // Don't widen any more if the patches are already too flat to fill the full height.
      if max_height < driver_.height: break
      // Don't widen any more if the patches already cover the whole width.
      if width >= driver_.width: break
      width_target += width_target

    // The algorithm below requires that x aligns with 8 pixels, the resolution
    // of the dirty map.
    start_x := round_down (max 0 dirty_left_) 8

    // Outer loop - the coarse rectangles that are the max size of
    // update patches.
    for y:= 0; y < driver_.height; y += max_height:
      while line_is_clean_ y:
        y = (y + 8) & ~7  // Move on to next factor of 8.
        if y >= driver_.height: break
      if y >= driver_.height: break
      for x := start_x; x < driver_.width; x += width:
        left := x
        right := min (x + width) driver_.width
        top := y
        bottom := min (y + max_height) driver_.height

        // Quick check if the whole rectangle is clean.  This is a little
        // imprecise because the same mask is used for all lines.
        mask := 0
        for iy := top; iy < bottom; iy += 8:
          mask |= 1 << ((iy >> 3) & 0b111)
        idx := (top >> 6) * dirty_bytes_per_line_ + (left >> 3)
        end_idx := ((round_up bottom 64) >> 6) * dirty_bytes_per_line_
        dirty_accumulator_[0] = CLEAN_
        blit dirty_[idx..end_idx] dirty_accumulator_ ((right - left + 7) >> 3) --source_line_stride=dirty_bytes_per_line_ --destination_pixel_stride=0 --destination_line_stride=0 --operation=OR
        if dirty_accumulator_[0] & mask == CLEAN_:
          continue

        // Inner loop.  For each coarse rectangle, find the smallest rectangle
        // that covers all the dirty bits.
        dirty_left := right
        dirty_right := left
        dirty_top := bottom
        dirty_bottom := top
        for iy := top; iy < bottom; iy += 8:
          line_mask := 1 << ((iy >> 3) & 0b111)
          if dirty_accumulator_[0] & line_mask == CLEAN_:
            continue
          for ix := left; ix < right; ix += 8:
            if is_dirty_ ix iy:
              dirty_left = min dirty_left ix
              dirty_right = max dirty_right (ix + 8)
              dirty_top = min dirty_top iy
              dirty_bottom = max dirty_bottom (iy + 8)
        dirty_left = max dirty_left (round_down (max 0 dirty_left_) x_rounding_)
        dirty_right = min dirty_right (round_up (min driver_.width dirty_right_) x_rounding_)
        dirty_top = max dirty_top (round_down (max 0 dirty_top_) y_rounding_)
        dirty_bottom = min dirty_bottom (round_up (min driver_.height dirty_bottom_) y_rounding_)
        if dirty_left <= dirty_right and dirty_top <= dirty_bottom:
          if dirty_top < refresh_dimensions[2]: refresh_dimensions[2] = dirty_top
          if dirty_bottom > refresh_dimensions[3]: refresh_dimensions[3] = dirty_bottom
          if dirty_left < refresh_dimensions[0]: refresh_dimensions[0] = dirty_left
          if dirty_right > refresh_dimensions[1]: refresh_dimensions[1] = dirty_right
          redraw.call dirty_left dirty_top dirty_right dirty_bottom

  redraw_rect_ left/int top/int right/int bottom/int -> none:
    canvas := create_canvas_ (right - left) (bottom - top)
    // For the Elements:
    // To get the translation for this tile in the driver coordinates instead
    // of the display coordinates, we invert the 2d transform, then translate
    // it, then invert it again.
    canvas.transform = (transform_.invert.translate left top).invert

    canvas.set_all_pixels background_
    elements_.do:
      it.draw canvas

    draw_ left top right bottom canvas

  abstract max_canvas_height_ width/int -> int

  abstract create_canvas_ w/int h/int -> Canvas

  abstract draw_ x y w h canvas/Canvas -> none

  clean_rect_ left/int top/int right/int bottom/int -> none:
    driver_.clean left top right bottom

  refresh_ left/int top/int right/int bottom/int -> none:
    driver_.commit left top right bottom

  /// Frees up the display so other process groups can use it.
  /// This happens automatically when the process group exits.
  close -> none:
    driver_.close

/**
Black-and-white pixel-based display connected to a device.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
class TwoColorPixelDisplay extends PixelDisplay:
  constructor driver/AbstractDriver --inverted/bool=false --portrait/bool=false --transform/Transform?=null:
    super driver --inverted=inverted --portrait=portrait --transform=transform
    background_ = two_color.WHITE

  default_draw_color_ -> int:
    return two_color.BLACK

  default_background_color_ -> int:
    return two_color.WHITE

  background= color/int -> none:
    if background_ != color:
      background_ = color
      child_invalidated_ 0 0 driver_.width driver_.height

  max_canvas_height_ width/int -> int:
    height := 0
    width_rounded := round_up width 8
    height_rounded := round_up driver_.height 8
    if width_rounded * height_rounded >> 3 < 4000:
      // If we can fit both the red and black plane in < 8k then do that.
      height = height_rounded
    else:
      // Some multiple of 8 where each plane fits in one page.
      height = (4000 / width_rounded) << 3
    // We can't work well with canvases that are less than 8 pixels tall.
    return max 8 height

  create_canvas_ w/int h/int -> Canvas:
    return two_color.Canvas_ w h

  draw_ x/int y/int w/int h/int canvas/two_color.Canvas_ -> none:
      driver_.draw_two_color x y w h canvas.pixels_

/**
Pixel-based display with four shades of gray, connected to a device.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
class FourGrayPixelDisplay extends TwoBitPixelDisplay_:
  constructor driver/AbstractDriver:
    super driver
    background_ = four_gray.WHITE

  background= color/int -> none:
    if background_ != color:
      background_ = color
      child_invalidated_ 0 0 driver_.width driver_.height

  default_draw_color_ -> int:
    return four_gray.BLACK

  default_background_color_ -> int:
    return four_gray.WHITE

  create_canvas_ w/int h/int -> Canvas:
    return four_gray.Canvas_ w h

/**
Pixel-based display with black, white, and red, connected to a device.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
class ThreeColorPixelDisplay extends TwoBitPixelDisplay_:
  constructor driver/AbstractDriver:
    super driver
    background_ = three_color.WHITE

  background= color/int -> none:
    if background_ != color:
      background_ = color
      child_invalidated_ 0 0 driver_.width driver_.height

  default_draw_color_ -> int:
    return three_color.BLACK

  default_background_color_ -> int:
    return three_color.WHITE

  create_canvas_ w/int h/int -> Canvas:
    return three_color.Canvas_ w h

abstract class TwoBitPixelDisplay_ extends PixelDisplay:
  background_ := three_color.WHITE

  constructor driver/AbstractDriver --inverted/bool=false --portrait/bool=false --transform/Transform?=null:
    super driver --inverted=inverted --portrait=portrait --transform=transform

  max_canvas_height_ width:
    width_rounded := round_up width 8
    height_rounded := round_up driver_.height 8
    height := ?
    if width_rounded * height_rounded >> 3 < 4000:
      // If we can fit both the red and black plane in < 8k then do that.
      height = height_rounded
    else:
      // Some multiple of 8 where each plane fits in one page.
      height = (4000 / width_rounded) << 3
    // We can't work well with canvases that are less than 8 pixels tall.
    return max 8 height

  draw_ x/int y/int w/int h/int canvas/two_bit.Canvas_ -> none:
    driver_.draw_two_bit x y w h canvas.plane_0_ canvas.plane_1_

/**
Pixel-based display with up to 256 shades of gray, connected to a device.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
class GrayScalePixelDisplay extends PixelDisplay:
  constructor driver/AbstractDriver --inverted/bool=false --portrait/bool=false --transform/Transform?=null:
    super driver --inverted=inverted --portrait=portrait --transform=transform
    background_ = gray_scale.WHITE

  background= color/int -> none:
    if background_ != color:
      background_ = color
      child_invalidated_ 0 0 driver_.width driver_.height

  default_draw_color_ -> int:
    return gray_scale.BLACK

  default_background_color_ -> int:
    return gray_scale.WHITE

  max_canvas_height_ width:
    height := 0
    // Keep each color component under 2k so you can fit two on a page.
    height = round_down (2000 / width) 8
    // We can't work well with canvases that are less than 4 pixels tall.
    return height < 8 ? 4 : height

  create_canvas_ w/int h/int -> Canvas:
    return gray_scale.Canvas_ w h

  draw_ x/int y/int w/int h/int canvas/gray_scale.Canvas_ -> none:
    driver_.draw_gray_scale x y w h canvas.pixels_

/**
Pixel-based display with up to 256 colors, connected to a device.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
class SeveralColorPixelDisplay extends PixelDisplay:
  constructor driver/AbstractDriver --inverted/bool=false --portrait/bool=false --transform/Transform?=null:
    super driver --inverted=inverted --portrait=portrait --transform=transform
    background_ = 0

  background= color/int -> none:
    if background_ != color:
      background_ = color
      child_invalidated_ 0 0 driver_.width driver_.height

  default_draw_color_ -> int:
    return 1

  default_background_color_ -> int:
    return 0

  max_canvas_height_ width:
    height := 0
    // Keep each color component under 2k so you can fit two on a page.
    height = round_down (2000 / width) 8
    // We can't work well with canvases that are less than 4 pixels tall.
    return height < 8 ? 4 : height

  create_canvas_ w/int h/int -> Canvas:
    return several_color.Canvas_ w h

  draw_ x/int y/int w/int h/int canvas/several_color.Canvas_ -> none:
    driver_.draw_several_color x y w h canvas.pixels_

/**
Pixel-based display with up to 16 million colors, connected to a device.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
class TrueColorPixelDisplay extends PixelDisplay:
  constructor driver/AbstractDriver --inverted/bool=false --portrait/bool=false --transform/Transform?=null:
    super driver --inverted=inverted --portrait=portrait --transform=transform
    background_ = true_color.WHITE

  background= color/int -> none:
    if background_ != color:
      background_ = color
      child_invalidated_ 0 0 driver_.width driver_.height

  default_draw_color_ -> int:
    return true_color.BLACK

  default_background_color_ -> int:
    return true_color.WHITE

  max_canvas_height_ width:
    height := 0
    // Keep each color component under 2k then the packed 3-colors-in-2-bytes
    // format is still less than a page.
    height = round_down (2000 / width) 8
    // We can't work well with canvases that are less than 4 pixels tall.
    return max 4 height

  create_canvas_ w/int h/int -> Canvas:
    return true_color.Canvas_ w h

  draw_ x/int y/int w/int h/int canvas/true_color.Canvas_ -> none:
    driver_.draw_true_color x y w h canvas.red_ canvas.green_ canvas.blue_
