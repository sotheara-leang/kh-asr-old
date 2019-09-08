#!/bin/bash

if [[ -z ${PROJ_HOME} ]]; then
    echo "Error - PROJ_HOME is undefine"
    exit 1
fi

# initialization PATH
. $PROJ_HOME/local/init_env.sh 

# initialization commands
. $PROJ_HOME/cmd.sh 

# parameters
data_dir=$1
output_dir=$2
step=$3
nj=$4

if [[ -z $exp_dir ]]; then
    exp_dir=data
fi

if [[ -z $step ]]; then
    step=-1
fi

if [[ -z $nj ]]; then
    nj=5
fi

exp_dir=$output_dir/exp

# load configuration
. $PROJ_HOME/conf/main.conf

#### Step 1 - Data preparation ####

if [[ $step -eq 1 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                          Data Preparation                                "
    echo ============================================================================

    python3 $PROJ_HOME/local/prepare_data.py --data_dir $data_dir --output_dir $output_dir --test_ratio $test_set_ratio

    echo ">>>>> Prepare dictionary"

    $PROJ_HOME/local/prepare_dict.sh $output_dir

    echo ">>>>> Prepare language model"

    $PROJ_HOME/local/prepare_lm.sh $data_dir $output_dir $lm_order

    echo ">>>>> Validate data"
    
    utils/validate_data_dir.sh $output_dir/train
    utils/fix_data_dir.sh $output_dir/train

    if [[ -d $output_dir/test ]]; then
        utils/validate_data_dir.sh $output_dir/test
        utils/fix_data_dir.sh $output_dir/test
    fi
    
    echo ">>>>> Extract MFCC features"

    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $output_dir/train $exp_dir/make_mfcc/train $exp_dir/mfcc/train
    steps/compute_cmvn_stats.sh $output_dir/train $exp_dir/make_mfcc/train $exp_dir/mfcc/train

    if [[ -d $exp_dir/test ]]; then
        steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $output_dir/test $exp_dir/make_mfcc/test $exp_dir/mfcc/test
        steps/compute_cmvn_stats.sh $output_dir/test $exp_dir/make_mfcc/test $exp_dir/mfcc/test
    fi
fi

#### Step 2 - Monophone ####

if [[ $step -eq 2 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                          mono : Monophone                                "
    echo ============================================================================

    out_dir=$exp_dir/$mono_output_dir

    echo ">>>>> Monophone: training"

    steps/train_mono.sh --nj $nj --cmd "$train_cmd" $output_dir/train $output_dir/lang $out_dir

    utils/mkgraph.sh $output_dir/lang $out_dir $out_dir/graph

    echo ">>>>> Monophone: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $out_dir/graph $output_dir/test $out_dir/decode_test
fi

#### Step 3 - Deltas ####

if [[ $step -eq 3 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                                tri1 : Deltas                             "
    echo ============================================================================

    out_dir=$exp_dir/$tri1_output_dir

    echo ">>>>> Monophone: alignment"

    steps/align_si.sh --nj $nj  --cmd "$align_cmd" \
        $output_dir/train $output_dir/lang $exp_dir/$mono_output_dir $exp_dir/${mono_output_dir}_ali

    echo ">>>>> Deltas: training"

    steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25  $tri1_num_leaves $tri1_num_gauss  \
        $output_dir/train $output_dir/lang $exp_dir/${mono_output_dir}_ali $out_dir

    utils/mkgraph.sh $output_dir/lang $out_dir $out_dir/graph

    echo ">>>>> Deltas: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $out_dir/graph $output_dir/test $out_dir/decode_test
fi

#### Step 4 - Deltas + Deltas-Deltas ####

if [[ $step -eq 4 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                      tri2 : Deltas + Delta-Deltas                        "
    echo ============================================================================

    out_dir=$exp_dir/$tri2_output_dir

    echo ">>>>> Deltas: alignment"

    steps/align_si.sh --nj $nj  --cmd "$align_cmd" --use-graphs true \
        $output_dir/train $output_dir/lang $exp_dir/$tri1_output_dir $exp_dir/${tri1_output_dir}_ali

    echo ">>>>> Deltas + Delta-Deltas: training"

    steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25  $tri2_num_leaves $tri2_num_gauss  \
        $output_dir/train $output_dir/lang $exp_dir/${tri1_output_dir}_ali $out_dir

    utils/mkgraph.sh $output_dir/lang $out_dir $out_dir/graph

    echo ">>>>> Deltas + Delta-Deltas: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $out_dir/graph $output_dir/test $out_dir/decode_test
fi

#### Step 5 - LDA-MLLT ####

if [[ $step -eq 5 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                             tri3 : LDA-MLLT                              "
    echo ============================================================================

    out_dir=$exp_dir/$mllt_output_dir

    echo ">>>>> Deltas + Delta-Deltas: alignment"

    steps/align_si.sh --nj $nj --cmd "$align_cmd" $output_dir/train $output_dir/lang \
        $exp_dir/$tri2_output_dir $exp_dir/${tri2_output_dir}_ali

    echo ">>>>> LDA-MLLT: training"

    steps/train_lda_mllt.sh --cmd "$train_cmd" $mllt_num_leaves $mllt_num_gauss  \
        $output_dir/train $output_dir/lang $exp_dir/${tri2_output_dir}_ali $out_dir

    utils/mkgraph.sh $output_dir/lang  $out_dir $out_dir/graph

    echo ">>>>> LDA-MLLT: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $out_dir/graph  $output_dir/test $out_dir/decode_test
fi

#### Step 6 - LDA-MLLT + SAT ####

if [[ $step -eq 6 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                         tri4 : LDA-MLLT + SAT                            "
    echo ============================================================================

    out_dir=$exp_dir/$sat_output_dir

    echo ">>>>> LDA-MLLT: alignment"

    steps/align_si.sh --nj $nj --cmd "$align_cmd" --use-graphs true $output_dir/train $output_dir/lang \
        $exp_dir/$mllt_output_dir $exp_dir/${mllt_output_dir}_ali

    echo ">>>>> LDA-MLLT + SAT: training"

    steps/train_sat.sh --cmd "$train_cmd" $sat_num_leaves $sat_num_gauss  \
        $output_dir/train $output_dir/lang $exp_dir/${mllt_output_dir}_ali $out_dir

    utils/mkgraph.sh $output_dir/lang  $out_dir $out_dir/graph

    echo ">>>>> LDA-MLLT + SAT: decoding"

    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" $out_dir/graph  $output_dir/test $out_dir/decode_test
fi

#### Step 7 - SGMM2  ####

if [[ $step -eq 7 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                                 SGMM2                                    "
    echo ============================================================================

    echo ">>>>> LDA-MLLT + SAT: alignment"

    out_dir=$exp_dir/$sgmm2_output_dir

    steps/align_fmllr.sh --nj $nj --cmd "$align_cmd" $output_dir/train $output_dir/lang \
        $exp_dir/$sat_output_dir $exp_dir/${sat_output_dir}_ali

    echo ">>>>> SGMM2: training"

    steps/train_ubm.sh --cmd "$train_cmd" $sgmm2_ubm_num_gauss \
        $output_dir/train $output_dir/lang $exp_dir/${sat_output_dir}_ali $exp_dir/$sgmm2_ubm_output_dir

    steps/train_sgmm2.sh --cmd "$train_cmd" $sgmm2_num_leaves $sgmm2_num_gauss \
        $output_dir/train $output_dir/lang $exp_dir/${sat_output_dir}_ali $exp_dir/$sgmm2_ubm_output_dir/final.ubm $out_dir

    utils/mkgraph.sh $output_dir/lang $out_dir $out_dir/graph

    echo ">>>>> SGMM2: decoding"

    steps/decode_sgmm2.sh --nj $nj --cmd "$decode_cmd" --transform-dir \
        $exp_dir/$sat_output_dir/decode_test $out_dir/graph $output_dir/test $out_dir/decode_test
fi

#### score

for x in $exp_dir/*/decode*; do [[ -d $x ]] && grep WER $x/wer_* | utils/best_wer.sh; done
