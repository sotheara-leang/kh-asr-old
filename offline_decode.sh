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
exp_dir=$1
data_dir=$2
output_dir=$3
step=$4

if [[ -z $output_dir ]]; then
    output_dir=$PROJ_HOME/data/offline
fi

if [[ -z $step ]]; then
    step=-1
fi

#### Init output directory ####

if [[ $step -eq -1 ]]; then
    rm -rf $output_dir
    mkdir $output_dir
fi

# Init logging file

exec > >(tee -i $output_dir/log.txt)
exec 2>&1

#### Step 1 - Data preparation ####

if [[ $step -eq 1 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                          Data Preparation                                "
    echo ============================================================================

    python3 $PROJ_HOME/local/prepare_data.py --data_dir $data_dir --output_dir $output_dir/data --mode 2

    echo ">>>>> Extract MFCC features"

    steps/make_mfcc.sh --nj $nb_job --cmd "$decode_cmd" $output_dir/data $output_dir/make_mfcc $output_dir/mfcc
    steps/compute_cmvn_stats.sh $output_dir/data $output_dir/make_mfcc $output_dir/mfcc

    echo ">>>>> Validate data"
    {
        utils/validate_data_dir.sh $output_dir/data;
        utils/fix_data_dir.sh $output_dir/data;
    }
fi

#### Step 2 - Monophone ####

if [[ $step -eq 2 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                           Monophone Decoding                             "
    echo ============================================================================

    mkdir $output_dir/$mono_output_dir/

    cp $exp_dir/exp/$mono_output_dir/final.mdl $output_dir/$mono_output_dir/

    steps/decode.sh --nj $nb_job_decode --cmd "$decode_cmd" \
        $exp_dir/exp/$mono_output_dir/graph $output_dir/data $output_dir/$mono_output_dir/decode_test || exit 1
fi

#### Step 3 - Deltas ####

if [[ $step -eq 3 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                           tri1 : Deltas Decoding                         "
    echo ============================================================================

    mkdir $output_dir/$tri1_output_dir/

    cp $exp_dir/exp/$tri1_output_dir/final.mdl $output_dir/$tri1_output_dir/

    steps/decode.sh --nj $nb_job_decode --cmd "$decode_cmd" \
        $exp_dir/exp/$tri1_output_dir/graph $output_dir/data $output_dir/$tri1_output_dir/decode_test || exit 1
fi

#### Step 4 - Deltas + Deltas-Deltas ####

if [[ $step -eq 4 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                  tri2 : Deltas + Delta-Deltas Decoding                   "
    echo ============================================================================

    mkdir $output_dir/$tri2_output_dir/

    cp $exp_dir/exp/$tri2_output_dir/final.mdl $output_dir/$tri2_output_dir/

    steps/decode.sh --nj $nb_job_decode --cmd "$decode_cmd" \
        $exp_dir/exp/$tri2_output_dir/graph $output_dir/data $output_dir/$tri2_output_dir/decode_test || exit 1
fi

#### Step 5 - LDA-MLLT ####

if [[ $step -eq 5 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                         tri3 : LDA-MLLT Decoding                         "
    echo ============================================================================

    mkdir $output_dir/$mllt_output_dir/

    cp $exp_dir/exp/$mllt_output_dir/final.mdl $output_dir/$mllt_output_dir/
    cp $exp_dir/exp/$mllt_output_dir/final.mat $output_dir/$mllt_output_dir/

    steps/decode.sh --nj $nb_job_decode --cmd "$decode_cmd" \
        $exp_dir/exp/$mllt_output_dir/graph  $output_dir/data $output_dir/$mllt_output_dir/decode_test || exit 1
fi

#### Step 6 - LDA-MLLT + SAT ####

if [[ $step -eq 6 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                     tri4 : LDA-MLLT + SAT Decoding                       "
    echo ============================================================================

    mkdir $output_dir/$sat_output_dir/

    cp $exp_dir/exp/$sat_output_dir/final.mdl $output_dir/$sat_output_dir/
    cp $exp_dir/exp/$sat_output_dir/final.mat $output_dir/$sat_output_dir/
    cp $exp_dir/exp/$sat_output_dir/final.alimdl $output_dir/$sat_output_dir/

    steps/decode_fmllr.sh --nj $nb_job_decode --cmd "$decode_cmd" \
        $exp_dir/exp/$sat_output_dir/graph  $output_dir/data $output_dir/$sat_output_dir/decode_test || exit 1
fi

#### Step 7 - SGMM2  ####

if [[ $step -eq 7 ]] || [[ $step -eq -1 ]]; then

    echo ============================================================================
    echo "                              SGMM2 Decoding                              "
    echo ============================================================================

    mkdir $output_dir/$sgmm2_output_dir/

    cp $exp_dir/exp/$sgmm2_output_dir/final.mdl $output_dir/$sgmm2_output_dir/
    cp $exp_dir/exp/$sgmm2_output_dir/final.mat $output_dir/$sgmm2_output_dir/
    cp $exp_dir/exp/$sgmm2_output_dir/final.alimdl $output_dir/$sgmm2_output_dir/

    steps/decode_sgmm2.sh --nj $nb_job_decode --cmd "$decode_cmd" --transform-dir \
        $exp_dir/exp/$sat_output_dir/decode $exp_dir/$sgmm2_output_dir/graph \
        $output_dir/data $output_dir/$sgmm2_output_dir/decode_test || exit 1
fi

#### score

for x in $output_dir/*/decode*; do [[ -d $x ]] && grep WER $x/wer_* | utils/best_wer.sh; done
