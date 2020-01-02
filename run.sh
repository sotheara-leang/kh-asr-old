#!/bin/bash

if [[ -z ${PROJ_HOME} ]]; then
    echo "Error - PROJ_HOME is undefined"
    exit 1
fi

# load configuration
. $PROJ_HOME/conf/main.conf

# initialization PATH
. $PROJ_HOME/local/init_env.sh 

# initialization commands
. $PROJ_HOME/cmd.sh 

# parameters
data_dir=$1
output_dir=$2
step=$3

if [[ -z $exp_dir ]]; then
    exp_dir=data
fi

if [[ -z $step ]]; then
    step=-1
fi

exp_dir=$output_dir/exp

#### Init output directory ####

if [[ $step -eq -1 ]]; then
    rm -rf $output_dir
    mkdir $output_dir
    mkdir $exp_dir
fi

# Init logging file

exec > >(tee -i $output_dir/exp/log.txt)
exec 2>&1

#### Step 1 - Data preparation ####

if [[ $step -eq 1 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                          Data Preparation                                "
    echo ============================================================================

    echo ">>>>> Prepare dictionary"

    local/prepare_dict.sh $output_dir

    utils/prepare_lang.sh $output_dir/local/dict "<unk>" $output_dir/local/lang $output_dir/lang

    echo ">>>>> Prepare language model"

    local/prepare_lm.sh $data_dir $output_dir $lm_order

    python3 $PROJ_HOME/local/prepare_data.py --data_dir $data_dir --output_dir $output_dir --test_ratio $test_set_ratio

    echo ">>>>> Extract MFCC features"

    steps/make_mfcc.sh --nj $nb_job --cmd "$train_cmd" $output_dir/train $exp_dir/make_mfcc/train $exp_dir/mfcc/train || exit 1
    steps/compute_cmvn_stats.sh $output_dir/train $exp_dir/make_mfcc/train $exp_dir/mfcc/train || exit 1

    steps/make_mfcc.sh --nj $nb_job --cmd "$train_cmd" $output_dir/test $exp_dir/make_mfcc/test $exp_dir/mfcc/test || exit 1
    steps/compute_cmvn_stats.sh $output_dir/test $exp_dir/make_mfcc/test $exp_dir/mfcc/test || exit 1

    echo ">>>>> Validate data"

    {
        utils/validate_data_dir.sh $output_dir/train;
        utils/validate_data_dir.sh $output_dir/test;

        utils/fix_data_dir.sh $output_dir/train;
        utils/fix_data_dir.sh $output_dir/test
    }
fi

#### Step 2 - Monophone ####

if [[ $step -eq 2 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                          mono : Monophone                                "
    echo ============================================================================

    echo ">>>>> Monophone: training"

    utils/subset_data_dir.sh $output_dir/train $mono_num_examples $output_dir/train.mono || exit 1

    steps/train_mono.sh --nj $nb_job --cmd "$train_cmd" $output_dir/train.mono $output_dir/lang $exp_dir/$mono_output_dir || exit 1

    utils/mkgraph.sh $output_dir/lang $exp_dir/$mono_output_dir $exp_dir/$mono_output_dir/graph || exit 1

    echo ">>>>> Monophone: decoding"

    steps/decode.sh --nj $nb_job_decode --cmd "$decode_cmd" \
        $exp_dir/$mono_output_dir/graph $output_dir/test $exp_dir/$mono_output_dir/decode_test || exit 1
fi

#### Step 3 - Deltas ####

if [[ $step -eq 3 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                                tri1 : Deltas                             "
    echo ============================================================================

    echo ">>>>> Monophone: alignment"

    steps/align_si.sh --nj $nb_job  --cmd "$align_cmd" \
        $output_dir/train $output_dir/lang $exp_dir/$mono_output_dir $exp_dir/${mono_output_dir}_ali || exit 1

    echo ">>>>> Deltas: training"

    steps/train_deltas.sh --cmd "$train_cmd" $tri1_num_leaves $tri1_num_gauss  \
        $output_dir/train $output_dir/lang $exp_dir/${mono_output_dir}_ali $exp_dir/$tri1_output_dir || exit 1

    utils/mkgraph.sh $output_dir/lang $exp_dir/$tri1_output_dir $exp_dir/$tri1_output_dir/graph || exit 1

    echo ">>>>> Deltas: decoding"

    steps/decode.sh --nj $nb_job_decode --cmd "$decode_cmd" \
        $exp_dir/$tri1_output_dir/graph $output_dir/test $exp_dir/$tri1_output_dir/decode_test || exit 1
fi

#### Step 4 - Deltas + Deltas-Deltas ####

if [[ $step -eq 4 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                      tri2 : Deltas + Delta-Deltas                        "
    echo ============================================================================

    echo ">>>>> Deltas: alignment"

    steps/align_si.sh --nj $nb_job  --cmd "$align_cmd" \
        $output_dir/train $output_dir/lang $exp_dir/$tri1_output_dir $exp_dir/${tri1_output_dir}_ali || exit 1

    echo ">>>>> Deltas + Delta-Deltas: training"

    steps/train_deltas.sh --cmd "$train_cmd" $tri2_num_leaves $tri2_num_gauss  \
        $output_dir/train $output_dir/lang $exp_dir/${tri1_output_dir}_ali $exp_dir/$tri2_output_dir || exit 1

    utils/mkgraph.sh $output_dir/lang $exp_dir/$tri2_output_dir $exp_dir/$tri2_output_dir/graph || exit 1

    echo ">>>>> Deltas + Delta-Deltas: decoding"

    steps/decode.sh --nj $nb_job_decode --cmd "$decode_cmd" \
        $exp_dir/$tri2_output_dir/graph $output_dir/test $exp_dir/$tri2_output_dir/decode_test || exit 1
fi

#### Step 5 - LDA-MLLT ####

if [[ $step -eq 5 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                             tri3 : LDA-MLLT                              "
    echo ============================================================================

    echo ">>>>> Deltas + Delta-Deltas: alignment"

    steps/align_si.sh --nj $nb_job --cmd "$align_cmd" $output_dir/train $output_dir/lang \
        $exp_dir/$tri2_output_dir $exp_dir/${tri2_output_dir}_ali || exit 1

    echo ">>>>> LDA-MLLT: training"

    steps/train_lda_mllt.sh --cmd "$train_cmd" $mllt_num_leaves $mllt_num_gauss  \
        $output_dir/train $output_dir/lang $exp_dir/${tri2_output_dir}_ali $exp_dir/$mllt_output_dir || exit 1

    utils/mkgraph.sh $output_dir/lang  $exp_dir/$mllt_output_dir $exp_dir/$mllt_output_dir/graph || exit 1

    echo ">>>>> LDA-MLLT: decoding"

    steps/decode.sh --nj $nb_job_decode --cmd "$decode_cmd" \
        $exp_dir/$mllt_output_dir/graph  $output_dir/test $exp_dir/$mllt_output_dir/decode_test || exit 1
fi

#### Step 6 - LDA-MLLT + SAT ####

if [[ $step -eq 6 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                         tri4 : LDA-MLLT + SAT                            "
    echo ============================================================================

    echo ">>>>> LDA-MLLT: alignment"

    steps/align_fmllr.sh --nj $nb_job --cmd "$align_cmd" $output_dir/train $output_dir/lang \
        $exp_dir/$mllt_output_dir $exp_dir/${mllt_output_dir}_ali || exit 1

    echo ">>>>> LDA-MLLT + SAT: training"

    steps/train_sat.sh --cmd "$train_cmd" $sat_num_leaves $sat_num_gauss  \
        $output_dir/train $output_dir/lang $exp_dir/${mllt_output_dir}_ali $exp_dir/$sat_output_dir || exit 1

    utils/mkgraph.sh $output_dir/lang  $exp_dir/$sat_output_dir $exp_dir/$sat_output_dir/graph || exit 1

    echo ">>>>> LDA-MLLT + SAT: decoding"

    steps/decode_fmllr.sh --nj $nb_job_decode --cmd "$decode_cmd" \
        $exp_dir/$sat_output_dir/graph  $output_dir/test $exp_dir/$sat_output_dir/decode_test || exit 1
fi

#### Step 7 - SGMM2  ####

if [[ $step -eq 7 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                                 SGMM2                                    "
    echo ============================================================================

    echo ">>>>> LDA-MLLT + SAT: alignment"

    steps/align_fmllr.sh --nj $nb_job --cmd "$align_cmd" $output_dir/train $output_dir/lang \
        $exp_dir/$sat_output_dir $exp_dir/${sat_output_dir}_ali || exit 1

    echo ">>>>> SGMM2: training"

    steps/train_ubm.sh --cmd "$train_cmd" $sgmm2_ubm_num_gauss \
        $output_dir/train $output_dir/lang $exp_dir/${sat_output_dir}_ali $exp_dir/$sgmm2_ubm_output_dir || exit 1

    steps/train_sgmm2.sh --cmd "$train_cmd" $sgmm2_num_leaves $sgmm2_num_gauss \
        $output_dir/train $output_dir/lang $exp_dir/${sat_output_dir}_ali \
        $exp_dir/$sgmm2_ubm_output_dir/final.ubm $exp_dir/$sgmm2_output_dir || exit 1

    utils/mkgraph.sh $output_dir/lang $exp_dir/$sgmm2_output_dir $exp_dir/$sgmm2_output_dir/graph || exit 1

    echo ">>>>> SGMM2: decoding"

    steps/decode_sgmm2.sh --nj $nb_job_decode --cmd "$decode_cmd" --transform-dir \
        $exp_dir/$sat_output_dir/decode_test $exp_dir/$sgmm2_output_dir/graph \
        $output_dir/test $exp_dir/$sgmm2_output_dir/decode_test || exit 1
fi

#### score

for x in $exp_dir/*/decode*; do [[ -d $x ]] && grep WER $x/wer_* | utils/best_wer.sh; done
