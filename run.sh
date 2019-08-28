#!/bin/bash

# initialization PATH
. ./path.sh || exit 1

# initialization commands
. ./cmd.sh || exit 1

data_dir=$1
output_dir=$2
lm_order=$3

nj=4 # number of parallel jobs - 1 is perfect for such a small dataset

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

### preparing language data

echo
echo ">>>>> Preparing language data"
echo

utils/prepare_lang.sh $data_dir/local/dict "<UNK>" $data_dir/local/lang $data_dir/lang

### making G.fst from lm.arpa

echo
echo ">>>>> Preparing language model"
echo 

[[ ! -d $lang ]] && mkdir $lang

arpa2fst --disambig-symbol=#0 $data_dir/lm/lm-$lm_order.arpa $lang/G-$lm_order.fst

### feature extraction

echo
echo ">>>>> Extracting voice features"
echo

utils/validate_data_dir.sh --no-feats $data_dir/train
utils/fix_data_dir.sh $data_dir/train

steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $data_dir/train $output_dir/log/mfcc/train $output_dir/mfcc/train
steps/compute_cmvn_stats.sh $data_dir/train $output_dir/log/mfcc/train $output_dir/mfcc/train

if [[ -d $data_dir/test ]]; then
    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $data_dir/test $output_dir/log/mfcc/test $output_dir/mfcc/test
    steps/compute_cmvn_stats.sh $data_dir/test $output_dir/log/mfcc/test $output_dir/mfcc/test
fi

### monophone training

echo
echo ">>>>> Monophone: training"
echo

steps/train_mono.sh --nj $nj $data_dir/train $data_dir/lang $data_dir/exp/mono

# graph compilation
utils/mkgraph.sh --mono $data_dir/lang $data_dir/exp/mono $data_dir/exp/mono/graph

# decoding

echo
echo ">>>>> Monophone: decoding"
echo

steps/decode.sh --nj $nj $data_dir/exp/mono/graph $data_dir/test $data_dir/exp/mono/decode_test

# score

echo
echo ">>>>> Scoring"
echo

for x in $output_dir/exp/*/decode*; do [[ -d $x ]] && grep WER $x/wer_* | utils/best_wer.sh; done
