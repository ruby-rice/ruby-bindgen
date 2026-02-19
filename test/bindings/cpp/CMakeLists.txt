cmake_minimum_required(VERSION 3.26)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

project("test_project" LANGUAGES CXX)

# Create the Extension Library
if (MSVC)
  add_library(${CMAKE_PROJECT_NAME} SHARED)
else ()
  add_library(${CMAKE_PROJECT_NAME} MODULE)
endif ()

# Fetch Rice from GitHub
include(FetchContent)

FetchContent_Declare(
  rice
  GIT_REPOSITORY https://github.com/ruby-rice/rice.git
  GIT_TAG master
)
FetchContent_MakeAvailable(rice)

# Configure Ruby Detection
list(PREPEND CMAKE_MODULE_PATH "${rice_SOURCE_DIR}")

# Find Ruby
find_package(Ruby REQUIRED)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
  Ruby::Module
)

# Link to Rice
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
  Rice::Rice
)

# Include Directories
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../../headers/cpp"
)

# Configure Extension Output
get_target_property(RUBY_EXT_SUFFIX Ruby::Ruby INTERFACE_RUBY_EXTENSION_SUFFIX)

set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES
  PREFIX ""
  SUFFIX "${RUBY_EXT_SUFFIX}"
  OUTPUT_NAME "test_project"
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN ON
  WINDOWS_EXPORT_ALL_SYMBOLS OFF
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../lib/${Ruby_VERSION_MAJOR}.${Ruby_VERSION_MINOR}"
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../lib"
)

# Subdirectories

# Sources
target_sources(${CMAKE_PROJECT_NAME} PRIVATE
  "buffers-rb.cpp"
  "classes-rb.cpp"
  "constructors-rb.cpp"
  "cross_file_derived-rb.cpp"
  "default_values-rb.cpp"
  "enums-rb.cpp"
  "filtering-rb.cpp"
  "functions-rb.cpp"
  "incomplete_types-rb.cpp"
  "inheritance-rb.cpp"
  "iterators-rb.cpp"
  "operators-rb.cpp"
  "overloads-rb.cpp"
  "template_defaults-rb.cpp"
  "template_inheritance-rb.cpp"
  "templates-rb.cpp"
)
