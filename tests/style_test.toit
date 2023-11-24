// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *

import pixel_display.common show Canvas
import pixel_display.element show Element
import pixel_display.style show *

/// Test that the examples from style.toit are well-formed.
toit_doc_examples_test:
  style := Style
      --type_map={
          "button": Style --color=0xffffff --background=0x606060,
      }
      --class_map={
          "box": Style --border_color=0xff0000,
      }
      --id_map={
          "fish": Style --color=0x00ff00,
      }

  style2 := Style
      --class_map={
          "box": Style
              --type_map={
                  "p": Style --color=0xffffff,
              },
      }

  FISH_OR_FOWL_STYLE ::= Style --color=0xffffff --background=0x606060

  style3 := Style
      --class_map={
          "fish": FISH_OR_FOWL_STYLE,
          "fowl": FISH_OR_FOWL_STYLE,
      }

  style4 := Style
      --class_map={
          "fish-or-fowl": Style --color=0xffffff --background=0x606060,
      }

/// Test a literal element tree can be constructed and get_element_by_id can be
///   used to find a named element.
element_tree_test:
  elements := Div [
      Square --id="first-square",
      Square --element_class="fish",
      ]

  first := elements.get_element_by_id "first-square"
  expect first.id == "first-square"

/// Test that we can use set_styles to distribute the styles to all the
///   elements.
combine_test:
  elements := Div [
      Div --id="special" [
          Square --id="first-square",
          Square --id="second-square" --element_class="fish",
          ],
      Square --element_class="fish",
      Square --element_class="fowl",
      ]

  style := Style
      --class_map={
          "fish": Style --color=0xffffff --background=0x606060,
          "fowl": Style --color=0x123456 --background=0x606060,
      }
      --id_map={
          // The special div gets a different color and its children
          // get a different background if they are squares.
          "special": Style --color=424242 --type_map={
              // Squares inside the special div get a different backgorund.
              "square": Style --background=0xabcdef,
          },
      }

  elements.set_styles [style]

  special := elements.get_element_by_id "special"
  first/Square := elements.get_element_by_id "first-square"
  second/Square := elements.get_element_by_id "second-square"
  expect_equals 0 first.color
  expect_equals 0xffffff second.color
  expect_equals [0xabcdef] first.background

/// Test that we can attach an overriding style to a single element.
single_element_style_test:
  first_style := Style --color=0x8090a0 --background=0x403020
  elements := Div [
      Div --id="special" [
          Square --id="first-square" --style=first_style,
          Square --id="second-square",
          ],
      Square --id="third-square",
      Square,
      ]

  style := Style
      --type_map={
          "square": Style --color=0xffffff --background=0x606060,
      }

  elements.set_styles [style]

  expect_equals 0xffffff
      (elements.get_element_by_id "second-square").color
  expect_equals 0x8090a0
      (elements.get_element_by_id "first-square").color

/// Test that we can add custom properties to a style and use them
///   from an element with the same custom property name.
extra_properties_test:
  style := Style
      --type_map={
          "foo-haver": Style { "foo": "bar" },
      }

  elements := Div [
      FooHaver --id="first-foo-haver",
  ]

  elements.set_styles [style]

  expect-equals "bar"
      (elements.get_element_by_id "first-foo-haver").foo

/// A class that stubs out the display methods we don't need
///   for test purposes.
abstract class TestElement extends Element:
  constructor --style/Style?=null --element_class/string?=null --classes/List?=null --id/string?=null children/List?=null:
    super --style=style --element_class=element_class --classes=classes --id=id children

  invalidate -> none:
    unreachable

  draw canvas/Canvas -> none:
    unreachable

  min_w -> int:
    unreachable

  min_h -> int:
    unreachable

class Square extends TestElement:
  type -> string: return "square"
  color/int := 0
  background/List? := null
  w/int? := null
  h/int? := null

  constructor --style/Style?=null --element_class/string?=null --classes/List?=null --id/string?=null children/List?=null:
    super --style=style --element_class=element_class --classes=classes --id=id children

  set_attribute key/string value -> none:
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

  constructor --style/Style?=null --element_class/string?=null --classes/List?=null --id/string?=null children/List?=null:
    super --style=style --element_class=element_class --classes=classes --id=id children

  set_attribute key/string value -> none:
    if key == "width":
      w = value
    else if key == "height":
      h = value

class FooHaver extends TestElement:
  type -> string: return "foo-haver"
  foo/string? := null

  constructor --style/Style?=null --element_class/string?=null --classes/List?=null --id/string?=null children/List?=null:
    super --style=style --element_class=element_class --classes=classes --id=id children
  
  set_attribute key/string value -> none:
    if key == "foo":
      foo = value

main:
  toit_doc_examples_test
  element_tree_test
  combine_test
  single_element_style_test
  extra_properties_test
