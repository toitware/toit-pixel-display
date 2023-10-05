// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import bitmap show *
import .texture
import .true_color as true_color

abstract class BorderlessWindow_ extends ResizableTexture implements Window:
  constructor x/int y/int w/int h/int transform:
    this.transform = transform.translate x y
    super x y w h transform

  add element/Texture -> none:
    elements_.add element
    element.change_tracker = this
    element.invalidate

  remove element/Texture -> none:
    elements_.remove element
    element.invalidate
    element.change_tracker = null

  remove_all -> none:
    elements_.do:
      it.invalidate
      it.change_tracker = null
    elements_.remove_all

  transform /Transform := ?
  elements_ := {}

  child_invalidated_element x/int y/int w/int h/int -> none:
    throw "NOT_IMPLEMENTED"

  child_invalidated x/int y/int w/int h/int -> none:
    right := x + w
    bottom := y + h
    // We got the dimensions of the invalidation in driver frame of reference.
    // We must trim them to fit the window, and pass them on.
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      // Now we have our own coordinates in driver frame of reference.
      left2 := max x x2
      top2 := max y y2
      right2 := min right (x2 + w2)
      bottom2 := min bottom (y2 + h2)
      if right2 > left2 and bottom2 > top2:
        if change_tracker:
          change_tracker.child_invalidated left2 top2 (right2 - left2) (bottom2 - top2)

/**
A WindowTexture_ is a collections of textures.  It is modeled like a painting hung on
  a wall.  It consists (from back to front) of a wall, a frame and the painting
  itself. The optional frame extends around and behind the picture, and can be
  partially transparent on true-color displays, which enables drop shadows.  The
  painting can also be partially transparent.
*/
abstract class WindowTexture_ extends BorderlessWindow_ implements Window:
  inner_x_ /int := ?
  inner_y_ /int := ?
  inner_w_ /int := ?
  inner_h_ /int := ?

  /**
  Changes the inner width (without any borders) of the window.
  */
  width= new_width/int:
    if new_width != inner_w_:
      inner_w_ = new_width
      update_

  /**
  Changes the inner height (without any borders) of the window.
  */
  height= new_height/int:
    if new_height != inner_h_:
      inner_h_ = new_height
      update_

  /**
  Changes the top left corner (without any borders) of the window.
  */
  move_to new_x/int new_y/int -> none:
    if new_x != inner_x_ or new_y != inner_y_:
      inner_x_ = new_x
      inner_y_ = new_y
      update_

  update_ -> none:
    invalidate
    fix_bounding_box_
    invalidate

  abstract fix_bounding_box_ -> none

  static ALL_TRANSPARENT ::= ByteArray 1: 0
  static ALL_OPAQUE ::= ByteArray 1: 0xff

  static is_all_transparent opacity/ByteArray -> bool:
    return opacity.size == 1 and opacity[0] == 0

  static is_all_opaque opacity/ByteArray -> bool:
    return opacity.size == 1 and opacity[0] == 0xff

  /**
  Returns a canvas that is an alpha map for the given area that describes where
    the wall around this window shines through.  This defines the edges and
    shadows of a window frame.  For 2-color and 3-color textures this is a
    bitmap with 0 for transparent and 1 for opaque.  For true-color and
    gray-scale textures it is a bytemap with 0 for transparent and 0xff for
    opaque.  As a special case it may return a single-entry byte array, which
    means all pixels have the same transparency.
  */
  abstract frame_map canvas/AbstractCanvas -> ByteArray

  /**
  Returns a canvas that is an alpha map for the given area that describes where
    the painting is visible.  This defines the edges of the content of this
    window.  For 2-color and 3-color textures this is a bitmap with 0 for
    transparent and 1 for opaque.  For true-color and gray-scale textures it is
    a bytemap with 0 for transparent and 0xff for opaque.  As a special case it
    may return a single-entry byte array, which means all pixels have the same
    transparency.
  */
  abstract painting_map canvas/AbstractCanvas -> ByteArray

  /**
  Draws the background on the canvas.  This represents the interior wall color
    and other interior objects will be draw on top of this.  Does not need to
    take the frame_map or painting_map into account: The canvas this function
    draws on will be composited using them afterwards.
  */
  abstract draw_background canvas/AbstractCanvas -> none

  /**
  Expected to draw the frame on the canvas.  This represents the window frame
    color.  Does not need to take the frame_map or painting_map into account: The
    return value from this function will be composited using them afterwards.
  */
  abstract draw_frame canvas

  constructor .inner_x_ .inner_y_ .inner_w_ .inner_h_ x/int y/int w/int h/int transform:
    super x y w h transform

  // After the textures under us have drawn themselves, we draw on top.
  write2_ canvas/AbstractCanvas:
    win_w := canvas.width_
    win_h := canvas.height_

    painting_opacity := painting_map canvas

    // If the window is 100% painting at these coordinates then we can draw the
    // elements of the window and no compositing is required.  We merely draw
    // the window background color and then draw the textures.
    if is_all_opaque painting_opacity:
      draw_background canvas
      elements_.do: it.write_ canvas
      return

    frame_opacity := frame_map canvas

    // The complicated case where we have to composite the tile from the wall,
    // the frame, and the painting_opacity.
    frame_canvas := null
    if not is_all_transparent frame_opacity:
      frame_canvas = canvas.create_similar
      frame_canvas.x_offset_ = canvas.x_offset_
      frame_canvas.y_offset_ = canvas.y_offset_
      draw_frame frame_canvas

    painting_canvas := canvas.create_similar
    painting_canvas.x_offset_ = canvas.x_offset_
    painting_canvas.y_offset_ = canvas.y_offset_
    draw_background painting_canvas
    elements_.do: it.write_ painting_canvas

    canvas.composit frame_opacity frame_canvas painting_opacity painting_canvas

/**
A rectangular window with a fixed width colored border.  The border is
  added to the visible area inside the window.
*/
abstract class SimpleWindow_ extends WindowTexture_:
  border_width_ := 0
  abstract make_alpha_map_ canvas
  abstract make_opaque_ x y w h map map_width

  constructor x y w h transform .border_width_:
    super x y w h  // Inner dimensions.
        // Actual dimensions.
        x - border_width_
        y - border_width_
        w + border_width_ * 2
        h + border_width_ * 2
        transform

  border_width -> int: return border_width_

  border_width= new_width/int -> none:
    if new_width != border_width_:
      border_width_ = new_width
      update_

  fix_bounding_box_ -> none:
    // The border is on the outside of the drawable area.
    x_ = inner_x_ - border_width_
    y_ = inner_y_ - border_width_
    w_ = inner_w_ + border_width_ * 2
    h_ = inner_h_ + border_width_ * 2

  // Draws 100% opacity for the frame shape, a filled rectangle.
  // (The frame is behind the painting, so this doesn't mean we only
  // see the frame.)
  frame_map canvas/AbstractCanvas:
    if border_width_ == 0: return WindowTexture_.ALL_TRANSPARENT  // The frame is not visible anywhere.
    // Transform inner dimensions not including border
    transform_.xywh inner_x_ inner_y_ inner_w_ inner_h_: | x y w2 h2 |
      x2 := x - canvas.x_offset_
      y2 := y - canvas.y_offset_
      if x2 <= 0 and y2 <= 0 and x2 + w2 >= canvas.width_ and y2 + h2 >= canvas.height_:
        // In the middle, the window content is 100% opaque and draw on top of the
        // frame.  There is no need to provide a frame alpha map, so for efficiency we
        // just return 0 which indicates the frame is 100% transparent.
        return WindowTexture_.ALL_TRANSPARENT
    // Transform outer dimensions including border.
    transform_.xywh x_ y_ w_ h_: | x y w2 h2 |
      x2 := x - canvas.x_offset_
      y2 := y - canvas.y_offset_
      // We need to create a bitmap to describe the frame's extent.
      transparency_map := make_alpha_map_ canvas
      // Declare the whole area inside the frame's extent opaque.  The window content will
      // draw on top of this as needed.
      make_opaque_ x2 y2 w2 h2 transparency_map canvas.width_
      return transparency_map
    unreachable

  // Draws 100% opacity for the window content, a filled rectangle.
  painting_map canvas/AbstractCanvas:
    transform_.xywh inner_x_ inner_y_ inner_w_ inner_h_: | x y w2 h2 |
      x2 := x - canvas.x_offset_
      y2 := y - canvas.y_offset_
      if x2 <= 0 and y2 <= 0 and x2 + w2 >= canvas.width_ and y2 + h2 >= canvas.height_:
        return WindowTexture_.ALL_OPAQUE  // The content is 100% opaque in the middle.
      // We need to create a bitmap to describe the content's extent.
      transparency_map := make_alpha_map_ canvas
      make_opaque_ x2 y2 w2 h2 transparency_map canvas.width_
      return transparency_map
    unreachable

/** A rectangular window with rounded corners.  */
abstract class RoundedCornerWindow_ extends WindowTexture_:
  corner_radius_ := 0
  opacities_ := null
  abstract make_alpha_map_ canvas/AbstractCanvas padding
  abstract make_opaque_ x y w h map map_width --frame/bool
  abstract set_opacity_ x y opacity map map_width --frame/bool

  constructor x y w h transform .corner_radius_:
    if corner_radius_ > TABLE_SIZE_: throw "OUT_OF_RANGE"
    super x y w h x y w h transform

  constructor.protected_ inner_x inner_y inner_w inner_h x y w h transform .corner_radius_:
    if corner_radius_ > TABLE_SIZE_: throw "OUT_OF_RANGE"
    super inner_x inner_y inner_w inner_h x y w h transform

  corner_radius -> int: return corner_radius_

  corner_radius= new_radius/int -> none:
    if not 0 <= new_radius <= TABLE_SIZE_: throw "OUT_OF_RANGE"
    if new_radius != corner_radius_:
      invalid_radius := max corner_radius_ new_radius
      corner_radius_ = new_radius
      if change_tracker:
        transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
          change_tracker.child_invalidated x2                       y2                       invalid_radius invalid_radius
          change_tracker.child_invalidated x2 + w2 - invalid_radius y2                       invalid_radius invalid_radius
          change_tracker.child_invalidated x2                       y2 + h2 - invalid_radius invalid_radius invalid_radius
          change_tracker.child_invalidated x2 + w2 + invalid_radius y2 + h2 - invalid_radius invalid_radius invalid_radius

  fix_bounding_box_ -> none:
    // There's no border outside the drawable area.
    x_ = inner_x_
    y_ = inner_y_
    w_ = inner_w_
    h_ = inner_h_

  ensure_opacities_:
    if opacities_: return
    opacities_ = ByteArray corner_radius_ * corner_radius_
    downsample := TABLE_SIZE_ / corner_radius_  // For example 81 for a corner_radius of 3.
    steps := List corner_radius_:
      (it * TABLE_SIZE_) / corner_radius
    corner_radius_.repeat: | j |
      b := steps[j]
      corner_radius_.repeat: | i |
        a := steps[i]
        idx := j * corner_radius_ + i
        // Set the opacity according to whether the downsample x downsample
        // square is fully outside the circle, fully inside the circle or on
        // the edge.
        if QUARTER_CIRCLE_[b + downsample - 1] >= a + downsample:
          opacities_[idx] = 0xff  // Inside quarter circle.
        else if QUARTER_CIRCLE_[b] < a:
          opacities_[idx] = 0  // Outside quarter circle.
        else:
          // Edge of quarter circle.
          total := 0
          downsample.repeat: | small_y |
            extent := QUARTER_CIRCLE_[b + small_y]
            if extent >= a + downsample:
              total += downsample
            else if extent > a:
              total += extent - a
          opacities_[idx] = (0xff * total) / (downsample * downsample)

  frame_map canvas/AbstractCanvas:
    return WindowTexture_.ALL_TRANSPARENT  // No frame on these windows.

  static TABLE_SIZE_ ::= 256
  // The heights of a top-right quarter circle of radius [TABLE_SIZE_].
  static QUARTER_CIRCLE_ ::= create_quarter_circle_array_ TABLE_SIZE_

  static create_quarter_circle_array_ size:
    array := ByteArray size
    hypotenuse := (size - 1) * (size - 1)
    size.repeat:
      array[it] = (hypotenuse - it * it).sqrt.to_int
    return array

  // Draws 100% opacity for the window content, a filled rounded-corner rectangle.
  painting_map canvas/AbstractCanvas:
    transform_.xywh inner_x_ inner_y_ inner_w_ inner_h_: | x y w2 h2 |
      x2 := x - canvas.x_offset_
      y2 := y - canvas.y_offset_
      if x2 + corner_radius_ <= 0 and y2 + corner_radius_ <= 0 and x2 + w2 - corner_radius_ >= canvas.width_ and y2 + h2 - corner_radius_ >= canvas.height_:
        return WindowTexture_.ALL_OPAQUE  // The content is 100% opaque in the middle.
      // We need to create a bitmap to describe the content's extent.
      transparency_map := make_alpha_map_ canvas 0
      draw_rounded_corners_ transparency_map canvas.width_ x2 y2 w2 h2 --frame=false
      return transparency_map
    unreachable

  draw_rounded_corners_ transparency_map map_width x2 y2 w2 h2 --frame/bool:
    // Part 1 of a cross of opacity (the rounded rectangle minus its corners).
    make_opaque_ (x2 + corner_radius_) y2 (w2 - 2 * corner_radius_) h2 transparency_map map_width --frame=frame
    if corner_radius_ <= 0: return
    ensure_opacities_
    // Part 2 of the cross.
    make_opaque_ x2 (y2 + corner_radius_) w2 (h2 - 2 * corner_radius_) transparency_map map_width --frame=frame
    // The rounded corners:
    left := x2 + corner_radius_ - 1
    right := x2 + w2 - corner_radius_
    top := y2 + corner_radius_ - 1
    bottom := y2 + h2 - corner_radius_
    corner_radius_.repeat: | j |
      corner_radius_.repeat: | i |
        opacity := opacities_[i + j * corner_radius_]
        set_opacity_ (left - i) (top - j) opacity transparency_map map_width --frame=frame
        set_opacity_ (right + i) (top - j) opacity transparency_map map_width --frame=frame
        set_opacity_ (left - i) (bottom + j) opacity transparency_map map_width --frame=frame
        set_opacity_ (right + i) (bottom + j) opacity transparency_map map_width --frame=frame

/** A rectangular window with rounded corners and a drop shadow  */
abstract class DropShadowWindow_ extends RoundedCornerWindow_:
  blur_radius := 0
  drop_distance_x := 0
  drop_distance_y := 0

  constructor x y w h transform corner_radius .blur_radius .drop_distance_x .drop_distance_y:
    if not 0 <= blur_radius <= 6: throw "OUT_OF_RANGE"
    extension_left := blur_radius > drop_distance_x ?  blur_radius - drop_distance_x : 0
    extension_top := blur_radius > drop_distance_y ?  blur_radius - drop_distance_y : 0
    extension_right := blur_radius > -drop_distance_x ? blur_radius + drop_distance_x : 0
    extension_bottom := blur_radius > -drop_distance_y ? blur_radius + drop_distance_y : 0
    super.protected_
      x
      y
      w
      h
      x - extension_left
      y - extension_top
      w + extension_left + extension_right
      h + extension_top + extension_bottom
      transform
      corner_radius

  frame_map canvas/AbstractCanvas:
    win_x := canvas.x_offset_
    win_y := canvas.y_offset_

    // Transform inner dimensions excluding shadow to determine if the canvas
    // is wholly inside the window.
    transform_.xywh inner_x_ inner_y_ inner_w_ inner_h_: | x y w2 h2 |
      x2 := x - win_x
      y2 := y - win_y
      if x2 + corner_radius_ <= 0 and y2 + corner_radius_ <= 0 and x2 + w2 - corner_radius_ >= canvas.width_ and y2 + h2 - corner_radius_ >= canvas.height_:
        // In the middle, the window content is 100% opaque and draw on top of the
        // frame.  There is no need to provide a frame alpha map, so for efficiency we
        // just return 0 which indicates the frame is 100% transparent.
        return WindowTexture_.ALL_TRANSPARENT

    // Transform outer dimensions including border to determine if the canvas
    // is wholly outside the window and its shadow.
    transform_.xywh x_ y_ w_ h_: | x y w2 h2 |
      x2 := x - win_x
      y2 := y - win_y
      if x2 + w2 <= 0 or y2 + h2 <= 0 or x2 >= canvas.width_ or y2 >= canvas.height_:
        return WindowTexture_.ALL_TRANSPARENT  // The frame is not opaque outside the shadow

    // Create a bitmap to describe the frame's extent.  It needs to be padded
    // relative to the canvas size so we can use the Gaussian blur.
    transparency_map := make_alpha_map_ canvas blur_radius * 2
    map_width := canvas.width_ + blur_radius * 2

    transform_.xywh (inner_x_ + drop_distance_x) (inner_y_ + drop_distance_y) inner_w_ inner_h_: | x y w2 h2 |
      x2 := x + blur_radius - win_x
      y2 := y + blur_radius - win_y

      // Transform the unblurred dimensions of the shadow so we can plot that on the
      // transparency map.
      draw_rounded_corners_ transparency_map map_width x2 y2 w2 h2 --frame=true

    if blur_radius == 0: return transparency_map

    // Blur the shadow.
    bytemap_blur transparency_map map_width blur_radius

    // Crop off the extra that was added to blur.
    transparency_map_unpadded := make_alpha_map_ canvas 0
    canvas.height_.repeat:
      source_index := (it + blur_radius) * map_width + blur_radius
      transparency_map_unpadded.replace (it*canvas.width_) transparency_map source_index source_index + canvas.width_
    return transparency_map_unpadded
