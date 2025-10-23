# Copyright 2020 Free Software Foundation, Inc.
#
# This file is part of GNU Radio
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

########################################################################
# Check if there is C++ code at all
########################################################################
if(NOT sidekiq_sources)
    message(STATUS "No C++ sources... skipping python bindings")
    return()
endif()

########################################################################
# Check for pygccxml
########################################################################
GR_PYTHON_CHECK_MODULE_RAW(
    "pygccxml"
    "import pygccxml"
    PYGCCXML_FOUND
)

include(GrPybind)

########################################################################
# Python Bindings
########################################################################

list(APPEND sidekiq_python_files
    sidekiq_tx_python.cc
    sidekiq_rx_python.cc
    python_bindings.cc
)

# This generates the pybind module target named: sidekiq_python
GR_PYBIND_MAKE_OOT(
    sidekiq          # module name
    ../../..         # root of the OOT
    gr::sidekiq      # C++ namespace
    "${sidekiq_python_files}"
)

# --------------------------------------------------------------------
# Z4-aware linking and runtime lookup (RPATH)
# Assumes top-level already ran: find_package(Sidekiq REQUIRED)
# and set:
#   Sidekiq_LIBRARIES  -> libsidekiq*.so (Z4) or static .a (others)
#   OTHER_LIBS         -> libgpiod on Z4; iio on aarch variants
#   Sidekiq_LIB_DIRS   -> SDK support dir (…/support/<suffix>/usr/lib/epiq)
# --------------------------------------------------------------------

# Link the SDK libs into the python module
if (TARGET sidekiq_python)
  # Prefer having the SDK dir in the link search path at build time (old CMake behavior).
  if (DEFINED Sidekiq_LIB_DIRS AND EXISTS "${Sidekiq_LIB_DIRS}")
    link_directories("${Sidekiq_LIB_DIRS}")
  endif()

  # Link ONLY what the finder exports (avoid pulling system glib/usb, etc.)
  if (DEFINED Sidekiq_LIBRARIES)
    target_link_libraries(sidekiq_python PRIVATE ${Sidekiq_LIBRARIES})
  endif()
  if (DEFINED OTHER_LIBS AND NOT "${OTHER_LIBS}" STREQUAL "")
    target_link_libraries(sidekiq_python PRIVATE ${OTHER_LIBS})
  endif()

  # Encode an RPATH so dlopen() can resolve libsidekiq*.so + libgpiod.so at runtime
  if (DEFINED Sidekiq_LIB_DIRS AND EXISTS "${Sidekiq_LIB_DIRS}")
    set_target_properties(sidekiq_python PROPERTIES
      BUILD_RPATH   "${Sidekiq_LIB_DIRS}:$ORIGIN"
      INSTALL_RPATH "${Sidekiq_LIB_DIRS}:$ORIGIN")
  endif()
endif()

# copy bindings extension for use in QA test module
add_custom_command(TARGET sidekiq_python POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
            ${CMAKE_BINARY_DIR}/test_modules/gnuradio/sidekiq/
)
add_custom_command(TARGET sidekiq_python POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:sidekiq_python>
            ${CMAKE_BINARY_DIR}/test_modules/gnuradio/sidekiq/
)

# Install the module into site-packages
install(TARGETS sidekiq_python
    DESTINATION ${GR_PYTHON_DIR}/gnuradio/sidekiq
    COMPONENT pythonapi
)
