#!/bin/bash

mydir="$(pwd)"
version="2.2"
tarball="$mydir/NsCDE-$version.tar.gz"
set -x
set -e

umask 0022
cd /tmp
tar xpzf "$tarball"
cd "NsCDE-$version"
./configure
make
make install
