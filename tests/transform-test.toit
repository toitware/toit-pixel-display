// Copyright (C) 2019 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *

import pixel-display show *

main:
  simple-texture-test

simple-texture-test:
  id := Transform.identity
  expect-equals 42 (id.x 42 103)
  expect-equals 103 (id.y 42 103)
  expect-equals 42 (id.width 42 103)
  expect-equals 103 (id.height 42 103)

  r90 := id.rotate-left
  expect-equals 103 (r90.x 42 103)
  expect-equals -42 (r90.y 42 103)
  expect-equals 103 (r90.width 42 103)
  expect-equals -42 (r90.height 42 103)
  expect-equals id
      r90.invert.apply r90
  expect-equals id
      r90.apply r90.invert

  r180 := r90.rotate-left
  expect-equals -42 (r180.x 42 103)
  expect-equals -103 (r180.y 42 103)
  expect-equals -42 (r180.width 42 103)
  expect-equals -103 (r180.height 42 103)
  expect-equals id
      r180.invert.apply r180
  expect-equals id
      r180.apply r180.invert

  r270 := r180.rotate-left
  expect-equals -103 (r270.x 42 103)
  expect-equals 42 (r270.y 42 103)
  expect-equals -103 (r270.width 42 103)
  expect-equals 42 (r270.height 42 103)
  expect-equals id
      r270.invert.apply r270
  expect-equals id
      r270.apply r270.invert

  r270b := id.rotate-right
  expect-equals -103 (r270b.x 42 103)
  expect-equals 42 (r270b.y 42 103)
  expect-equals -103 (r270b.width 42 103)
  expect-equals 42 (r270b.height 42 103)

  idb := r90.apply r270
  expect-equals 42 (idb.x 42 103)
  expect-equals 103 (idb.y 42 103)
  expect-equals 42 (idb.width 42 103)
  expect-equals 103 (idb.height 42 103)

  idc := r180.apply r180
  expect-equals 42 (idc.x 42 103)
  expect-equals 103 (idc.y 42 103)
  expect-equals 42 (idc.width 42 103)
  expect-equals 103 (idc.height 42 103)

  x10 := id.translate 10 0
  x10l := x10.rotate-left
  expect-equals 113 (x10l.x 42 103)
  expect-equals -42 (x10l.y 42 103)
  expect-equals 103 (x10l.width 42 103)
  expect-equals -42 (x10l.height 42 103)
  expect-equals id
      x10.invert.apply x10
  expect-equals id
      x10.apply x10.invert
  expect-equals id
      x10l.invert.apply x10l
  expect-equals id
      x10l.apply x10l.invert
