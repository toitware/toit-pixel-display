// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests for Label that the change box is smaller when we only
// change part of the text.

import bitmap show *
import expect show *
import font show *
import pixel-display show *
import pixel-display.element show *
import pixel-display.gradient show *
import pixel-display.style show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  WIDTH ::= 192
  HEIGHT ::= 120
  driver := TrueColorPngVisualizer WIDTH HEIGHT args[0] --outline=0x4040ff
  display := PixelDisplay.true-color driver
  display.background = 0x808080

  gradient1 := GradientBackground --angle=120 --specifiers=[
      GradientSpecifier --color=0xffff00 10,
      GradientSpecifier --color=0xffc000 50,
      GradientSpecifier --color=0x808000 90,
      ]

  gradient2 := GradientBackground --angle=120 --specifiers=[
      GradientSpecifier --color=0xe0e0e0 10,
      GradientSpecifier --color=0xffffff 80,
      GradientSpecifier --color=0xc0c0c0 100,
      ]

  gradient3 := GradientBackground --angle=120 --specifiers=[
      GradientSpecifier --color=0x8080ff 10,
      GradientSpecifier --color=0x8080c0 50,
      GradientSpecifier --color=0x808080 90,
      ]

  background := GradientBackground --angle=0 --specifiers=[
      GradientSpecifier --color=0x101010 0,
      GradientSpecifier --color=0x202020 70,
      GradientSpecifier --color=0x404040 100,
      ]

  content := Div --x=0 --y=0 --w=WIDTH --h=HEIGHT --background=background [
      Div.clipping --x=20 --y=20 --w=60 --h=30 --id="div1" --classes=["round"],
      Div.clipping --x=100 --y=20 --w=60 --h=30 --id="div2" --classes=["round"],
      Div.clipping --x=20 --y=70 --w=60 --h=30 --id="div3" --classes=["round"],
      Div.clipping --x=100 --y=70 --w=60 --h=30 --id="div4" --classes=["round"],
      ]

  display.add content

  style := Style
      --id-map={
          "div1": Style --background=gradient1,
          "div2": Style --background=gradient2,
          "div3": Style --background=gradient3,
          "div4": Style --background=gradient1,
      }
      --class-map={
          "round": Style --border=(RoundedCornerBorder --radius=10),
      }

  content.set-styles [style]

  display.draw
  driver.write-png

  content.background = GradientBackground --angle=0 --specifiers=[
      GradientSpecifier --color=0xffffff 0,
      GradientSpecifier --color=0xeeeeee 70,
      GradientSpecifier --color=0xbbbbbb 100,
      ]

  display.draw
  driver.write-png

  shadow-style := Style --class-map={
      "round": Style --border=(ShadowRoundedCornerBorder --radius=10)
  }

  content.set-styles [shadow-style]

  display.draw
  driver.write-png
