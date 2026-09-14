cmake_minimum_required(VERSION 3.16)
project(modal LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(MODAL_BUILD_TESTS "Build the unit tests" ON)

# -ffast-math is deliberately absent. It implies -ffinite-math-only, which
# lets the compiler assume no value is ever NaN and delete the guard that
# catches a bad coefficient before it poisons the mix for the session.
add_library(modal_core
  core/src/json.cpp
  core/src/model.cpp
  core/src/bank.cpp
  core/src/queue.cpp
  core/src/voice.cpp
  core/src/excitation.cpp)
target_include_directories(modal_core PUBLIC core/include PRIVATE core/src)
target_compile_options(modal_core PRIVATE
  -O2 -fno-math-errno -ffp-contract=fast -Wall -Wextra)

add_library(modal_fitter
  fitter/src/fft.cpp
  fitter/src/fitter.cpp)
target_include_directories(modal_fitter PUBLIC fitter/src PRIVATE fitter/third_party)
target_link_libraries(modal_fitter PUBLIC modal_core)
target_compile_options(modal_fitter PRIVATE -O2 -Wall -Wextra)

add_executable(modal-fit fitter/src/main.cpp)
target_link_libraries(modal-fit PRIVATE modal_fitter)
target_compile_options(modal-fit PRIVATE -O2 -Wall -Wextra)

add_executable(modal-render harness/src/main.cpp)
target_link_libraries(modal-render PRIVATE modal_core)
target_compile_options(modal-render PRIVATE -O2 -Wall -Wextra)

if(MODAL_BUILD_TESTS)
  enable_testing()
  add_executable(modal_tests
    tests/main.cpp
    tests/test_model.cpp
    tests/test_bank.cpp
    tests/test_excitation.cpp
    tests/test_fitter.cpp
    tests/test_queue.cpp
    tests/test_voice.cpp)
  target_link_libraries(modal_tests PRIVATE modal_core modal_fitter)
  target_include_directories(modal_tests PRIVATE tests)
  target_compile_options(modal_tests PRIVATE -O2 -Wall -Wextra)
  add_test(NAME modal_tests COMMAND modal_tests)
endif()
