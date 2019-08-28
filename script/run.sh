#!/bin/bash

# initialization PATH
. ./path.sh || exit 1

# initialization commands
. ./cmd.sh || exit 1

data_dir=$1
output_dir=$2
lm_order=$3

nj=1 # number of parallel jobs - 1 is perfect for such a small dataset

if [[ -z $data_dir ]]; then
    data_dir=data
fi

if [[ -z $output_dir ]]; then
    output_dir=$data_dir/exp
fi

if [[ -z $lm_order ]]; then
    lm_order=1
fi

lang=$data_dir/lang

### making G.fst from lm.arpa

[[ ! -d $lang ]] && mkdir $lang

arpa2fst --disambig-symbol=#0 $data_dir/lm/lm-$lm_order.arpa $lang/G-$lm_order.fst

### feature extraction

steps/make_mfcc.sh --nj 4 $data_dir/train $output_dir/make_mfcc/train mfcc
steps/compute_cmvn_stats.sh $data_dir/train $output_dir/make_mfcc/train mfcc

if [[ -d $data_dir/test ]]; then
    steps/make_mfcc.sh --nj 4 $data_dir/test $output_dir/exp/make_mfcc/test mfcc
    steps/compute_cmvn_stats.sh $data_dir/test $output_dir/exp/make_mfcc/test mfcc
fi

### monophone training

steps/train_mono.sh --nj $nj $data_dir/train $data_dir/lang $data_dir/exp/mono

# graph compilation
utils/mkgraph.sh --mono $data_dir/lang $data_dir/exp/mono $data_dir/exp/mono/graph

# decoding
steps/decode.sh --nj $nj $data_dir/exp/mono/graph $data_dir/test $data_dir/exp/mono/decode_test

echo -e "Mono training done.\n"

# score
for x in $output_dir/exp/*/decode*; do [[ -d $x ]] && grep WER $x/wer_* | utils/best_wer.sh; done