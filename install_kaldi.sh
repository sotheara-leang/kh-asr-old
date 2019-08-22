#!/bin/bash

sudo apt-get install atlas autoconf automake git libtool svn wget zlib
sudo apt-get install awk bash grep make perl

git clone https://github.com/kaldi-asr/kaldi.git

# tools
cd kaldi/tools
extras/check_dependencies.sh
make -j 8

# to install srilm, follow kaldi/tools/install_srilm.sh

# src
cd ../src
./configure
make depend -j 8
make -j 8