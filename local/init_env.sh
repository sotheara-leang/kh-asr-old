#!/usr/bin/env bash

if [[ ! -d $KALDI_ROOT ]]; then
  echo "kaldi folder not found -> local/setup/install.sh"
  exit 1
fi

[[ -f $KALDI_ROOT/tools/env.sh ]] && . $KALDI_ROOT/tools/env.sh

export PATH=$KALDI_ROOT/utils:$KALDI_ROOT/steps:$KALDI_ROOT/tools/openfst/bin:$PATH

. $KALDI_ROOT/tools/config/common_path.sh

export LC_ALL=C
