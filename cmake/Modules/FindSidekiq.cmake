# - Try to find Sidekiq (Epiq Solutions SDK)
# Once done this will define:
#   Sidekiq_FOUND          - TRUE if Sidekiq was found
#   Sidekiq_LIBRARIES      - Sidekiq libraries to link
#   Sidekiq_INCLUDE_DIRS   - Sidekiq include directories
#   Sidekiq_LIB_DIRS       - Preferred library directories (SDK support dir)
#   OTHER_LIBS             - Extra libs (e.g., iio for z3u/aarch, gpiod for z4)
#   PKGCONFIG_LIBS         - Extra libs from pkg-config (when applicable)
#
# Optional inputs:
#   Sidekiq_PKG_INCLUDE_DIRS, Sidekiq_PKG_LIBRARY_DIRS
#   Sidekiq_DIR (env var): SDK root (defaults to $HOME/sidekiq_sdk_current)
#   SUFFIX: override detected SDK suffix (e.g. z4, z3u, aarch64, ...)
#
# Notes:
#   * For Z4, this module prefers the SDK’s SHARED lib (libsidekiq*.so) and the
#     bundled libgpiod in the Z4 support dir to avoid v1/v2 symbol mismatches.
#   * On non-Z4, behavior mirrors the original finder (static libsidekiq__*.a).

if (NOT Sidekiq_FOUND)
  # ----- SDK root -----
  if (NOT DEFINED Sidekiq_ROOT OR "${Sidekiq_ROOT}" STREQUAL "")
    if (DEFINED ENV{Sidekiq_DIR} AND NOT "$ENV{Sidekiq_DIR}" STREQUAL "")
      set(Sidekiq_ROOT "$ENV{Sidekiq_DIR}")
    else()
      set(Sidekiq_ROOT "$ENV{HOME}/sidekiq_sdk_current")
    endif()
  endif()
  file(TO_CMAKE_PATH "${Sidekiq_ROOT}" Sidekiq_ROOT)

  # ----- Headers -----
  find_path(Sidekiq_INCLUDE_DIR
    NAMES sidekiq_api.h
    HINTS ${Sidekiq_PKG_INCLUDE_DIRS} "${Sidekiq_ROOT}/include" "${Sidekiq_ROOT}/sidekiq_core/inc"
    PATHS /usr/local/include /usr/include /opt/include /opt/local/include
  )
  set(Sidekiq_INCLUDE_DIRS "${Sidekiq_INCLUDE_DIR}")

  # ----- Arch / suffix detection -----
  execute_process(COMMAND uname -m OUTPUT_VARIABLE cpu_arch OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(STRIP "${cpu_arch}" cpu_arch)
  message(STATUS "cpu_arch is: '${cpu_arch}'")

  if (NOT DEFINED SUFFIX OR "${SUFFIX}" STREQUAL "")
    # Prefer a sensible suffix by scanning ${Sidekiq_ROOT}/lib
    set(_SDK_LIB_DIR "${Sidekiq_ROOT}/lib")
    set(SUFFIX "none")
    if (EXISTS "${_SDK_LIB_DIR}")
      # Prefer z4 if the support dir exists (explicit Z4 handling uses shared .so)
      if (EXISTS "${Sidekiq_ROOT}/lib/support/z4")
        set(SUFFIX "z4")
      else()
        # Fallback: pick the first libsidekiq__*.a that also has a matching support/<suffix> dir
        file(GLOB _SK_ARCH "${_SDK_LIB_DIR}/libsidekiq__*.a")
        foreach(_arc IN LISTS _SK_ARCH)
          get_filename_component(_nm "${_arc}" NAME_WE)  # libsidekiq__<suffix>
          string(REPLACE "libsidekiq__" "" _sfx "${_nm}")
          if (EXISTS "${Sidekiq_ROOT}/lib/support/${_sfx}")
            set(SUFFIX "${_sfx}")
            break()
          endif()
        endforeach()
      endif()
    endif()
    if ("${SUFFIX}" STREQUAL "none")
      message(FATAL_ERROR "Could not determine SDK suffix. Set -DSUFFIX=<suffix> (e.g. z4, z3u, aarch64, x86_64.gcc).")
    endif()
  endif()

  # Common support dir and pkgconfig dir
  set(Sidekiq_LIB_DIRS "${Sidekiq_ROOT}/lib/support/${SUFFIX}/usr/lib/epiq")
  set(_PKGCONFIG_DIR   "${Sidekiq_LIB_DIRS}/pkgconfig")

  # ----- Map suffix to lib names / extra deps -----
  set(otherlib "none")
  set(_use_shared FALSE)

  if ("${cpu_arch}" STREQUAL "x86_64")
    # Default x86_64 path (kept from original)
    set(libname "libsidekiq__x86_64.gcc.a")
  elseif ("${SUFFIX}" STREQUAL "msiq-x40")
    set(libname  "libsidekiq__msiq-x40.a")
  elseif ("${SUFFIX}" STREQUAL "msiq-g20g40")
    set(libname  "libsidekiq__msiq-g20g40.a")
  elseif ("${SUFFIX}" STREQUAL "z3u")
    set(libname  "libsidekiq__z3u.a")
    set(otherlib "iio")
  elseif ("${SUFFIX}" STREQUAL "aarch64")
    set(libname  "libsidekiq__aarch64.a")
    set(otherlib "iio")
  elseif ("${SUFFIX}" STREQUAL "aarch64.gcc6.3")
    set(libname  "libsidekiq__aarch64.gcc6.3.a")
    set(otherlib "iio")
  elseif ("${SUFFIX}" STREQUAL "arm_cortex-a9.gcc7.2.1_gnueabihf")
    set(libname  "libsidekiq__arm_cortex-a9.gcc7.2.1_gnueabihf.a")
    set(otherlib "iio")
  elseif ("${SUFFIX}" STREQUAL "z4")
    # Z4: use the SDK’s shared sidekiq + bundled gpiod
    set(_use_shared TRUE)
    set(libname "")  # not used in this branch
  else()
    message(FATAL_ERROR "Invalid platform suffix '${SUFFIX}'")
  endif()

  message(STATUS "Detected SDK SUFFIX: ${SUFFIX}")

  # ----- Locate libraries -----
  unset(Sidekiq_LIBRARY CACHE)
  unset(OTHER_LIBS CACHE)
  set(PKGCONFIG_LIBS "")

  if (_use_shared)
    # Z4 branch: shared lib + bundled gpiod
    find_library(Sidekiq_LIBRARY
      NAMES sidekiq-dev-z4-1 sidekiq
      HINTS "${Sidekiq_LIB_DIRS}" "${Sidekiq_ROOT}/lib"
      NO_DEFAULT_PATH
    )
    if (NOT Sidekiq_LIBRARY)
      message(FATAL_ERROR "Z4: shared sidekiq .so not found in ${Sidekiq_LIB_DIRS}.")
    endif()

    # Always take gpiod from the Z4 bundle (v2 ABI there)
    find_library(GPIOD_SDK_LIBRARY NAMES gpiod
      HINTS "${Sidekiq_LIB_DIRS}" NO_DEFAULT_PATH)
    if (NOT GPIOD_SDK_LIBRARY)
      message(FATAL_ERROR "Z4: libgpiod not found in ${Sidekiq_LIB_DIRS}.")
    endif()
    set(OTHER_LIBS "${GPIOD_SDK_LIBRARY}")

    # Optionally prime PKG_CONFIG_PATH for modules that expect it
    if (EXISTS "${_PKGCONFIG_DIR}")
      set(ENV{PKG_CONFIG_PATH} "${_PKGCONFIG_DIR}:$ENV{PKG_CONFIG_PATH}")
      message(STATUS "Z4: PKG_CONFIG_PATH = $ENV{PKG_CONFIG_PATH}")
    endif()

  else()
    # Non-Z4: preserve original static linking behavior
    find_library(Sidekiq_LIBRARY
      NAMES ${libname}
      HINTS ${Sidekiq_PKG_LIBRARY_DIRS} "${Sidekiq_ROOT}/lib"
      PATHS /usr/local/lib /usr/lib /usr/lib64
    )
    if (NOT Sidekiq_LIBRARY)
      message(FATAL_ERROR "Sidekiq static library not found (expected ${libname}).")
    endif()

    if (NOT "${otherlib}" STREQUAL "none")
      find_library(OTHER_LIBS
        NAMES ${otherlib}
        HINTS ${Sidekiq_PKG_LIBRARY_DIRS} "${Sidekiq_LIB_DIRS}"
        PATHS /usr/lib/epiq /usr/local/lib /usr/lib /opt/lib /opt/local/lib
      )
      if (NOT OTHER_LIBS)
        message(FATAL_ERROR "Required extra library '${otherlib}' not found for suffix ${SUFFIX}.")
      endif()
    endif()
  endif()

  # ----- Export variables -----
  set(Sidekiq_LIBRARIES "${Sidekiq_LIBRARY}")
  set(Sidekiq_PKG_LIBRARY_DIRS "${Sidekiq_LIB_DIRS}")
  set(ENV{Sidekiq_DIR} "${Sidekiq_ROOT}")

  message(STATUS "library is: ${Sidekiq_LIBRARY}")
  message(STATUS "otherlib is: ${OTHER_LIBS}")

  include(FindPackageHandleStandardArgs)
  if (_use_shared)
    find_package_handle_standard_args(Sidekiq DEFAULT_MSG
      Sidekiq_LIBRARY Sidekiq_INCLUDE_DIR)
  else()
    if (NOT "${otherlib}" STREQUAL "none")
      find_package_handle_standard_args(Sidekiq DEFAULT_MSG
        Sidekiq_LIBRARY Sidekiq_INCLUDE_DIR OTHER_LIBS)
    else()
      find_package_handle_standard_args(Sidekiq DEFAULT_MSG
        Sidekiq_LIBRARY Sidekiq_INCLUDE_DIR)
    endif()
  endif()

  mark_as_advanced(Sidekiq_INCLUDE_DIRS Sidekiq_LIBRARIES OTHER_LIBS PKGCONFIG_LIBS)
endif()
