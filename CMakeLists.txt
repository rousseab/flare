cmake_minimum_required(VERSION 4.0)

set(CMAKE_DISABLE_SOURCE_CHANGES ON)
set(CMAKE_DISABLE_IN_SOURCE_BUILD ON)

set(CMAKE_BUILD_TYPE Debug)

project(flare LANGUAGES CXX)
#project(${SKBUILD_PROJECT_NAME} VERSION ${SKBUILD_PROJECT_VERSION} LANGUAGES CXX)
#  message(STATUS "The project name is : ${SKBUILD_PROJECT_NAME}")


list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/CMakeModules/)

include(ExternalProject)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# TODO: let CMAKE detect which architecture its on
#set(CMAKE_OSX_ARCHITECTURES "x86_64")
set(CMAKE_OSX_ARCHITECTURES "arm64") # Apple Silicon machines

if(NOT CMAKE_BUILD_TYPE)
  message(STATUS "[flare] CMAKE_BUILD_TYPE not specified, setting it to "
                 "Release. Use `-DCMAKE_BUILD_TYPE=...` to overwrite.")
  set(CMAKE_BUILD_TYPE Release)
endif()

#
# Dependencies
#

include(FetchContent)

# googletest
################################################################################

if(NOT DEFINED SKBUILD)
    FetchContent_Declare(googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG release-1.11.0
        SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/External/googletest
        UPDATE_COMMAND ""
    )
    FetchContent_MakeAvailable(googletest)
endif()

# Json
################################################################################

FetchContent_Declare(json URL https://github.com/nlohmann/json/releases/download/v3.12.0/json.tar.xz)
FetchContent_MakeAvailable(json)

# Eigen3
################################################################################

ExternalProject_Add(
    eigen_project
    SOURCE_DIR "${CMAKE_BINARY_DIR}/External/Eigen3"
    URL "https://github.com/eigenteam/eigen-git-mirror/archive/3.3.7.tar.gz"
    URL_HASH MD5=77a2c934eaf35943c43ee600a83b72df
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ""
)
ExternalProject_Get_Property(eigen_project SOURCE_DIR)
add_library(Eigen3 INTERFACE)
target_include_directories(Eigen3 SYSTEM INTERFACE ${SOURCE_DIR})
include_directories(${SOURCE_DIR})

# pybind11
###############################################################################
set(PYBIND11_FINDPYTHON ON)
FetchContent_Declare(
    pybind11
    GIT_REPOSITORY https://github.com/pybind/pybind11
    GIT_TAG v2.13.6
)
FetchContent_MakeAvailable(pybind11)
###############################################################################

# Specify source files.
set(FLARE_SOURCES
    src/flare_pp/y_grad.cpp
    src/flare_pp/radial.cpp
    src/flare_pp/cutoffs.cpp
    src/flare_pp/structure.cpp
    src/flare_pp/bffs/sparse_gp.cpp
    src/flare_pp/bffs/gp.cpp
    src/flare_pp/descriptors/descriptor.cpp
    src/flare_pp/descriptors/b1.cpp
    src/flare_pp/descriptors/b2.cpp
    src/flare_pp/descriptors/b2_norm.cpp
    src/flare_pp/descriptors/b2_simple.cpp
    src/flare_pp/descriptors/b3.cpp
    src/flare_pp/descriptors/wigner3j.cpp
    src/flare_pp/descriptors/two_body.cpp
    src/flare_pp/descriptors/three_body.cpp
    src/flare_pp/descriptors/three_body_wide.cpp
    src/flare_pp/descriptors/four_body.cpp
    src/flare_pp/kernels/kernel.cpp
    src/flare_pp/kernels/normalized_dot_product.cpp
    src/flare_pp/kernels/dot_product.cpp
    src/flare_pp/kernels/norm_dot_icm.cpp
    src/flare_pp/kernels/squared_exponential.cpp)

set(PYBIND_SOURCES
    src/flare_pp/ace_binding.cpp)

# Include sources.
include_directories(
  src/flare_pp
  src/flare_pp/descriptors
  src/flare_pp/kernels
  src/flare_pp/bffs)

# Create flare library.
# Should be static to avoid issues with pip installation.
# See: https://github.com/pybind/cmake_example/issues/11
add_library(flare STATIC ${FLARE_SOURCES})
set_target_properties(flare PROPERTIES POSITION_INDEPENDENT_CODE ON)
add_dependencies(flare eigen_project)

# Link to json.
target_link_libraries(flare PUBLIC nlohmann_json::nlohmann_json)

# Link to OpenMP.
if(NOT DEFINED ENV{NO_OMP})
    find_package(OpenMP)
    if(OpenMP_CXX_FOUND)
        target_link_libraries(flare PUBLIC OpenMP::OpenMP_CXX)
    endif()
endif()

# Add conda include directories TODO: MKL issue if not
if(DEFINED ENV{CONDA_PREFIX})
  message(STATUS "Adding conda include directories.")
  include_directories($ENV{CONDA_PREFIX}/include)
  set(CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX}")
  set(CMAKE_LIBRARY_PATH "$ENV{CONDA_PREFIX}/lib")
  set(CMAKE_INCLUDE_PATH "$ENV{CONDA_PREFIX}/include")
endif()


if(NOT DEFINED ENV{NO_LAPACK})
  find_package(LAPACK REQUIRED)
  target_link_libraries(flare PUBLIC LAPACK::LAPACK)

  if (LAPACK_LIBRARIES MATCHES mkl)
    message(STATUS "Linking Eigen to MKL.")
    target_compile_definitions(flare PUBLIC EIGEN_USE_MKL_ALL=1)
  else()
    find_package(LAPACKE)
    if(LAPACKE_FOUND)
      target_link_libraries(flare PUBLIC ${LAPACKE_LIBRARIES})
      message(STATUS "Linking Eigen to LAPACKE.")
      target_compile_definitions(flare PUBLIC EIGEN_USE_LAPACKE=1)
    endif()
  endif()
endif()


# The PYBIND11_MODULE in src/flare_pp/ace_binding is creating a module named _C_flare. 
# The exact same name must be used here.

pybind11_add_module(_C_flare MODULE ${PYBIND_SOURCES})
find_package(Python COMPONENTS Interpreter Development REQUIRED)
target_link_libraries(_C_flare PUBLIC flare)
install(TARGETS _C_flare LIBRARY DESTINATION flare_pp) # CMake variable for library installation directory

# Add test directory.
if(NOT DEFINED SKBUILD)
  add_subdirectory(ctests)
endif()
