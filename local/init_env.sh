#!/usr/bin/env bash

if [[ -f $PROJ_HOME/kaldi ]]; then
  echo "kaldi folder not found"
  exit 1
fi

export KALDI_ROOT=$PROJ_HOME/kaldi

. $KALDI_ROOT/tools/env.sh

export PATH=$PROJ_HOME/utils:$PROJ_HOME/steps:$KALDI_ROOT/tools/openfst/bin:$PROJ_HOME:$PATH

. $KALDI_ROOT/tools/config/common_path.sh

export LC_ALL=C
