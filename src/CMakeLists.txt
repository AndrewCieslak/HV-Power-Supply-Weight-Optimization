add_executable(hvps_app main.cpp)
set_target_properties(hvps_app PROPERTIES RUNTIME_OUTPUT_DIRECTORY
                                          "${CMAKE_BINARY_DIR}/bin")

target_compile_options(
  hvps_app
  PRIVATE $<$<CXX_COMPILER_ID:MSVC>:/W4
          /permissive
          /Zc:preprocessor->
          $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wall
          -Wextra
          -Wpedantic
          -Wshadow
          -pedantic-errors>)

add_custom_target(
  run
  COMMAND $<TARGET_FILE:hvps_app>
  DEPENDS hvps_app
  WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
  USES_TERMINAL)

apply_sanitizers(hvps_app)
apply_lto(hvps_app)
