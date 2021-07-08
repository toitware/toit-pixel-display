// Copyright (C) 2020 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import bitmap show *
import pixel_display.texture show *
import pixel_display.true_color show *

main:
  error := catch:
    ba := ByteArray 25
    bytemap_blur ba 5 2
  if error == "UNIMPLEMENTED":
    // Not all builds have the byte display primitives for true color displays.
    return
  else if error:
    throw error

  canvas := Canvas 64 48
  tr := Transform.identity
  window := DropShadowWindow 30 20 140 100 tr (get_rgb 255 255 153) --corner_radius=7 --blur_radius=4 --drop_distance_x=-10 --drop_distance_y=-10
  canvas.set_all_pixels (get_rgb 23 200 230)
  window.write 0 0 canvas
  48.repeat: | y |
    line := ""
    64.repeat: | x |
      pixel := canvas.get_pixel x y
      line += "$(%3d red_component pixel) $(%3d green_component pixel) $(%3d blue_component pixel)   ";
