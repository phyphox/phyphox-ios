#!/bin/bash

set -e

if test "$#" -lt 2; then
echo "Illegal number of parameters"
return
fi

if test "$#" -eq 3; then
rm -rf "$2"
git -c advice.detachedHead=false clone --recursive --depth=1 "https://github.com/$1" "$2" --branch "$3"
find "$2" -name .git -prune -exec rm -rf {} \;
else
rm -rf "$2"
git -c advice.detachedHead=false clone --recursive --depth=1 "https://github.com/$1" "$2"
find "$2" -name .git -prune -exec rm -rf {} \;
fi
