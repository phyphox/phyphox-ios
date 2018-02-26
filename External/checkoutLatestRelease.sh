#!/bin/bash

set -e

if test "$#" -ne 2; then
echo "Illegal number of parameters"
return
fi

tag=$(curl -s -S -L "https://api.github.com/repos/$1/releases/latest" | jq -r '.tag_name')

. checkoutLatestCommit.sh "$1" "$2" "$tag"
