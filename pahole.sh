#!/bin/sh
# A script to install pahole from source.

set -eu

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
readonly tmp

cd "$tmp"
git clone --recurse-submodules --branch "$1" --single-branch https://git.kernel.org/pub/scm/devel/pahole/pahole.git pahole
mkdir pahole/build
cd pahole/build
cmake -D__LIB=lib ..
make install
ldconfig
