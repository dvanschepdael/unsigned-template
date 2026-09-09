#!/usr/bin/env bash
set -euo pipefail

# Build in a disposable copy: generated SDK files never dirty the submodule.
source_dir=$1
build_dir=$2
python_bin=$3
mkdir -p "$build_dir/source" "$build_dir/install"
build_dir=$(cd "$build_dir" && pwd)
tar -C "$source_dir" --exclude=.git -cf - . | tar -C "$build_dir/source" -xf -
cd "$build_dir/source"
# MSYS2 keeps pkg-config's Autoconf macros under the active subsystem prefix.
pkg_prefix=$(pkg-config --variable=prefix pkg-config)
if [ -z "$pkg_prefix" ]; then
    pkg_prefix=$(dirname "$(dirname "$(command -v pkg-config)")")
fi
if [ -n "$pkg_prefix" ] && [ -d "$pkg_prefix/share/aclocal" ]; then
    export ACLOCAL_PATH="$pkg_prefix/share/aclocal${ACLOCAL_PATH:+:$ACLOCAL_PATH}"
fi
autoreconf -fi
./configure --prefix="$build_dir/install" --with-python="$python_bin" \
    --enable-external-toolchain --enable-external-emudbg \
    --enable-external-gngeo --disable-examples
# The upstream BIOS ZIP recipes must not run concurrently under MSYS2.
make -j1
make -j1 install
touch "$build_dir/.installed"
