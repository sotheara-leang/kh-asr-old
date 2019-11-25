#!/usr/bin/env bash

INSTALL_DIR=$1

if [[ -z INSTALL_DIR ]]; then
    INSTALL_DIR=/opt
fi

nproc=4

os=`uname`
if [[ $os == 'Darwin' ]]; then
    brew install \
        gcc \
        make \
        automake \
        autoconf \
        bzip2 \
        unzip \
        wget \
        sox \
        libtool \
        git \
        subversion \
        python3 \
        zlib

    brew cask install gfortran
else
    apt-get update && apt-get install -y  \
        autoconf \
        automake \
        bzip2 \
        g++ \
        git \
        make \
        python3 \
        subversion \
        unzip \
        wget \
        sox \
        zlib1g-dev \
        gfortran
fi

cd $INSTALL_DIR && [[ ! -d kaldi ]] && git clone https://github.com/kaldi-asr/kaldi.git

touch $KALDI_ROOT/tools/python/.use_default_python

cd $KALDI_ROOT/tools && \
    ./extras/check_dependencies.sh && \
    make -j $(nproc) && \
    #./install_portaudio.sh && \
    #./extras/install_mkl.sh && \

cd $KALDI_ROOT/src && \
    ./configure --shared && \
    make -j $(nproc) depend && \
    make -j $(nproc) && \

cd $KALDI_ROOT/src && \
    make -j $(nproc) ext

# create symbolic link

[[ ! -L $PROJ_HOME/steps ]] && ln -s $KALDI_ROOT/egs/wsj/s5/steps $KALDI_ROOT
[[ ! -L $PROJ_HOME/utils ]] && ln -s $KALDI_ROOT/egs/wsj/s5/utils $KALDI_ROOT
