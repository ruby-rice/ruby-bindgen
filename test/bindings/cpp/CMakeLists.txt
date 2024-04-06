cmake_minimum_required (VERSION 3.26)

project(test-class)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package("Ruby")

if (MSVC)
  set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<IF:$<AND:$<C_COMPILER_ID:MSVC>,$<CXX_COMPILER_ID:MSVC>>,$<$<CONFIG:Debug,RelWithDebInfo>:EditAndContinue>,$<$<CONFIG:Debug,RelWithDebInfo>:ProgramDatabase>>")
  add_compile_definitions(-D_CRT_SECURE_NO_DEPRECATE -D_CRT_NONSTDC_NO_DEPRECATE)
  add_compile_options(/bigobj)
  # The default of /EHsc crashes Ruby when calling longjmp with optimizations on (/O2)
  string(REGEX REPLACE "/EHsc" "/EHs" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
else (GCC)
  add_compile_options(-ftemplate-backtrace-limit=0)
  # https://github.com/doxygen/doxygen/issues/9269#issuecomment-1094975328
  add_compile_options(-Wa,-mbig-obj)
endif ()

add_library (${PROJECT_NAME})

# Subdirectories
add_subdirectory ("opencv4")

# Sources
target_sources(${PROJECT_NAME} PRIVATE
    "class-rb.cpp"
    "test-class-rb.cpp"
  )
