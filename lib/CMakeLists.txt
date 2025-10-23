# Library sources: keep explicit list if you have one; GLOB is OK for drop-in
file(GLOB_RECURSE sidekiq_sources
  "${CMAKE_CURRENT_SOURCE_DIR}/*.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/*.c"
)

add_library(gnuradio-sidekiq SHARED ${sidekiq_sources})

# Public includes
target_include_directories(gnuradio-sidekiq
  PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../include>
  PUBLIC $<INSTALL_INTERFACE:include>
)

# Link JUST the SDK libs that the finder exports:
# - ${Sidekiq_LIBRARIES} -> libsidekiq*.so (Z4) or static .a (others)
# - ${OTHER_LIBS}        -> libgpiod on Z4; iio on aarch variants
target_link_libraries(gnuradio-sidekiq
  PRIVATE
    gnuradio::gnuradio-runtime
    ${Sidekiq_LIBRARIES}
    ${OTHER_LIBS}
)

# Prefer the SDK support dir for link-time lookup and embed an RPATH for runtime
if (EXISTS "${Sidekiq_LIB_DIRS}")
  link_directories("${Sidekiq_LIB_DIRS}")
  set_target_properties(gnuradio-sidekiq PROPERTIES
    BUILD_RPATH   "${Sidekiq_LIB_DIRS}:$ORIGIN"
    INSTALL_RPATH "${Sidekiq_LIB_DIRS}:$ORIGIN")
endif()

set_target_properties(gnuradio-sidekiq PROPERTIES
  DEFINE_SYMBOL "gnuradio_sidekiq_EXPORTS"
  SOVERSION 1
  VERSION   1.0.0
)

# Install the library
install(TARGETS gnuradio-sidekiq
  EXPORT gnuradio-sidekiq-targets
  LIBRARY DESTINATION ${GR_LIBRARY_DIR} COMPONENT "sidekiq_runtime"
  ARCHIVE DESTINATION ${GR_LIBRARY_DIR} COMPONENT "sidekiq_devel"
  RUNTIME DESTINATION bin                COMPONENT "sidekiq_runtime"
  INCLUDES DESTINATION include
)


