#!/bin/bash

# initialization PATH
. ./local/init_env.sh || exit 1

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
. $PROJ_HOME/conf/main.conf

#### Step 1 - Data preparation ####

if [[ $step -eq 1 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                          Data Preparation                                "
    echo ============================================================================

    echo ">>>>> Prepare dictionary"

    utils/prepare_lang.sh $data_dir/local/dict "<UNK>" $data_dir/local/lang $data_dir/lang || exit 1

    echo ">>>>> Prepare language model"

    lang=$data_dir/lang
    [[ ! -d $lang ]] && mkdir $lang

    arpa2fst --disambig-symbol=#0 $data_dir/lm/lm.arpa $lang/G.fst

    echo ">>>>> Extract MFCC features"

    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $data_dir/train $output_dir/make_mfcc/train $output_dir/mfcc/train
    steps/compute_cmvn_stats.sh $data_dir/train $output_dir/make_mfcc/train $output_dir/mfcc/train

    if [[ -d $data_dir/test ]]; then
        steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $data_dir/test $output_dir/make_mfcc/test $output_dir/mfcc/test
        steps/compute_cmvn_stats.sh $data_dir/test $output_dir/make_mfcc/test $output_dir/mfcc/test
    fi

    echo ">>>>> Validate data"

    utils/validate_data_dir.sh $data_dir/train
    utils/fix_data_dir.sh $data_dir/train

    if [[ -d $data_dir/test ]]; then
        utils/validate_data_dir.sh $data_dir/test
        utils/fix_data_dir.sh $data_dir/test
    fi
fi

#### Step 2 - Monophone ####

if [[ $step -eq 2 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                          mono : Monophone                                "
    echo ============================================================================

    out_dir=$output_dir/$mono_output_dir

    echo ">>>>> Monophone: training"

    steps/train_mono.sh --nj $nj --cmd "$train_cmd" $data_dir/train $data_dir/lang $out_dir || exit 1

    utils/mkgraph.sh $data_dir/lang $out_dir $out_dir/graph || exit 1

    echo ">>>>> Monophone: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $out_dir/graph $data_dir/test $out_dir/decode_test || exit 1
fi

#### Step 3 - Deltas ####

if [[ $step -eq 3 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                                tri1 : Deltas                             "
    echo ============================================================================

    out_dir=$output_dir/$tri1_output_dir

    echo ">>>>> Monophone: alignment"

    steps/align_si.sh --boost-silence 1.25 --nj $nj  --cmd "$train_cmd" \
        $data_dir/train $data_dir/lang $output_dir/$mono_output_dir $output_dir/${mono_output_dir}_ali || exit 1

    echo ">>>>> Deltas: training"

    steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25  $tri1_num_leaves $tri1_num_gauss  \
        $data_dir/train $data_dir/lang $output_dir/${mono_output_dir}_ali $out_dir || exit 1

    utils/mkgraph.sh $data_dir/lang $out_dir $out_dir/graph

    echo ">>>>> Deltas: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $out_dir/graph $data_dir/test $out_dir/decode_test || exit 1
fi

#### Step 4 - Deltas + Deltas-Deltas ####

if [[ $step -eq 4 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                      tri2 : Deltas + Delta-Deltas                        "
    echo ============================================================================

    out_dir=$output_dir/$tri2_output_dir

    echo ">>>>> Deltas: alignment"

    steps/align_si.sh --boost-silence 1.25 --nj $nj  --cmd "$train_cmd" \
        $data_dir/train $data_dir/lang $output_dir/$tri1_output_dir $output_dir/${tri1_output_dir}_ali || exit 1

    echo ">>>>> Deltas + Delta-Deltas: training"

    steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25  $tri2_num_leaves $tri2_num_gauss  \
        $data_dir/train $data_dir/lang $output_dir/${tri1_output_dir}_ali $out_dir || exit 1

    utils/mkgraph.sh $data_dir/lang $out_dir $out_dir/graph

    echo ">>>>> Deltas + Delta-Deltas: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $out_dir/graph $data_dir/test $out_dir/decode_test || exit 1
fi

#### Step 5 - LDA-MLLT ####

if [[ $step -eq 5 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                             tri3 : LDA-MLLT                              "
    echo ============================================================================

    out_dir=$output_dir/$mllt_output_dir

    echo ">>>>> Deltas + Delta-Deltas: alignment"

    steps/align_si.sh --nj $nj --cmd "$decode_cmd" $data_dir/train $data_dir/lang \
        $output_dir/$tri2_output_dir $output_dir/${tri2_output_dir}_ali || exit 1

    echo ">>>>> LDA-MLLT: training"

    steps/train_lda_mllt.sh --cmd "$train_cmd" $mllt_num_leaves $mllt_num_gauss  \
        $data_dir/train $data_dir/lang $output_dir/${tri2_output_dir}_ali $out_dir || exit 1

    utils/mkgraph.sh $data_dir/lang  $out_dir $out_dir/graph || exit 1

    echo ">>>>> LDA-MLLT: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $out_dir/graph  $data_dir/test $out_dir/decode_test || exit 1
fi

#### Step 6 - LDA-MLLT + SAT ####

if [[ $step -eq 6 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                         tri4 : LDA-MLLT + SAT                            "
    echo ============================================================================

    out_dir=$output_dir/$sat_output_dir

    echo ">>>>> LDA-MLLT: alignment"

    steps/align_si.sh --nj $nj --cmd "$decode_cmd" $data_dir/train $data_dir/lang \
        $output_dir/$mllt_output_dir $output_dir/${mllt_output_dir}_ali || exit 1

    echo ">>>>> LDA-MLLT + SAT: training"

    steps/train_sat.sh --cmd "$train_cmd" $sat_num_leaves $sat_num_gauss  \
        $data_dir/train $data_dir/lang $output_dir/${mllt_output_dir}_ali $out_dir || exit 1

    utils/mkgraph.sh $data_dir/lang  $out_dir $out_dir/graph || exit 1

    echo ">>>>> LDA-MLLT + SAT: decoding"

    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" $out_dir/graph  $data_dir/test $out_dir/decode_test || exit 1
fi

#### Step 7 - SGMM2  ####

if [[ $step -eq 7 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                                 SGMM2                                    "
    echo ============================================================================

    echo ">>>>> LDA-MLLT + SAT: alignment"

    out_dir=$output_dir/$sgmm2_output_dir

    steps/align_fmllr.sh --nj $nj --cmd "$decode_cmd" $data_dir/train $data_dir/lang \
        $output_dir/$sat_output_dir $output_dir/${sat_output_dir}_ali || exit 1

    echo ">>>>> SGMM2: training"

    steps/train_ubm.sh --cmd "$train_cmd" $sgmm2_ubm_num_gauss \
        $data_dir/train $data_dir/lang $output_dir/${sat_output_dir}_ali $output_dir/$sgmm2_ubm_output_dir || exit 1

    steps/train_sgmm2.sh --cmd "$train_cmd" $sgmm2_num_leaves $sgmm2_num_gauss \
        $data_dir/train $data_dir/lang $output_dir/${sat_output_dir}_ali $output_dir/$sgmm2_ubm_output_dir/final.ubm $out_dir || exit 1

    utils/mkgraph.sh $data_dir/lang $out_dir $out_dir/graph || exit 1

    echo ">>>>> SGMM2: decoding"

    steps/decode_sgmm2.sh --nj $nj --cmd "$decode_cmd" --transform-dir \
        $output_dir/$sat_output_dir/decode_test $out_dir/graph $output_dir/train $out_dir/decode_test || exit 1
fi

#### score

for x in $output_dir/*/decode*; do [[ -d $x ]] && grep WER $x/wer_* | utils/best_wer.sh; done
