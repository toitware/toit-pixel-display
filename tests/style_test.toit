// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *

import pixel-display.common show Canvas
import pixel-display.element show Element
import pixel-display.style show *

/// Test that the examples from style.toit are well-formed.
toit-doc-examples-test:
  style := Style
      --type-map={
          "button": Style --color=0xffffff --background=0x606060,
      }
      --class-map={
          "box": Style --border=(SolidBorder --color=0xff0000 --width=2)
      }
      --id-map={
          "fish": Style --color=0x00ff00,
      }

  style2 := Style
      --class-map={
          "box": Style
              --type-map={
                  "p": Style --color=0xffffff,
              },
      }

  FISH-OR-FOWL-STYLE ::= Style --color=0xffffff --background=0x606060

  style3 := Style
      --class-map={
          "fish": FISH-OR-FOWL-STYLE,
          "fowl": FISH-OR-FOWL-STYLE,
      }

  style4 := Style
      --class-map={
          "fish-or-fowl": Style --color=0xffffff --background=0x606060,
      }

/// Test a literal element tree can be constructed and get-element-by-id can be
///   used to find a named element.
element-tree-test:
  elements := Div [
      Square --id="first-square",
      Square --classes=["fish"],
      ]

  first := elements.get-element-by-id "first-square"
  expect first.id == "first-square"

/// Test that we can use set-styles to distribute the styles to all the
///   elements.
combine-test:
  elements := Div [
      Div --id="special" [
          Square --id="first-square",
          Square --id="second-square" --classes=["fish"],
          ],
      Square --classes=["fish"],
      Square --classes=["fowl"],
      ]

  style := Style
      --class-map={
          "fish": Style --color=0xffffff --background=0x606060,
          "fowl": Style --color=0x123456 --background=0x606060,
      }
      --id-map={
          // The special div gets a different color and its children
          // get a different background if they are squares.
          "special": Style --color=424242 --type-map={
              // Squares inside the special div get a different backgorund.
              "square": Style --background=0xabcdef,
          },
      }

  elements.set-styles [style]

  special := elements.get-element-by-id "special"
  first/Square := elements.get-element-by-id "first-square"
  second/Square := elements.get-element-by-id "second-square"
  expect-equals 0 first.color
  expect-equals 0xffffff second.color
  expect-equals 0xabcdef first.background

/// Test that we can attach an overriding style to a single element.
single-element-style-test:
  first-style := Style --color=0x8090a0 --background=0x403020
  elements := Div [
      Div --id="special" [
          Square --id="first-square" --style=first-style,
          Square --id="second-square",
          ],
      Square --id="third-square",
      Square,
      ]

  style := Style
      --type-map={
          "square": Style --color=0xffffff --background=0x606060,
      }

  elements.set-styles [style]

  expect-equals 0xffffff
      (elements.get-element-by-id "second-square").color
  expect-equals 0x8090a0
      (elements.get-element-by-id "first-square").color

/// Test that we can add custom properties to a style and use them
///   from an element with the same custom property name.
extra-properties-test:
  style := Style
      --type-map={
          "foo-haver": Style { "foo": "bar" },
      }

  elements := Div [
      FooHaver --id="first-foo-haver",
  ]

  elements.set-styles [style]

  expect-equals "bar"
      (elements.get-element-by-id "first-foo-haver").foo

/// A class that stubs out the display methods we don't need
///   for test purposes.
abstract class TestElement extends Element:
  constructor --style/Style?=null --classes/List?=null --id/string?=null children/List?=null:
    super --style=style --classes=classes --id=id children

  invalidate -> none:

  draw canvas/Canvas -> none:
    unreachable

class Square extends TestElement:
  type -> string: return "square"
  color/int := 0
  background := null
  w/int? := null
  h/int? := null

  constructor --style/Style?=null --classes/List?=null --id/string?=null children/List?=null:
    super --style=style --classes=classes --id=id children

  set-attribute_ key/string value -> none:
    if key == "width":
      w = value
    else if key == "height":
      h = value
    else if key == "color":
      color = value
    else if key == "background":
      background = value

class Div extends TestElement:
  type -> string: return "div"
  w/int? := null
  h/int? := null

  constructor --style/Style?=null --classes/List?=null --id/string?=null children/List?=null:
    super --style=style --classes=classes --id=id children

  set-attribute_ key/string value -> none:
    if key == "width":
      w = value
    else if key == "height":
      h = value

class FooHaver extends TestElement:
  type -> string: return "foo-haver"
  foo/string? := null

  w: return 0
  h: return 0

  constructor --style/Style?=null --classes/List?=null --id/string?=null children/List?=null:
    super --style=style --classes=classes --id=id children
  
  set-attribute_ key/string value -> none:
    if key == "foo":
      foo = value

main:
  toit-doc-examples-test
  element-tree-test
  combine-test
  single-element-style-test
  extra-properties-test
