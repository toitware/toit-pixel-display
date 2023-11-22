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
  driver := TrueColorPngVisualizer 240 160 args[0] --outline=0x101010
  display := TrueColorPixelDisplay driver
  display.background = 0x78aac8

  background_gradient := Gradient --angle=180
      --specifiers=[
          GradientSpecifier --color=0x80ddff 10,
          GradientSpecifier --color=0x80ffdd 90,
      ]
  background_gradient_element := GradientElement --x=0 --y=0 --w=240 --h=160 --gradient=background_gradient
  display.add background_gradient_element

  win := RoundedCornerWindowElement --x=30 --y=30 --w=180 --h=100 --corner_radius=15
  display.add win

  gradient := Gradient --angle=0
      --specifiers=[
          GradientSpecifier --color=0xffdd80 10,
          GradientSpecifier --color=0xddff80 90,
      ]
  gradient_element := GradientElement --x=0 --y=0 --w=180 --h=100 --gradient=gradient
  win.add gradient_element

  text := Label --x=90 --y=55 --label="Hello, World!" --font=sans10 --color=0x101040
  win.add text

  display.draw

  text.move_to 120 65

  display.draw

  // Window-relative coordinates.
  text.move_to -10 7

  display.draw

  driver.write_png
