#!/usr/bin/env bash

. $PROJ_HOME/conf/decode.conf

. $PROJ_HOME/local/init_env.sh

model_dir=$1
wav_dir=$2
decode_dir=$3

if [[ -z $decode_dir ]]; then
    decode_dir='./work'
fi

mkdir -p $decode_dir

> $decode_dir/input.scp

for f in $wav_dir/*.wav; do
    bf=`basename $f`
    bf=${bf%.wav}
    echo $bf $f >> $decode_dir/input.scp
done

if [[ -f $model_dir/final.mat ]]; then
    online-wav-gmm-decode-faster --verbose=$verbose --rt-min=$rt_min --rt-max=$rt_max \
    --max-active=$max_active --beam=$beam --acoustic-scale=$acoustic_scale \
    scp:$decode_dir/input.scp $model_dir/final.mdl $model_dir/HCLG.fst \
    $model_dir/words.txt $silence_phones ark,t:$decode_dir/trans.txt \
    ark,t:$decode_dir/ali.txt $model_dir/final.mat
else
    online-wav-gmm-decode-faster --verbose=$verbose --rt-min=$rt_min --rt-max=$rt_max \
    --max-active=$max_active --beam=$beam --acoustic-scale=$acoustic_scale \
    scp:$decode_dir/input.scp $model_dir/final.mdl $model_dir/HCLG.fst \
    $model_dir/words.txt $silence_phones ark,t:$decode_dir/trans.txt \
    ark,t:$decode_dir/ali.txt
fi

$PROJ_HOME/utils/int2sym.pl -f 2- $model_dir/words.txt $decode_dir/trans.txt > $wav_dir/trans.txt
