// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests for Label that the change box is smaller when we only
// change part of the text.

import bitmap show *
import expect show *
import font show *
import pixel_display show *
import pixel_display.element show *
import pixel_display.gradient show *
import .png_visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := TrueColorPngVisualizer 192 80 args[0] --outline=0x4040ff
  display := PixelDisplay.true_color driver
  display.background = 0x808080

  gradient := GradientBackground --angle=0 --specifiers=[
      GradientSpecifier --color=0xffff00 10,
      GradientSpecifier --color=0xffc000 50,
      GradientSpecifier --color=0x808000 90,
      ]
  gradient_element := Div --x=20 --y=10 --w=100 --h=60 --background=gradient
  display.add gradient_element

  display.draw

  gradient_2 := GradientBackground --angle=180 --specifiers=[
      GradientSpecifier --color=0x00ff00 10,
      GradientSpecifier --color=0x00ffc0 50,
      GradientSpecifier --color=0xc0ffff 90,
      ]
  gradient_2_element := Div --x=50 --y=20 --w=100 --h=40 --background=gradient_2
  display.add gradient_2_element

  display.draw

  gradient_element.background = GradientBackground --angle=90 --specifiers=gradient.specifiers
  gradient_element.h = 10
  gradient_element.w = 30
  gradient_2_element.background = GradientBackground --angle=270 --specifiers=gradient_2.specifiers
  gradient_2_element.h = 10
  gradient_2_element.w = 30

  display.draw

  driver.write_png
