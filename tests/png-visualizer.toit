// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import binary show BIG_ENDIAN byte_swap_32
import bitmap show *
import bytes show Buffer
import crypto.crc show *
import host.file
import monitor show Latch
import pixel_display show *
import zlib

class TwoColorPngVisualizer extends PngVisualizingDriver_:
  flags ::= FLAG_2_COLOR | FLAG_PARTIAL_UPDATES
  constructor width height basename --outline/int?=null: super width height basename --outline=outline
  width_to_byte_width w: return (round_up w 8) >> 3

class ThreeColorPngVisualizer extends PngVisualizingDriver_:
  flags ::= FLAG_3_COLOR | FLAG_PARTIAL_UPDATES
  constructor width height basename --outline/int?=null: super width height basename --outline=outline
  width_to_byte_width w: return (round_up w 4) >> 2

class FourGrayPngVisualizer extends PngVisualizingDriver_:
  flags ::= FLAG_4_COLOR | FLAG_PARTIAL_UPDATES
  constructor width height basename --outline/int?=null: super width height basename --outline=outline
  width_to_byte_width w: return (round_up w 4) >> 2

class TrueColorPngVisualizer extends PngVisualizingDriver_:
  flags ::= FLAG_TRUE_COLOR | FLAG_PARTIAL_UPDATES
  constructor width height basename --outline/int?=null: super width height basename --outline=outline
  width_to_byte_width w: return w * 3

class GrayScalePngVisualizer extends PngVisualizingDriver_:
  flags ::= FLAG_GRAY_SCALE | FLAG_PARTIAL_UPDATES
  constructor width height basename --outline/int?=null: super width height basename --outline=outline
  width_to_byte_width w: return w

class SeveralColorPngVisualizer extends PngVisualizingDriver_:
  flags ::= FLAG_SEVERAL_COLOR | FLAG_PARTIAL_UPDATES
  constructor width height basename --outline/int?=null: super width height basename --outline=outline
  width_to_byte_width w: return w

abstract class PngVisualizingDriver_ extends AbstractDriver:
  width /int ::= ?
  height /int ::= ?
  width_ /int ::= ?  // Rounded up to a multiple of 8.
  height_ /int ::= ?  // Rounded up to a multiple of 8.
  outline_buffer_ /ByteArray? := null
  buffer_ /ByteArray := #[]
  temp_buffer_/ByteArray := #[]
  temps_ := List 8
  // Optional outliner to see update locations.
  outline/int? := null
  // How many bytes make up one strip of image data.
  abstract width_to_byte_width w/int -> int

  static INVERT_ := ByteArray 0x100: 0xff - it

  constructor .width .height basename/string --.outline/int?=null:
    width_ = round_up width 8
    height_ = round_up height 8
    png_basename_ = basename
    buffer_ = ByteArray
        (width_to_byte_width width_) * height_
    if outline:
      outline_buffer_ = buffer_.copy

  draw_true_color left/int top/int right/int bottom/int red/ByteArray green/ByteArray blue/ByteArray -> none:
    patch_width := right - left
    top_left := min buffer_.size (3 * (left + width_ * top))

    if outline:
      red2 := red.copy
      green2 := green.copy
      blue2 := blue.copy
      draw_byte_outline_ (outline >> 16) red2 patch_width
      draw_byte_outline_ ((outline >> 16) & 0xff) green2 patch_width
      draw_byte_outline_ (outline & 0xff) blue2 patch_width

      // Pack 3 pixels in three consecutive bytes.  Since we receive the data in
      // three one-byte-per-pixel buffers we have to shuffle the bytes.
      blit red2   outline_buffer_[top_left..]     patch_width --destination_pixel_stride=3 --destination_line_stride=(width_ * 3)
      blit green2 outline_buffer_[top_left + 1..] patch_width --destination_pixel_stride=3 --destination_line_stride=(width_ * 3)
      blit blue2  outline_buffer_[top_left + 2..] patch_width --destination_pixel_stride=3 --destination_line_stride=(width_ * 3)

    // Pack 3 pixels in three consecutive bytes.  Since we receive the data in
    // three one-byte-per-pixel buffers we have to shuffle the bytes.
    blit red   buffer_[top_left..]     patch_width --destination_pixel_stride=3 --destination_line_stride=(width_ * 3)
    blit green buffer_[top_left + 1..] patch_width --destination_pixel_stride=3 --destination_line_stride=(width_ * 3)
    blit blue  buffer_[top_left + 2..] patch_width --destination_pixel_stride=3 --destination_line_stride=(width_ * 3)

  draw_gray_scale left/int top/int right/int bottom/int pixels/ByteArray -> none:
    patch_width := right - left
    top_left := min buffer_.size (left + width_ * top)
    if outline:
      pixels2 := pixels.copy
      draw_byte_outline_ outline pixels2 patch_width

      blit pixels2 outline_buffer_[top_left..] patch_width --destination_line_stride=width_

    blit pixels buffer_[top_left..] patch_width --destination_line_stride=width_

  draw_several_color left/int top/int right/int bottom/int pixels/ByteArray -> none:
    draw_gray_scale left top right bottom pixels

  draw_two_color left/int top/int right/int bottom/int pixels/ByteArray -> none:
    if outline:
      patch_width := right - left
      pixels2 := pixels.copy
      draw_bit_outline_ outline pixels2 patch_width
      write_png_two_color outline_buffer_ left top right bottom pixels2

    write_png_two_color buffer_ left top right bottom pixels

  write_png_two_color buffer/ByteArray left/int top/int right/int bottom/int pixels/ByteArray -> none:
    if temp_buffer_.size < pixels.size:
      temp_buffer_ = ByteArray pixels.size
    8.repeat:
      temps_[it] = temp_buffer_[it..pixels.size]

    assert: left == (round_up left 8)
    assert: top == (round_up top 8)
    assert: right == (round_up right 8)
    assert: bottom == (round_up bottom 8)

    patch_width := right - left
    patch_height := bottom - top

    // Writes the patch to the buffer.  The patch is arranged as height/8
    // strips of width bytes, where each byte represents 8 vertically stacked
    // pixels, lsbit at the top.  PNG requires these be transposed so that each
    // line is represented by consecutive bytes, from top to bottom, msbit on
    // the left.

    pixels_0 := pixels[0..]
    pixels_1 := pixels[1..]
    pixels_2 := pixels[2..]
    pixels_4 := pixels[4..]

    // We start by reflecting each 8x8 block.
    // Reflect each 2x2 pixel block.
    blit pixels_0 temps_[0] patch_width/2 --source_pixel_stride=2 --destination_pixel_stride=2 --mask=0xaa
    blit pixels_1 temps_[1] patch_width/2 --source_pixel_stride=2 --destination_pixel_stride=2 --mask=0x55
    blit pixels_0 temps_[1] patch_width/2 --source_pixel_stride=2 --destination_pixel_stride=2 --shift=-1 --mask=0xaa --operation=OR
    blit pixels_1 temps_[0] patch_width/2 --source_pixel_stride=2 --destination_pixel_stride=2 --shift=1 --mask=0x55 --operation=OR
    // Reflect each 4x4 pixel block.  Blit is treating each 4x8 block as a line for this operation.
    blit temps_[0] pixels_0 2 --source_line_stride=4 --destination_line_stride=4 --mask=0xcc
    blit temps_[2] pixels_2 2 --source_line_stride=4 --destination_line_stride=4 --mask=0x33
    blit temps_[0] pixels_2 2 --source_line_stride=4 --destination_line_stride=4 --shift=-2 --mask=0xcc --operation=OR
    blit temps_[2] pixels_0 2 --source_line_stride=4 --destination_line_stride=4 --shift=2 --mask=0x33 --operation=OR
    // Reflect each 8x8 pixel block.  Blit is treating each 8x8 block as a line for this operation.
    blit pixels_0 temps_[0] 4 --source_line_stride=8 --destination_line_stride=8 --mask=0xf0
    blit pixels_4 temps_[4] 4 --source_line_stride=8 --destination_line_stride=8 --mask=0x0f
    blit pixels_0 temps_[4] 4 --source_line_stride=8 --destination_line_stride=8 --shift=-4 --mask=0xf0 --operation=OR
    blit pixels_4 temps_[0] 4 --source_line_stride=8 --destination_line_stride=8 --shift=4 --mask=0x0f --operation=OR

    // Now we need to spread the 8x8 blocks out over the lines they belong on.
    // First line is bytes 0, 8, 16..., next line is bytes 1, 9, 17... etc.
    8.repeat:
      index := left + (width_ * (top + 7 - it)) >> 3
      blit temps_[it] buffer[index..] (patch_width >> 3) --source_pixel_stride=8 --destination_line_stride=width_ --lookup_table=INVERT_

  draw_bit_outline_ outline/int pixels/ByteArray patch_width/int -> none:
    bottom_left := pixels.size - patch_width
    // Dotted line along top and bottom.
    for x := 0; x < patch_width; x += 2:
      if outline == 0:
        pixels[x] &= ~1
        pixels[bottom_left + x] &= ~0x80
      else:
        pixels[x] |= 1
        pixels[bottom_left + x] |= 0x80
    // Dotted line along left and right.
    for y := 0; y < pixels.size; y += patch_width:
      if outline == 0:
        pixels[y] &= ~0b01010101
        pixels[y + patch_width - 1] &= ~0b01010101
      else:
        pixels[y] |= 0b01010101
        pixels[y + patch_width - 1] |= 0b01010101

  draw_byte_outline_ outline/int pixels/ByteArray patch_width/int -> none:
    bottom_left := pixels.size - patch_width
    // Dotted line along top and bottom.
    for x := 0; x < patch_width; x += 2:
      pixels[x] = outline
      pixels[bottom_left + x] = outline
    // Dotted line along left and right.
    for y := 0; y < pixels.size; y += patch_width * 2:
      pixels[y] = outline
      pixels[y + patch_width - 1] = outline

  draw_two_bit left/int top/int right/int bottom/int plane_0/ByteArray plane_1/ByteArray -> none:
    if outline:
      patch_width := right - left
      plane_0_2 := plane_0.copy
      plane_1_2 := plane_1.copy
      draw_bit_outline_ (outline & 1) plane_0_2 patch_width
      draw_bit_outline_ (outline >> 1) plane_1_2 patch_width
      write_png_two_bit outline_buffer_ left top right bottom plane_0_2 plane_1_2
    write_png_two_bit buffer_ left top right bottom plane_0 plane_1

  write_png_two_bit buffer/ByteArray left/int top/int right/int bottom/int plane_0/ByteArray plane_1/ByteArray -> none:
    patch_width := right - left
    assert: patch_width == (round_up patch_width 8)
    patch_height := bottom - top
    assert: patch_height == (round_up patch_height 8)

    byte_width := width_to_byte_width width_

    // Writes part of the patch to the compressor.  The patch is arranged as
    // height/8 strips of width bytes, where each byte represents 8 vertically
    // stacked pixels.  PNG requires these be transposed so that each
    // line is represented by consecutive bytes, from top to bottom, msbit on
    // the left.
    // This implementation is not as optimized as the two-color version.
    row := 0
    ppb := 4  // Pixels per byte.
    for y := 0; y < patch_height; y += 8:
      for in_bit := 0; in_bit < 8 and y + top + in_bit < height; in_bit++:
        out_index := (left >> 2) + (top + y + in_bit) * byte_width
        for x := 0; x < patch_width; x += ppb:
          out := 0
          byte_pos := row + x + ppb - 1
          for out_bit := ppb - 1; out_bit >= 0; out_bit--:
            out |= ((plane_0[byte_pos - out_bit] >> in_bit) & 1) << (out_bit * 2)
            out |= ((plane_1[byte_pos - out_bit] >> in_bit) & 1) << (out_bit * 2 + 1)
          buffer[out_index + (width_to_byte_width x)] = out
      row += patch_width

  png_counter := 0
  png_basename_/string

  static HEADER ::= #[0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n']

  static write_chunk stream name/string data/ByteArray -> none:
    length := ByteArray 4
    if name.size != 4: throw "invalid name"
    BIG_ENDIAN.put_uint32 length 0 data.size
    write_ stream length
    write_ stream name
    write_ stream data
    crc := Crc32
    crc.add name
    crc.add data
    write_ stream
      byte_swap_
        crc.get

  static write_ stream byte_array -> none:
    done := 0
    while done != byte_array.size:
      done += stream.write byte_array[done..]

  commit left/int top/int right/int bottom/int -> none:
    if outline:
      write_png outline_buffer_
      outline_buffer_.replace 0 buffer_
    write_png buffer_

  write_png buffer/ByteArray -> none:
    true_color := flags & FLAG_TRUE_COLOR != 0
    gray := flags & FLAG_4_COLOR != 0
    three_color := flags & FLAG_3_COLOR != 0
    gray_scale := flags & FLAG_GRAY_SCALE != 0
    several_color := flags & FLAG_SEVERAL_COLOR != 0

    writeable := file.Stream.for_write "$png_basename_-$(%06d png_counter++).png"

    write_ writeable HEADER

    bits_per_pixel := ?
    color_type := ?
    if true_color:
      bits_per_pixel = 8
      color_type = 2  // True color.
    else if gray_scale:
      bits_per_pixel = 8
      color_type = 0  // Gray scale.
    else if three_color:
      bits_per_pixel = 2
      color_type = 3  // Palette.
    else if several_color:
      bits_per_pixel = 8
      color_type = 3  // Palette.
    else if gray:
      bits_per_pixel = 2
      color_type = 0  // Grayscale.
    else:
      bits_per_pixel = 1
      color_type = 0  // Grayscale

    ihdr := #[
      0, 0, 0, 0,          // Width.
      0, 0, 0, 0,          // Height.
      bits_per_pixel,
      color_type,
      0, 0, 0,
    ]
    BIG_ENDIAN.put_uint32 ihdr 0 width
    BIG_ENDIAN.put_uint32 ihdr 4 height
    write_chunk writeable "IHDR" ihdr

    if three_color:
      write_chunk writeable "PLTE" #[  // Palette.
          0xff, 0xff, 0xff,         // 0 is white.
          0, 0, 0,                  // 1 is black.
          0xff, 0, 0,               // 2 is red.
        ]
    else if several_color:
      // Use color palette of 7-color epaper display.
      write_chunk writeable "PLTE" #[  // Palette.
          0xff, 0xff, 0xff,         // 0 is white.
          0, 0, 0,                  // 1 is black.
          0xff, 0, 0,               // 2 is red.
          0, 0xff, 0,               // 3 is green.
          0, 0, 0xff,               // 4 is blue.
          0xff, 0xff, 0,            // 5 is yellow.
          0xff, 0xc0, 0,            // 6 is orange.
          // The next three are not available on the 7-color e-paper display.
          0x40, 0x40, 0x40,         // 7 is dark gray.
          0x80, 0x80, 0x80,         // 8 is gray.
          0xc0, 0xc0, 0xc0,         // 9 is light gray.
        ]

    compressor := zlib.RunLengthZlibEncoder
    done := Latch
    compressed := Buffer

    task::
      while data := compressor.reader.read:
        compressed.write data
      done.set null

    zero_byte := #[0]
    line_size := width_to_byte_width width
    line_step := width_to_byte_width width_
    height.repeat: | y |
      compressor.write zero_byte  // Adaptive scheme.
      index := y * line_step
      line := buffer[index..index + line_size]
      if gray:
        line = ByteArray line.size: line[it] ^ 0xff
      else if several_color:
        line = ByteArray line.size: min SEVERAL_MAX_COLOR_ line[it]
      compressor.write line

    compressor.close

    // Wait for the reader task to finish.
    done.get

    if compressed.size != 0:
      write_chunk writeable "IDAT" compressed.bytes  // Compressed pixel data.

    write_chunk writeable "IEND" #[]  // End chunk.

    writeable.close

SEVERAL_WHITE ::= 0
SEVERAL_BLACK ::= 1
SEVERAL_RED ::= 2
SEVERAL_GREEN ::= 3
SEVERAL_BLUE ::= 4
SEVERAL_YELLOW ::= 5
SEVERAL_ORANGE ::= 6
SEVERAL_DARK_GRAY ::= 7
SEVERAL_GRAY ::= 8
SEVERAL_LIGHT_GRAY ::= 9
SEVERAL_MAX_COLOR_ ::= 9

byte_swap_ ba/ByteArray -> ByteArray:
  result := ba.copy
  byte_swap_32 result
  return result
