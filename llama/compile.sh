#! /bin/bash

set -e

# This script expects to be run inside the build container with the flags:
#   --user nobody:nogroup --workingdir /build --env VERSION="${VERSION}"
cd "llama.cpp-${VERSION}"

# target semi-recent CPU arch
export CC=gcc-14 CFLAGS="-Os -march=haswell -mtune=skylake"
export CXX=g++-14 CXXFLAGS="-Os -march=haswell -mtune=skylake"

# Build a statically compiled AVX2/SSE4.2 llama-server

cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_NATIVE=OFF \
  -DLLAMA_BUILD_TESTS=OFF \
  -DGGML_BACKEND_DL=OFF \
  -DGGML_CPU_ALL_VARIANTS=OFF \
  -DGGML_AVX2=ON \
  -DGGML_SSE42=ON \
  -DGGML_STATIC=ON \
  -DBUILD_SHARED_LIBS=OFF \
  -DGGML_CCACHE=OFF \

cmake --build build -j8
