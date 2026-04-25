macro(eigen_tests_configure_linker project_name)
  set(eigen_tests_USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(eigen_tests_USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC" "MSVC")
  set_property(CACHE eigen_tests_USER_LINKER_OPTION PROPERTY STRINGS ${eigen_tests_USER_LINKER_OPTION_VALUES})
  list(
    FIND
    eigen_tests_USER_LINKER_OPTION_VALUES
    ${eigen_tests_USER_LINKER_OPTION}
    eigen_tests_USER_LINKER_OPTION_INDEX)

  if(${eigen_tests_USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${eigen_tests_USER_LINKER_OPTION}', explicitly supported entries are ${eigen_tests_USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${eigen_tests_USER_LINKER_OPTION}")
endmacro()
