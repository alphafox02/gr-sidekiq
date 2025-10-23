# Collect sources (keep your explicit list if you prefer)
file(GLOB sidekiq_sources
  "${CMAKE_CURRENT_SOURCE_DIR}/*.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/*.c"
)

# Finder for the Sidekiq SDK (Z4-aware)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/Modules")
find_package(Sidekiq REQUIRED)

message(STATUS "Sidekiq_INCLUDE_DIRS - ${Sidekiq_INCLUDE_DIRS}")
message(STATUS "Sidekiq_LIBRARIES   - ${Sidekiq_LIBRARIES}")
message(STATUS "OTHER_LIBS          - ${OTHER_LIBS}")
message(STATUS "Sidekiq_LIB_DIRS    - ${Sidekiq_LIB_DIRS}")
message(STATUS "SUFFIX              - ${SUFFIX}")

add_library(gnuradio-sidekiq SHARED ${sidekiq_sources})

# Public includes
target_include_directories(gnuradio-sidekiq
  PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../include>
  PUBLIC $<INSTALL_INTERFACE:include>
  PRIVATE ${Sidekiq_INCLUDE_DIRS}
)

# Link JUST the SDK libs; avoid forcing system glib/usb here (prevents Z4 conflicts)
target_link_libraries(gnuradio-sidekiq
  PRIVATE
    gnuradio::gnuradio-runtime
    ${Sidekiq_LIBRARIES}
    ${OTHER_LIBS}
)

# Prefer the SDK support dir for link-time lookup and embed RPATH for runtime
if (DEFINED Sidekiq_LIB_DIRS AND EXISTS "${Sidekiq_LIB_DIRS}")
  link_directories("${Sidekiq_LIB_DIRS}")
  set_target_properties(gnuradio-sidekiq PROPERTIES
    BUILD_RPATH   "${Sidekiq_LIB_DIRS}:$ORIGIN"
    INSTALL_RPATH "${Sidekiq_LIB_DIRS}:$ORIGIN")
endif()

# So-versioned install (ldconfig-friendly)
set_target_properties(gnuradio-sidekiq PROPERTIES
  SOVERSION 1
  VERSION   1.0.0
  DEFINE_SYMBOL "gnuradio_sidekiq_EXPORTS"
)

# Install the library
install(TARGETS gnuradio-sidekiq
  EXPORT gnuradio-sidekiq-targets
  LIBRARY DESTINATION ${GR_LIBRARY_DIR} COMPONENT "sidekiq_runtime"
  ARCHIVE DESTINATION ${GR_LIBRARY_DIR} COMPONENT "sidekiq_devel"
  RUNTIME DESTINATION bin                COMPONENT "sidekiq_runtime"
  INCLUDES DESTINATION include
)

