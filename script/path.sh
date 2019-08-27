#!/bin/bash

export PROJ_HOME=`pwd`/..

if [[ -d $PROJ_HOME/kaldi ]]; then

    export KALDI_ROOT=$PROJ_HOME/kaldi

    . $KALDI_ROOT/tools/env.sh

    export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$PWD:$PATH

    . $KALDI_ROOT/tools/config/common_path.sh

    export LC_ALL=C
fi