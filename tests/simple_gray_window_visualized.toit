// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import bitmap show *
import font show Font
import pixel_display show *
import pixel_display.element show *
import .png_visualizer

main args:
  sans10 := Font.get "sans10"

  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := GrayScalePngVisualizer 240 160 args[0] --outline=0x10
  display := GrayScalePixelDisplay driver
  display.background = 160

  background_gradient := GradientElement --x=0 --y=0 --w=240 --h=160 --angle=180
      --specifiers=[
          GradientSpecifier --color=0x20 10,
          GradientSpecifier --color=0x60 90,
      ]
  display.add background_gradient

  win := SimpleWindowElement --x=30 --y=30 --w=180 --h=100 --border_width=0
  display.add win

  gradient := GradientElement --x=0 --y=0 --w=180 --h=100 --angle=0
      --specifiers=[
          GradientSpecifier --color=0x90 10,
          GradientSpecifier --color=0xe0 90,
      ]
  win.add gradient

  text := Label --x=90 --y=55 --label="Hello, World!" --font=sans10 --color=0x10
  win.add text

  display.draw

  text.move_to 120 65

  display.draw

  // Window-relative coordinates.
  text.move_to -10 7

  display.draw

  driver.write_png
