# Copyright (C) 2023 Toitware ApS.
# Use of this source code is governed by a Zero-Clause BSD license that can
# be found in the tests/TESTS_LICENSE file.

cmake_minimum_required(VERSION 3.22)

# NONE means skip testing the C compiler.
project(pixel_display NONE)

enable_testing()
add_subdirectory(tests)
