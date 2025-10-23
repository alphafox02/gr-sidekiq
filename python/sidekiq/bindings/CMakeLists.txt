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
    MESSAGE(STATUS "No C++ sources... skipping python bindings")
    return()
endif(NOT sidekiq_sources)

########################################################################
# Check for pygccxml
########################################################################
GR_PYTHON_CHECK_MODULE_RAW(
    "pygccxml"
    "import pygccxml"
    PYGCCXML_FOUND
)

include(GrPybind)
include(GNUInstallDirs)  # for CMAKE_INSTALL_FULL_LIBDIR

########################################################################
# Python Bindings
########################################################################

list(APPEND sidekiq_python_files
    sidekiq_tx_python.cc
    sidekiq_rx_python.cc
    python_bindings.cc
)

# Generates target: sidekiq_python
GR_PYBIND_MAKE_OOT(
    sidekiq
    ../../..
    gr::sidekiq
    "${sidekiq_python_files}"
)

# Z4-aware linking and runtime lookup:
#   - Link the SDK libs exported by the finder (Sidekiq_LIBRARIES, OTHER_LIBS)
#   - Add RPATHs so this module can find:
#       * SDK libs (libsidekiq*.so, libgpiod.so) in Sidekiq_LIB_DIRS
#       * Core GR lib (libgnuradio-sidekiq.so.*) in install libdir
if (TARGET sidekiq_python)
    # bring in the SDK support dir for link search at build time
    if (DEFINED Sidekiq_LIB_DIRS AND EXISTS "${Sidekiq_LIB_DIRS}")
        link_directories("${Sidekiq_LIB_DIRS}")
    endif()

    if (DEFINED Sidekiq_LIBRARIES AND NOT "${Sidekiq_LIBRARIES}" STREQUAL "")
        target_link_libraries(sidekiq_python PRIVATE ${Sidekiq_LIBRARIES})
    endif()
    if (DEFINED OTHER_LIBS AND NOT "${OTHER_LIBS}" STREQUAL "")
        target_link_libraries(sidekiq_python PRIVATE ${OTHER_LIBS})
    endif()

    # RPATHs: SDK dir + where libgnuradio-sidekiq.so.* installs + $ORIGIN
    set(_SDK_DIR  "${Sidekiq_LIB_DIRS}")
    set(_CORE_DIR "${CMAKE_INSTALL_FULL_LIBDIR}")  # typically /usr/local/lib/aarch64-linux-gnu on Z4
    if (NOT _CORE_DIR)
        set(_CORE_DIR "/usr/local/lib/aarch64-linux-gnu")
    endif()

    set_target_properties(sidekiq_python PROPERTIES
        BUILD_RPATH   "${_SDK_DIR};${_CORE_DIR};$ORIGIN"
        INSTALL_RPATH "${_SDK_DIR};${_CORE_DIR};$ORIGIN"
    )
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
