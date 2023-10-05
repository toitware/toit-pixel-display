// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests for TextElement that the change box is smaller when we only
// change part of the text.

import bitmap show *
import expect show *
import font show *
import pixel_display show *
import pixel_display.texture show *
import .png_visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := TrueColorPngVisualizer 192 80 args[0] --outline=0x4040ff
  display := TrueColorPixelDisplay driver
  display.background = 0x808080

  gradient := GradientElement --x=20 --y=10 --angle=0 --w=100 --h=60 --specifiers=[
      GradientSpecifier --color=0xffff00 10,
      GradientSpecifier --color=0xffc000 50,
      GradientSpecifier --color=0x808000 90,
      ]
  display.add gradient

  display.draw

  gradient_2 := GradientElement --x=50 --y=20 --angle=180 --w=100 --h=40 --specifiers=[
      GradientSpecifier --color=0x00ff00 10,
      GradientSpecifier --color=0x00ffc0 50,
      GradientSpecifier --color=0xc0ffff 90,
      ]
  display.add gradient_2

  display.draw

  gradient.angle = 90
  gradient.h = 10
  gradient.w = 30
  gradient_2.angle = 270
  gradient_2.h = 10
  gradient_2.w = 30

  display.draw

  driver.write_png
