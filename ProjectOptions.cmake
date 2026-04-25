include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(eigen_tests_supports_sanitizers)
  # Emscripten doesn't support sanitizers
  if(EMSCRIPTEN)
    set(SUPPORTS_UBSAN OFF)
    set(SUPPORTS_ASAN OFF)
  elseif((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(eigen_tests_setup_options)
  option(eigen_tests_ENABLE_HARDENING "Enable hardening" ON)
  option(eigen_tests_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    eigen_tests_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    eigen_tests_ENABLE_HARDENING
    OFF)

  eigen_tests_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR eigen_tests_PACKAGING_MAINTAINER_MODE)
    option(eigen_tests_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(eigen_tests_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(eigen_tests_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(eigen_tests_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(eigen_tests_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(eigen_tests_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(eigen_tests_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(eigen_tests_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(eigen_tests_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(eigen_tests_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(eigen_tests_ENABLE_PCH "Enable precompiled headers" OFF)
    option(eigen_tests_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(eigen_tests_ENABLE_IPO "Enable IPO/LTO" ON)
    option(eigen_tests_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(eigen_tests_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(eigen_tests_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(eigen_tests_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(eigen_tests_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(eigen_tests_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(eigen_tests_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(eigen_tests_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(eigen_tests_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(eigen_tests_ENABLE_PCH "Enable precompiled headers" OFF)
    option(eigen_tests_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      eigen_tests_ENABLE_IPO
      eigen_tests_WARNINGS_AS_ERRORS
      eigen_tests_ENABLE_SANITIZER_ADDRESS
      eigen_tests_ENABLE_SANITIZER_LEAK
      eigen_tests_ENABLE_SANITIZER_UNDEFINED
      eigen_tests_ENABLE_SANITIZER_THREAD
      eigen_tests_ENABLE_SANITIZER_MEMORY
      eigen_tests_ENABLE_UNITY_BUILD
      eigen_tests_ENABLE_CLANG_TIDY
      eigen_tests_ENABLE_CPPCHECK
      eigen_tests_ENABLE_COVERAGE
      eigen_tests_ENABLE_PCH
      eigen_tests_ENABLE_CACHE)
  endif()

  eigen_tests_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (eigen_tests_ENABLE_SANITIZER_ADDRESS OR eigen_tests_ENABLE_SANITIZER_THREAD OR eigen_tests_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(eigen_tests_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(eigen_tests_global_options)
  if(eigen_tests_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    eigen_tests_enable_ipo()
  endif()

  eigen_tests_supports_sanitizers()

  if(eigen_tests_ENABLE_HARDENING AND eigen_tests_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR eigen_tests_ENABLE_SANITIZER_UNDEFINED
       OR eigen_tests_ENABLE_SANITIZER_ADDRESS
       OR eigen_tests_ENABLE_SANITIZER_THREAD
       OR eigen_tests_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${eigen_tests_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${eigen_tests_ENABLE_SANITIZER_UNDEFINED}")
    eigen_tests_enable_hardening(eigen_tests_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(eigen_tests_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(eigen_tests_warnings INTERFACE)
  add_library(eigen_tests_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  eigen_tests_set_project_warnings(
    eigen_tests_warnings
    ${eigen_tests_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  include(cmake/Linker.cmake)
  # Must configure each target with linker options, we're avoiding setting it globally for now

  if(NOT EMSCRIPTEN)
    include(cmake/Sanitizers.cmake)
    eigen_tests_enable_sanitizers(
      eigen_tests_options
      ${eigen_tests_ENABLE_SANITIZER_ADDRESS}
      ${eigen_tests_ENABLE_SANITIZER_LEAK}
      ${eigen_tests_ENABLE_SANITIZER_UNDEFINED}
      ${eigen_tests_ENABLE_SANITIZER_THREAD}
      ${eigen_tests_ENABLE_SANITIZER_MEMORY})
  endif()

  set_target_properties(eigen_tests_options PROPERTIES UNITY_BUILD ${eigen_tests_ENABLE_UNITY_BUILD})

  if(eigen_tests_ENABLE_PCH)
    target_precompile_headers(
      eigen_tests_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(eigen_tests_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    eigen_tests_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(eigen_tests_ENABLE_CLANG_TIDY)
    eigen_tests_enable_clang_tidy(eigen_tests_options ${eigen_tests_WARNINGS_AS_ERRORS})
  endif()

  if(eigen_tests_ENABLE_CPPCHECK)
    eigen_tests_enable_cppcheck(${eigen_tests_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(eigen_tests_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    eigen_tests_enable_coverage(eigen_tests_options)
  endif()

  if(eigen_tests_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(eigen_tests_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(eigen_tests_ENABLE_HARDENING AND NOT eigen_tests_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR eigen_tests_ENABLE_SANITIZER_UNDEFINED
       OR eigen_tests_ENABLE_SANITIZER_ADDRESS
       OR eigen_tests_ENABLE_SANITIZER_THREAD
       OR eigen_tests_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    eigen_tests_enable_hardening(eigen_tests_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
