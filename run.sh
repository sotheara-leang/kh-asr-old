#!/bin/bash

# initialization PATH
. ./path.sh || exit 1

# initialization commands
. ./cmd.sh || exit 1

# parameters

data_dir=$1
output_dir=$2
step=$3
nj=$4 # number of parallel jobs - 1 is perfect for such a small dataset

if [[ -z $data_dir ]]; then
    data_dir=data
fi

if [[ -z $output_dir ]]; then
    output_dir=$data_dir/exp
fi

if [[ -z $step ]]; then
    step=-1
fi

if [[ -z $nj ]]; then
    nj=4
fi

#### Stage 1 - Data preparation ####

if [[ $step -eq 1 ]] || [[ $step -eq -1 ]]; then

    echo
    echo ">>>>> Validation data"
    echo

    utils/validate_data_dir.sh --no-feats $data_dir/train
    utils/fix_data_dir.sh $data_dir/train

    utils/validate_data_dir.sh --no-feats $data_dir/test
    utils/fix_data_dir.sh $data_dir/test

    echo
    echo ">>>>> Preparing dictionary"
    echo

    utils/prepare_lang.sh $data_dir/local/dict "<UNK>" $data_dir/local/lang $data_dir/lang || exit 1

    echo
    echo ">>>>> Preparing language model"
    echo

    lang=$data_dir/lang
    [[ ! -d $lang ]] && mkdir $lang

    arpa2fst --disambig-symbol=#0 $data_dir/lm/lm.arpa $lang/G.fst

    echo
    echo ">>>>> Extracting MFCC features"
    echo

    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $data_dir/train $output_dir/make_mfcc/train $output_dir/mfcc/train
    steps/compute_cmvn_stats.sh $data_dir/train $output_dir/make_mfcc/train $output_dir/mfcc/train

    if [[ -d $data_dir/test ]]; then
        steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $data_dir/test $output_dir/make_mfcc/test $output_dir/mfcc/test
        steps/compute_cmvn_stats.sh $data_dir/test $output_dir/make_mfcc/test $output_dir/mfcc/test
    fi
fi

#### Stage 2 - Monophone training ####

if [[ $step -eq 2 ]] || [[ $step -eq -1 ]]; then

    echo
    echo ">>>>> Monophone: training"
    echo

    steps/train_mono.sh --nj $nj --cmd "$train_cmd" $data_dir/train $data_dir/lang $data_dir/exp/mono || exit 1

    # graph compilation
    utils/mkgraph.sh --mono $data_dir/lang $data_dir/exp/mono $data_dir/exp/mono/graph || exit 1

    echo
    echo ">>>>> Monophone: decoding"
    echo

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $data_dir/exp/mono/graph $data_dir/test $data_dir/exp/mono/decode_test
fi

#### Stage 3 - Triphone training ####

if [[ $step -eq 3 ]] || [[ $step -eq -1 ]]; then
    echo
fi

#### score

for x in $output_dir/exp/*/decode*; do [[ -d $x ]] && grep WER $x/wer_* | utils/best_wer.sh; done
