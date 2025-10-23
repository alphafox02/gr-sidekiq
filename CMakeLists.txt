# Default build type
set(CMAKE_BUILD_TYPE "Release" CACHE STRING "")

cmake_minimum_required(VERSION 3.8)
project(gr-sidekiq CXX C)
enable_testing()

# PyBOMBS prefix
if(DEFINED ENV{PYBOMBS_PREFIX})
  set(CMAKE_INSTALL_PREFIX $ENV{PYBOMBS_PREFIX})
  message(STATUS "PyBOMBS installed GNU Radio. Setting CMAKE_INSTALL_PREFIX to $ENV{PYBOMBS_PREFIX}")
endif()

# Our CMake modules first
list(INSERT CMAKE_MODULE_PATH 0 ${CMAKE_SOURCE_DIR}/cmake/Modules)

# GNU Radio
find_package(Gnuradio "3.10" REQUIRED)

# (Minimal change) We do NOT hardcode /usr/lib/epiq here anymore.
# If your lib/ subdir runs find_package(Sidekiq), its cache vars will be visible here.

# Version / policies
set(VERSION_MAJOR 1)
set(VERSION_API   0)
set(VERSION_ABI   0)
set(VERSION_PATCH 0)
cmake_policy(SET CMP0011 NEW)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(GrMinReq)
include(GrCompilerSettings)
include(GrVersion)
include(GrPlatform) # defines LIB_SUFFIX

if(NOT CMAKE_MODULES_DIR)
  set(CMAKE_MODULES_DIR lib${LIB_SUFFIX}/cmake)
endif()

set(GR_INCLUDE_DIR      include/gnuradio/sidekiq)
set(GR_CMAKE_DIR        ${CMAKE_MODULES_DIR}/gnuradio-sidekiq)
set(GR_PKG_DATA_DIR     ${GR_DATA_DIR}/${CMAKE_PROJECT_NAME})
set(GR_PKG_DOC_DIR      ${GR_DOC_DIR}/${CMAKE_PROJECT_NAME})
set(GR_PKG_CONF_DIR     ${GR_CONF_DIR}/${CMAKE_PROJECT_NAME}/conf.d)
set(GR_PKG_LIBEXEC_DIR  ${GR_LIBEXEC_DIR}/${CMAKE_PROJECT_NAME})

# Apple rpath niceties
if(APPLE)
  if(NOT CMAKE_INSTALL_NAME_DIR)
    set(CMAKE_INSTALL_NAME_DIR
        ${CMAKE_INSTALL_PREFIX}/${GR_LIBRARY_DIR} CACHE PATH "" FORCE)
  endif()
  if(NOT CMAKE_INSTALL_RPATH)
    set(CMAKE_INSTALL_RPATH
        ${CMAKE_INSTALL_PREFIX}/${GR_LIBRARY_DIR} CACHE PATH "" FORCE)
  endif()
  if(NOT CMAKE_BUILD_WITH_INSTALL_RPATH)
    set(CMAKE_BUILD_WITH_INSTALL_RPATH ON CACHE BOOL "" FORCE)
  endif()
endif()

# Doxygen
find_package(Doxygen)
if(DOXYGEN_FOUND)
  option(ENABLE_DOXYGEN "Build docs using Doxygen" ON)
else()
  option(ENABLE_DOXYGEN "Build docs using Doxygen" OFF)
endif()

# Uninstall target
configure_file(
  ${CMAKE_SOURCE_DIR}/cmake/cmake_uninstall.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake
  @ONLY)
add_custom_target(uninstall
  ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake
)

# (Minimal change) Do NOT hard-code: link_directories("/usr/lib/epiq")
# We’ll set per-target RPATHs in lib/ and python/ so runtime lookup works.

# Subdirs
add_subdirectory(include/gnuradio/sidekiq)
add_subdirectory(lib)
add_subdirectory(apps)
add_subdirectory(docs)
if(ENABLE_PYTHON)
  message(STATUS "PYTHON and GRC components are enabled")
  add_subdirectory(python/sidekiq)
  add_subdirectory(grc)
else()
  message(STATUS "PYTHON and GRC components are disabled")
endif()

# Install cmake search helper
install(FILES cmake/Modules/gnuradio-sidekiqConfig.cmake
  DESTINATION ${GR_CMAKE_DIR})

include(CMakePackageConfigHelpers)
configure_package_config_file(
  ${PROJECT_SOURCE_DIR}/cmake/Modules/targetConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/cmake/Modules/${target}Config.cmake
  INSTALL_DESTINATION ${GR_CMAKE_DIR})

