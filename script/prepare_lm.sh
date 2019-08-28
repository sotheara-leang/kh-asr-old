#!/bin/bash

KALDI_ROOT=`pwd`/../kaldi

data_dir=$1
lm_order=$2

if [[ -z $data_dir ]]; then
    data_dir=data
fi

if [[ -z $lm_order ]]; then
    lm_order=1
fi

loc=`which ngram-count`;

if [[ -z $loc ]]; then
        if uname -a | grep 64 >/dev/null; then
            sdir=$KALDI_ROOT/tools/srilm/bin/i686-m64
        else
            sdir=$KALDI_ROOT/tools/srilm/bin/i686
        fi
        if [[ -f $sdir/ngram-count ]]; then
            echo "Using SRILM language modelling tool from $sdir"
            export PATH=$PATH:$sdir
        else
            echo "SRILM toolkit is probably not installed. Instructions: tools/install_srilm.sh"
            exit 1
        fi
fi

[[ ! -d $data_dir/lm/ ]] && mkdir $data_dir/lm/

ngram-count -order $lm_order -write-vocab $data_dir/lm/vocab.txt -wbdiscount -text $data_dir/corpus.txt -lm $data_dir/lm/lm-$lm_order.arpa