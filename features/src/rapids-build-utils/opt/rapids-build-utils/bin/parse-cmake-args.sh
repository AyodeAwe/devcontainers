#! /usr/bin/env bash

parse_cmake_args() {

    set -euo pipefail;

    local ARG="";
    local args=(${CMAKE_ARGS:-});
    args+=(-GNinja);
    args+=(-DCMAKE_BUILD_TYPE=Release);
    args+=(-DCMAKE_EXPORT_COMPILE_COMMANDS=ON);
    args+=(-DCMAKE_CUDA_ARCHITECTURES=${CUDAARCHS:-native});
    args+=(-DCMAKE_C_COMPILER="$(realpath -m "$(which gcc)")");
    args+=(-DCMAKE_CXX_COMPILER="$(realpath -m "$(which g++)")");
    args+=(-DCMAKE_CUDA_COMPILER="$(realpath -m "$(which nvcc)")");
    args+=(-DCMAKE_CUDA_HOST_COMPILER="$(realpath -m "$(which gcc)")");

    while test -n "${1:-}"; do
        ARG="${1:-}";
        if [[ "$ARG" == -D ]]; then
            shift;
            if test -n "${1:-}"; then
                ARG+="${1:-}";
                args+=("$ARG");
            fi
            shift;
            continue;
        fi
        shift;
        args+=("$ARG");
    done;

    echo ${args[@]};
}

(parse_cmake_args "$@");
