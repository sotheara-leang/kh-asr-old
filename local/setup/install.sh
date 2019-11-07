#!/usr/bin/env bash

install_dir=$1

if [[ -z $PROJ_HOME ]]; then
    echo "Error - PROJ_HOME is undefine"
    exit 1
fi

if [[ -z $install_dir ]]; then
    install_dir=/opt
fi

export KALDI_ROOT=$install_dir/kaldi

echo ">>>>> Install kaldi"
$PROJ_HOME/local/setup/install_kaldi.sh $install_dir

echo ">>>>> Install srilm"
$PROJ_HOME/local/setup/install_srilm.sh