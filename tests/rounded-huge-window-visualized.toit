// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Test huge rounded corners.

import bitmap show *
import font show Font
import pixel-display show *
import pixel-display.gradient show *
import .png-visualizer

main args:
  sans10 := Font.get "sans10"

  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := TrueColorPngVisualizer 240 240 args[0] --outline=0x101010
  display := PixelDisplay.true-color driver
  display.background = 0x78aac8

  background-gradient := GradientBackground --angle=180
      --specifiers=[
          GradientSpecifier --color=0x80ddff 10,
          GradientSpecifier --color=0x80ffdd 90,
      ]
  background-gradient-element := Div --x=0 --y=0 --w=240 --h=240 --background=background-gradient
  display.add background-gradient-element

  win := Div.clipping --x=30 --y=30 --w=180 --h=180 --border=(RoundedCornerBorder --radius=90)
  display.add win

  gradient := GradientBackground --angle=0
      --specifiers=[
          GradientSpecifier --color=0xffdd80 10,
          GradientSpecifier --color=0xddff80 90,
      ]
  gradient-element := Div --x=0 --y=0 --w=180 --h=180 --background=gradient
  win.add gradient-element

  text := Label --x=90 --y=55 --label="Hello, World!" --font=sans10 --color=0x101040
  win.add text

  display.draw

  text.move-to 120 65

  display.draw

  // Window-relative coordinates.
  text.move-to -10 7

  display.draw

  driver.write-png
