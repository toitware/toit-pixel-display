// Copyright (C) 2019 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import expect show *

import pixel_display.texture show *

main:
  simple_texture_test

simple_texture_test:
  id := Transform.identity
  expect_equals 42 (id.x 42 103)
  expect_equals 103 (id.y 42 103)
  expect_equals 42 (id.width 42 103)
  expect_equals 103 (id.height 42 103)

  r90 := id.rotate_left
  expect_equals 103 (r90.x 42 103)
  expect_equals -42 (r90.y 42 103)
  expect_equals 103 (r90.width 42 103)
  expect_equals -42 (r90.height 42 103)

  r180 := r90.rotate_left
  expect_equals -42 (r180.x 42 103)
  expect_equals -103 (r180.y 42 103)
  expect_equals -42 (r180.width 42 103)
  expect_equals -103 (r180.height 42 103)

  r270 := r180.rotate_left
  expect_equals -103 (r270.x 42 103)
  expect_equals 42 (r270.y 42 103)
  expect_equals -103 (r270.width 42 103)
  expect_equals 42 (r270.height 42 103)

  r270b := id.rotate_right
  expect_equals -103 (r270b.x 42 103)
  expect_equals 42 (r270b.y 42 103)
  expect_equals -103 (r270b.width 42 103)
  expect_equals 42 (r270b.height 42 103)

  idb := r90.apply r270
  expect_equals 42 (idb.x 42 103)
  expect_equals 103 (idb.y 42 103)
  expect_equals 42 (idb.width 42 103)
  expect_equals 103 (idb.height 42 103)

  idc := r180.apply r180
  expect_equals 42 (idc.x 42 103)
  expect_equals 103 (idc.y 42 103)
  expect_equals 42 (idc.width 42 103)
  expect_equals 103 (idc.height 42 103)

  x10 := id.translate 10 0
  x10l := x10.rotate_left
  expect_equals 113 (x10l.x 42 103)
  expect_equals -42 (x10l.y 42 103)
  expect_equals 103 (x10l.width 42 103)
  expect_equals -42 (x10l.height 42 103)
