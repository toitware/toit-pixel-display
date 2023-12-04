// Copyright (C) 2020 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import bitmap show *
import font show Font
import pixel_display show *
import pixel_display.texture show *
import pixel_display.true_color show *
import .png-visualizer

main args:
  sans10 := Font.get "sans10"

  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := TrueColorPngVisualizer 240 160 args[0] --outline=0x101010
  display := TrueColorPixelDisplay driver
  display.background = get_rgb 120 160 200

  transform := display.landscape

  win := DropShadowWindow 30 30 180 100 transform 0xe0e0ff --corner_radius=10 --blur_radius=6 --drop_distance_x=10 --drop_distance_y=10 --shadow_opacity_percent=30
  display.add win

  text := TextTexture 90 55 transform TEXT_TEXTURE_ALIGN_CENTER "Hello, World!" sans10 0x101010
  win.add text

  display.draw

  text.move_to 100 65

  display.draw

  text.move_to 15 37

  display.draw

  driver.write_png
