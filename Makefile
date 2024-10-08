# Copyright (C) 2023 Toitware ApS.
# Use of this source code is governed by a Zero-Clause BSD license that can
# be found in the tests/LICENSE file.

all: test

.PHONY: build/host/CMakeCache.txt
build/CMakeCache.txt:
	@$(MAKE) rebuild-cmake

.PHONY: install-pkgs
install-pkgs: rebuild-cmake
	@(cd build && ninja install-pkgs)
	@[ -f tests/toit-png-tools/Makefile ] || \
		(echo "The 'tests/toit-png-tools/' directory doesn't contain a makefile." && \
		 echo "Run 'git submodule update --init' to get the submodule." && \
		 exit 1)
	@(cd tests/toit-png-tools && $(MAKE) rebuild-cmake)
	@(cd tests/toit-png-tools && cmake -DTOITRUN:FILEPATH="$${TOITRUN:-toit.run}" -DTOITPKG:FILEPATH="$${TOITPKG:-toit.pkg}" build)
	@(cd tests/toit-png-tools && $(MAKE) install-pkgs)

test: install-pkgs rebuild-cmake
	@(cd build && ninja check)

# We rebuild the cmake file all the time.
# We use "glob" in the cmakefile, and wouldn't otherwise notice if a new
# file (for example a test) was added or removed.
# It takes <1s on Linux to run cmake, so it doesn't hurt to run it frequently.
rebuild-cmake:
	@mkdir -p build
	@(cd build && cmake .. -G Ninja)

.PHONY: all test rebuild-cmake install-pkgs
