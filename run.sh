#!/bin/bash

log(){
    echo $1
}

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

    log ">>>>> Validation data"

    utils/validate_data_dir.sh --no-feats $data_dir/train
    utils/fix_data_dir.sh $data_dir/train

    utils/validate_data_dir.sh --no-feats $data_dir/test
    utils/fix_data_dir.sh $data_dir/test

    log ">>>>> Preparing dictionary"

    utils/prepare_lang.sh $data_dir/local/dict "<UNK>" $data_dir/local/lang $data_dir/lang || exit 1

    log ">>>>> Preparing language model"

    lang=$data_dir/lang
    [[ ! -d $lang ]] && mkdir $lang

    arpa2fst --disambig-symbol=#0 $data_dir/lm/lm.arpa $lang/G.fst

    log ">>>>> Extracting MFCC features"

    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $data_dir/train $output_dir/make_mfcc/train $output_dir/mfcc/train
    steps/compute_cmvn_stats.sh $data_dir/train $output_dir/make_mfcc/train $output_dir/mfcc/train

    if [[ -d $data_dir/test ]]; then
        steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $data_dir/test $output_dir/make_mfcc/test $output_dir/mfcc/test
        steps/compute_cmvn_stats.sh $data_dir/test $output_dir/make_mfcc/test $output_dir/mfcc/test
    fi
fi

#### Stage 2 - Monophone training ####

if [[ $step -eq 2 ]] || [[ $step -eq -1 ]]; then

    log ">>>>> Monophone: training"

    steps/train_mono.sh --boost-silence 1.25  --nj $nj --cmd "$train_cmd" $data_dir/train $data_dir/lang $data_dir/exp/mono || exit 1

    # graph compilation
    utils/mkgraph.sh --mono $data_dir/lang $data_dir/exp/mono $data_dir/exp/mono/graph || exit 1

    echo ">>>>> Monophone: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $data_dir/exp/mono/graph $data_dir/test $data_dir/exp/mono/decode_test || exit 1
fi

#### Stage 3 - Triphone - Delta training ####

if [[ $step -eq 3 ]] || [[ $step -eq -1 ]]; then

    echo ">>>>> Monophone: aligment"

    steps/align_si.sh --boost-silence 1.25 --nj $nj  --cmd "$train_cmd" $data_dir/train $data_dir/lang $data_dir/exp/mono $data_dir/exp/mono_ali || exit 1

    log ">>>>> Triphone - Delta: training"

    steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25  4200 40000  $data_dir/train $data_dir/lang $data_dir/exp/mono_ali $data_dir/exp/tri1 || exit 1

    # graph compilation
    utils/mkgraph.sh $data_dir/lang $data_dir/exp/tri1 $data_dir/exp/tri1/graph

    echo ">>>>> Triphone - Delta: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $data_dir/exp/tri1/graph  $data_dir/test $data_dir/exp/tri1/decode_test || exit 1
fi

#### Stage 4 - Triphone - Delta + Delta-Delta training ####

if [[ $step -eq 4 ]] || [[ $step -eq -1 ]]; then

    echo ">>>>> Triphone - Delta: aligment"

    steps/align_si.sh --boost-silence 1.25 --nj $nj --cmd "$train_cmd" $data_dir/train $data_dir/lang $data_dir/exp/tri1 $data_dir/exp/tri1_ali || exit 1

    log ">>>>> Triphone - Delta + Delta-Delta: training"

    steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25  4200 40000  $data_dir/train $data_dir/lang $data_dir/exp/tri1_ali $data_dir/exp/tri2a || exit 1

    # graph compilation
    utils/mkgraph.sh $data_dir/lang  $data_dir/exp/tri2a $data_dir/exp/tri2a/graph || exit 1

    echo ">>>>> Triphone - Delta + Delta-Delta: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $data_dir/exp/tri2a/graph  $data_dir/test $data_dir/exp/tri2a/decode_test || exit 1
fi

#### Stage 5 - Triphone - LDA-MLLT training ####

if [[ $step -eq 5 ]] || [[ $step -eq -1 ]]; then

    echo ">>>>> Triphone - Delta + Delta-Delta: aligment"

    steps/align_si.sh --boost-silence 1.25 --nj $nj --cmd "$decode_cmd" $data_dir/train $data_dir/lang $data_dir/exp/tri2a $data_dir/exp/tri2a_ali || exit 1

    log ">>>>> Triphone - LDA-MLLT: training"

    steps/train_lda_mllt.sh --cmd "$train_cmd" --boost-silence 1.25  4200 40000  $data_dir/train $data_dir/lang $data_dir/exp/tri2a_ali $data_dir/exp/tri2b || exit 1

    # graph compilation
    utils/mkgraph.sh $data_dir/lang  $data_dir/exp/tri2b $data_dir/exp/tri2b/graph || exit 1

    echo ">>>>> Triphone - LDA-MLLT: decoding"

    steps/decode.sh --nj $nj --cmd "$decode_cmd" $data_dir/exp/tri2b/graph  $data_dir/test $data_dir/exp/tri2b/decode_test || exit 1
fi

#### score

for x in $output_dir/exp/*/decode*; do [[ -d $x ]] && grep WER $x/wer_* | utils/best_wer.sh; done
