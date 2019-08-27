#!/bin/bash

cd ../

sudo apt-get install atlas autoconf automake git libtool subversion wget zlib
sudo apt-get install gawk bash grep make perl

if [[ ! -f kaldi ]]; then
    git clone https://github.com/kaldi-asr/kaldi.git
fi

# tools
cd kaldi/tools
extras/check_dependencies.sh
make -j 8

# src
cd ../src
./configure
make depend -j 8
make -j 8