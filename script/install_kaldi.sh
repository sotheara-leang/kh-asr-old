#!/bin/bash

cd ../

PROJ_HOME=`pwd`
KALDI_ROOT=$PROJ_HOME/kaldi

sudo apt-get install atlas autoconf automake git libtool subversion wget zlib
sudo apt-get install gawk bash grep make perl

if [[ ! -f kaldi ]]; then
    git clone https://github.com/kaldi-asr/kaldi.git
fi

# tools

cd $KALDI_ROOT/tools
extras/check_dependencies.sh
make -j 8

# src

cd ../src
./configure
make depend -j 8
make -j 8

# create symbolic link

[[ ! -L "steps" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/steps $PROJ_HOME

[[ ! -L "utils" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/utils $PROJ_HOME

[[ ! -L "conf" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/conf $PROJ_HOME