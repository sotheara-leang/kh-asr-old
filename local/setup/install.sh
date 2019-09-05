#!/usr/bin/env bash

if [[ -z ${PROJ_HOME} ]]; then
    echo "Error - PROJ_HOME is undefine"
    exit 1
fi

echo ">>>>> Install kaldi"
$PROJ_HOME/local/setup/install_kaldi.sh

echo ">>>>> Install srilm"
$PROJ_HOME/local/setup/install_srilm.sh