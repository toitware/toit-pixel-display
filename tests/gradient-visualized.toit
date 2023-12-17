// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests for Label that the change box is smaller when we only
// change part of the text.

import bitmap show *
import expect show *
import font show *
import pixel-display show *
import pixel-display.gradient show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := TrueColorPngVisualizer 192 80 args[0] --outline=0x4040ff
  display := PixelDisplay.true-color driver
  display.background = 0x808080

  gradient := GradientBackground --angle=0 --specifiers=[
      GradientSpecifier --color=0xffff00 10,
      GradientSpecifier --color=0xffc000 50,
      GradientSpecifier --color=0x808000 90,
      ]
  gradient-element := Div --x=20 --y=10 --w=100 --h=60 --background=gradient
  display.add gradient-element

  display.draw

  gradient-2 := GradientBackground --angle=180 --specifiers=[
      GradientSpecifier --color=0x00ff00 10,
      GradientSpecifier --color=0x00ffc0 50,
      GradientSpecifier --color=0xc0ffff 90,
      ]
  gradient-2-element := Div --x=50 --y=20 --w=100 --h=40 --background=gradient-2
  display.add gradient-2-element

  display.draw

  gradient-element.background = GradientBackground --angle=90 --specifiers=gradient.specifiers
  gradient-element.h = 10
  gradient-element.w = 30
  gradient-2-element.background = GradientBackground --angle=270 --specifiers=gradient-2.specifiers
  gradient-2-element.h = 10
  gradient-2-element.w = 30

  display.draw

  driver.write-png
