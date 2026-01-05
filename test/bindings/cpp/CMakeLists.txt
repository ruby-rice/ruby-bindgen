# =============================================================================
# CMakeLists.txt - Compiles generated Rice bindings to verify they're valid C++
# =============================================================================

# -----------------------------------------------------------------------------
# CMake Version and C++ Standard
# -----------------------------------------------------------------------------
cmake_minimum_required(VERSION 3.26)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# -----------------------------------------------------------------------------
# Project Definition
# -----------------------------------------------------------------------------
project("rice_bindings_test" LANGUAGES CXX)

# -----------------------------------------------------------------------------
# Create Object Library (compile only, no linking)
# -----------------------------------------------------------------------------
# We use OBJECT library to verify the generated code compiles without
# needing to link into a full extension.

add_library(${CMAKE_PROJECT_NAME} OBJECT)

# -----------------------------------------------------------------------------
# Fetch Rice from Local Source
# -----------------------------------------------------------------------------
# Using local Rice source for latest FindRuby.cmake

include(FetchContent)

FetchContent_Declare(
  rice
  SOURCE_DIR c:/Source/rice
)
FetchContent_MakeAvailable(rice)

# -----------------------------------------------------------------------------
# Configure Ruby Detection
# -----------------------------------------------------------------------------
# Rice provides an enhanced FindRuby.cmake that creates proper CMake targets.

list(PREPEND CMAKE_MODULE_PATH "${rice_SOURCE_DIR}")

# -----------------------------------------------------------------------------
# Find Ruby Installation
# -----------------------------------------------------------------------------
find_package(Ruby REQUIRED)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
  Ruby::Module
)

# -----------------------------------------------------------------------------
# Link to Rice
# -----------------------------------------------------------------------------
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
  Rice::Rice
)

# -----------------------------------------------------------------------------
# Include Directories for Test Headers
# -----------------------------------------------------------------------------
# Add the headers directory so we can find the original C++ headers being wrapped

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/../../headers/cpp
)

# -----------------------------------------------------------------------------
# Source Files
# -----------------------------------------------------------------------------
# Generated binding files - update this list when adding new test headers

target_sources(${CMAKE_PROJECT_NAME} PRIVATE
  classes-rb.cpp
  constructors-rb.cpp
  default_values-rb.cpp
  enums-rb.cpp
  functions-rb.cpp
  inheritance-rb.cpp
  iterators-rb.cpp
 # operators-rb.cpp
  templates-rb.cpp
)
