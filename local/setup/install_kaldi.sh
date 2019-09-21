#!/usr/bin/env bash

KALDI_ROOT=$PROJ_HOME/kaldi

cd $PROJ_HOME

os=`uname`
if [[ os -eq 'Darwin' ]]; then
    brew install automake cmake git graphviz libtool pkg-config wget
else
    sudo apt-get install autoconf automake cmake curl g++ git graphviz \
    libatlas3-base libtool make pkg-config subversion unzip wget zlib1g-dev
fi

if [[ ! -d kaldi ]]; then
    git clone https://github.com/kaldi-asr/kaldi.git
fi

# tools
cd $KALDI_ROOT/tools
./extras/check_dependencies.sh
make -j 8

# src
cd $KALDI_ROOT/src
./configure
make depend -j 8
make -j 8

# create symbolic link
[[ ! -L "steps" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/steps $PROJ_HOME
[[ ! -L "utils" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/utils $PROJ_HOME