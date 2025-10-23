# Install pure-Python package files
file(GLOB_RECURSE py_files
  "${CMAKE_CURRENT_SOURCE_DIR}/*.py"
)

if (py_files)
  install(FILES ${py_files}
    DESTINATION ${GR_PYTHON_DIR}/gnuradio/sidekiq
    COMPONENT "sidekiq_python"
  )
endif()

# If you have a binary python module (SWIG/pybind) under bindings/, build it:
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/bindings/CMakeLists.txt")
  add_subdirectory(bindings)
endif()

