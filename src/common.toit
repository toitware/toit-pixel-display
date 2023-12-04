// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Common things between textures and elements.

import font show Font
import bitmap show ORIENTATION_0 ORIENTATION_90 ORIENTATION_180 ORIENTATION_270

import .texture show Transform
import .style

/**
A display or a window within a display.
You can add and remove texture objects to a Window.  They will be drawn
  in the order they were added, where the first textures are at the back
  and are overwritten by textures added later.
*/
interface Window:
  add element /ElementOrTexture_ -> none
  remove element /ElementOrTexture_ -> none
  remove_all -> none

  // Called by elements that have been added to this.
  child_invalidated x/int y/int w/int h/int ->none

  // Called by elements that have been added to this.
  child_invalidated_element x/int y/int w/int h/int ->none

/**
Something you can draw on a canvas.  It could be a text string, a pixmap or
  a geometric figure. They can be stacked up and will be drawn from back to
  front, with transparency.
*/
abstract class ElementOrTexture_:
  hash_code /int ::= random 0 0x10000000
  change_tracker /Window? := null

  /**
  Writes the image data to a canvas window.
  $canvas: Some sort of canvas.  The precise type depends on the depth of the display.
  */
  write canvas/Canvas -> none:
    write_ canvas

  abstract write_ canvas

  abstract invalidate -> none

abstract class Canvas:
  width_ / int                    // Used by both Textures and Elements.
  height_ / int                   // Only used by Textures.
  x_offset_ / int := 0            // Only used by Textures.
  y_offset_ / int := 0            // Only used by Textures.
  transform / Transform? := null  // Only used by Elements.

  constructor .width_ .height_:

  abstract create_similar -> Canvas

  abstract set_all_pixels color/int -> none

  abstract supports_8_bit -> bool
  abstract gray_scale -> bool

  abstract make_alpha_map -> Canvas
  abstract make_alpha_map --padding/int -> Canvas

  /*
  A, C disjoint or one of them is empty 0
  A subset of C, A not empty            1
  C subset of A, C not empty            2
  A identical to C and non-empty        3
  */

  static DISJOINT           ::= 0  // The area and the canvas are disjoint.
  static AREA_IN_CANVAS     ::= 1  // The area is a subset of the canvas.
  static CANVAS_IN_AREA     ::= 2  // The canvas is a subset of the area.
  static COINCIDENT         ::= 3  // The area and the canvas are identical.
  static OVERLAP            ::= 4  // The areas overlap, but neither is a subset of the other.

  bounds_analysis x/int y/int w/int h/int -> int:
    if h == 0 or w == 0 or width_ == 0 or height_ == 0: return DISJOINT
    transform.xywh x y w h: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if right < 0 or bottom < 0 or x2 >= width_ or y2 >= height_: return DISJOINT
      if x2 >= 0 and y2 >= 0 and right <= width_ and bottom <= height_:
        if x2 == 0 and y2 == 0 and right == width_ and bottom == height_: return COINCIDENT
        return AREA_IN_CANVAS
      if x2 <= 0 and y2 <= 0 and right >= width_ and bottom >= height_: return CANVAS_IN_AREA
    return OVERLAP

  abstract composit frame_opacity frame_canvas/Canvas painting_opacity painting_canvas/Canvas
