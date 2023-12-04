// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .common
import .element as element

ALIGN_LEFT ::= 0
ALIGN_CENTER ::= 1
ALIGN_RIGHT ::= 2

class Style:
  iterate_properties [block] -> none:
    unreachable  // Unimplemented.

  matching_styles --type/string?=null --classes/List?=null --id/string?=null [block] -> none:
    unreachable  // Unimplemented.

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
