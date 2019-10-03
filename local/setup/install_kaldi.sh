#!/usr/bin/env bash

KALDI_ROOT=$PROJ_HOME/kaldi

cd $PROJ_HOME

os=`uname`
if [[ $os == 'Darwin' ]]; then
    brew install gcc make automake autoconf bzip2 unzip wget sox libtool git subversion \
        python3 zlib
else
    sudo apt-get update
    sudo apt-get install g++ make automake autoconf bzip2 unzip wget sox libtool git subversion \
        python3 zlib1g-dev
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

#
make ext

# create symbolic link
[[ ! -L "steps" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/steps $PROJ_HOME
[[ ! -L "utils" ]] && ln -s $KALDI_ROOT/egs/wsj/s5/utils $PROJ_HOME