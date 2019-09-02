#!/bin/bash

# initialization PATH
. ./path.sh || exit 1

# initialization commands
. ./cmd.sh || exit 1

# parameters
data_dir=$1
output_dir=$2
step=$3
nj=$4

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

# load configuration
. conf/run.conf

#### Step 1 - Data preparation ####

if [[ $step -eq 1 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                          Data Preparation                                "
    echo ============================================================================

    echo ">>>>> Validate data"

    utils/validate_data_dir.sh --no-feats $data_dir/train
    utils/fix_data_dir.sh $data_dir/train

    utils/validate_data_dir.sh --no-feats $data_dir/test
    utils/fix_data_dir.sh $data_dir/test

    echo ">>>>> Prepare dictionary"

    utils/prepare_lang.sh $data_dir/local/dict "<UNK>" $data_dir/local/lang $data_dir/lang || exit 1

    echo ">>>>> Prepare language model"

    lang=$data_dir/lang
    [[ ! -d $lang ]] && mkdir $lang

    arpa2fst --disambig-symbol=#0 $data_dir/lm/lm.arpa $lang/G.fst

    eho ">>>>> Extract MFCC features"

    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $data_dir/train $output_dir/make_mfcc/train $output_dir/mfcc/train
    steps/compute_cmvn_stats.sh $data_dir/train $output_dir/make_mfcc/train $output_dir/mfcc/train

    if [[ -d $data_dir/test ]]; then
        steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $data_dir/test $output_dir/make_mfcc/test $output_dir/mfcc/test
        steps/compute_cmvn_stats.sh $data_dir/test $output_dir/make_mfcc/test $output_dir/mfcc/test
    fi
fi

#### Step 2 - Monophone ####

if [[ $step -eq 2 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                          mono : Monophone                                "
    echo ============================================================================

    echo ">>>>> Monophone: training"

    steps/train_mono.sh --nj $nj --cmd "$train_cmd" $data_dir/train $data_dir/lang $data_dir/exp/mono || exit 1

    utils/mkgraph.sh --mono $data_dir/lang $data_dir/exp/mono $data_dir/exp/mono/graph || exit 1

    echo ">>>>> Monophone: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $data_dir/exp/mono/graph $data_dir/test $data_dir/exp/mono/decode_test || exit 1
fi

#### Step 3 - Deltas + Delta-Deltas ####

if [[ $step -eq 3 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                       tri1 : Deltas + Delta-Deltas                       "
    echo ============================================================================

    echo ">>>>> Monophone: alignment"

    steps/align_si.sh --boost-silence 1.25 --nj $nj  --cmd "$train_cmd" \
        $data_dir/train $data_dir/lang $data_dir/exp/mono $data_dir/exp/mono_ali || exit 1

    echo ">>>>> Deltas + Delta-Deltas: training"

    steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25  $numLeavesTri1 $numGaussTri1  \
        $data_dir/train $data_dir/lang $data_dir/exp/mono_ali $data_dir/exp/tri1 || exit 1

    utils/mkgraph.sh $data_dir/lang $data_dir/exp/tri1 $data_dir/exp/tri1/graph

    echo ">>>>> Deltas + Delta-Deltas: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $data_dir/exp/tri1/graph  $data_dir/test $data_dir/exp/tri1/decode_test || exit 1
fi

#### Step 4 - LDA-MLLT ####

if [[ $step -eq 4 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                             tri2 : LDA-MLLT                              "
    echo ============================================================================

    echo ">>>>> Deltas + Delta-Deltas: alignment"

    steps/align_si.sh --nj $nj --cmd "$decode_cmd" $data_dir/train $data_dir/lang $data_dir/exp/tri1 $data_dir/exp/tri1_ali || exit 1

    echo ">>>>> LDA-MLLT: training"

    steps/train_lda_mllt.sh --cmd "$train_cmd" $numLeavesMLLT $numGaussMLLT  \
        $data_dir/train $data_dir/lang $data_dir/exp/tri1_ali $data_dir/exp/tri2 || exit 1

    utils/mkgraph.sh $data_dir/lang  $data_dir/exp/tri2 $data_dir/exp/tri2/graph || exit 1

    echo ">>>>> LDA-MLLT: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $data_dir/exp/tri2/graph  $data_dir/test $data_dir/exp/tri2/decode_test || exit 1
fi

#### Step 5 - LDA-MLLT + SAT ####

if [[ $step -eq 5 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                         tri3 : LDA-MLLT + SAT                            "
    echo ============================================================================

    echo ">>>>> LDA-MLLT: alignment"

    steps/align_si.sh --nj $nj --cmd "$decode_cmd" $data_dir/train $data_dir/lang $data_dir/exp/tri2 $data_dir/exp/tri2_ali || exit 1

    echo ">>>>> LDA-MLLT + SAT: training"

    steps/train_sat.sh --cmd "$train_cmd" $numLeavesSAT $numGaussSAT  \
        $data_dir/train $data_dir/lang $data_dir/exp/tri2_ali $data_dir/exp/tri3 || exit 1

    utils/mkgraph.sh $data_dir/lang  $data_dir/exp/tri3 $data_dir/exp/tri3/graph || exit 1

    echo ">>>>> LDA-MLLT + SAT: decoding"

    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" $data_dir/exp/tri3/graph  $data_dir/test $data_dir/exp/tri3/decode_test || exit 1
fi

#### Step 6 - SGMM2  ####

if [[ $step -eq 6 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                                 SGMM2                                    "
    echo ============================================================================

    echo ">>>>> LDA-MLLT + SAT: alignment"

    steps/align_fmllr.sh --nj $nj --cmd "$decode_cmd" $data_dir/train $data_dir/lang $data_dir/exp/tri3 $data_dir/exp/tri3_ali || exit 1

    echo ">>>>> SGMM2: training"

    steps/train_ubm.sh --cmd "$train_cmd" $numGaussUBM $data_dir/train $data_dir/lang $data_dir/exp/tri3_ali $data_dir/exp/ubm4 || exit 1

    steps/train_sgmm2.sh --cmd "$train_cmd" $numLeavesSGMM $numGaussSGMM \
        $data_dir/train $data_dir/lang $data_dir/exp/tri3_ali $data_dir/ubm4/final.ubm $data_dir/exp/sgmm2_4 || exit 1

    utils/mkgraph.sh $data_dir/lang $data_dir/exp/sgmm2_4 $data_dir/exp/sgmm2_4/graph || exit 1

    echo ">>>>> SGMM2: decoding"

    steps/decode_sgmm2.sh --nj $nj --cmd "$decode_cmd" --transform-dir \
        $data_dir/exp/tri3/decode_test $data_dir/exp/sgmm2_4/graph $data_dir/train $data_dir/exp/sgmm2_4/decode_test || exit 1
fi

#### score

for x in $output_dir/exp/*/decode*; do [[ -d $x ]] && grep WER $x/wer_* | utils/best_wer.sh; done
