#!/bin/bash

set -e

if [ "$#" -ne 1 ]; then
    echo "Give the path to lammps as a command-line argument!"
    exit 1
fi

lammps=$1
src=$lammps/src
kk=$src/KOKKOS

for f in $(ls kokkos)
do
    if [[ "$f" == *mgp* ]];then
        continue
    fi
    ln -s $(pwd)/kokkos/$f $kk/$f
done

for f in *.cpp *.h
do
    ln -s $(pwd)/$f $src/$f
done

for f in cutoffs radial y_grad
do
    for ex in cpp h
    do
        ln -s $(pwd)/../src/flare_pp/$f.$ex $src/$f.$ex
    done
done

echo '
################################################################################
# Add Eigen3 as a dependency for FLARE
################################################################################
include(ExternalProject)

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

################################################################################
# Add the FLARE relevant source files
################################################################################
target_sources(lammps PRIVATE
    ${LAMMPS_SOURCE_DIR}/cutoffs.cpp
    ${LAMMPS_SOURCE_DIR}/lammps_descriptor.cpp
    ${LAMMPS_SOURCE_DIR}/radial.cpp
    ${LAMMPS_SOURCE_DIR}/y_grad.cpp
)

if(PKG_KOKKOS)
    set(KokkosKernels_ADD_DEFAULT_ETI OFF CACHE BOOL "faster build")
    set(KokkosKernels_ENABLED_COMPONENTS BLAS CACHE STRING "faster build")

    if(EXTERNAL_KOKKOS)
        find_package(KokkosKernels REQUIRED)
    else()
        include(FetchContent)
        FetchContent_Declare(
            kokkoskernels
            GIT_REPOSITORY https://github.com/kokkos/kokkos-kernels.git
        )
        FetchContent_MakeAvailable(kokkoskernels)
    endif()
    target_link_libraries(lammps PUBLIC Kokkos::kokkoskernels)
endif()
' >> $lammps/cmake/CMakeLists.txt
