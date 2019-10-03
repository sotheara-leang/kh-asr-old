#!/usr/bin/env bash

. $PROJ_HOME/conf/decode_sgmm2.conf

. $PROJ_HOME/local/init_env.sh

model_dir=$1
wav_dir=$2
output_file=$3

if [[ -z $output_file ]]; then
    output_file=$wav_dir/trans.txt
fi

decode_dir=$(mktemp -d -t ci-XXXXXXXXXX)

mkdir -p $decode_dir

for f in $wav_dir/*.wav; do
    bf=`basename $f`
    bf=${bf%.wav}
    echo $bf $f >> $decode_dir/wav.scp
done

compute-mfcc-feats --config=$PROJ_HOME/conf/mfcc.conf \
    scp:$decode_dir/wav.scp \
    ark,scp:$decode_dir/feats.ark,$decode_dir/feats.scp || exit 1

compute-cmvn-stats scp:$decode_dir/feats.scp ark,scp:$decode_dir/cmvn.ark,$decode_dir/cmvn.scp || exit 1

cmvn_opts=`cat $decode_dir/cmvn_opts 2>/dev/null`

splice_opts=`cat $decode_dir/splice_opts 2>/dev/null`

apply-cmvn $cmvn_opts scp:$decode_dir/cmvn.scp scp:$decode_dir/feats.scp ark:- \
    | splice-feats $splice_opts ark:- ark:- \
    | transform-feats $model_dir/final.mat ark:- ark:- > $decode_dir/normalized_feats.scp || exit 1

sgmm2-gselect --full-gmm-nbest=15 $model_dir/final.mdl \
    ark,t:$decode_dir/normalized_feats.scp "ark:|gzip -c > $decode_dir/gselect.gz" || exit 1;

gselect="--gselect=ark,s,cs:gunzip -c $decode_dir/gselect.gz| copy-gselect --n=3 ark:- ark:- |"

sgmm2-latgen-faster "$gselect" --max-active=$max_active --beam=$beam --lattice-beam=$lattice_beam \
    --acoustic-scale=$acoustic_scale --determinize-lattice=$determinize_lattice --allow-partial=$allow_partial \
    --word-symbol-table=$model_dir/words.txt \
    $model_dir/final.alimdl $model_dir/HCLG.fst \
    ark,t:$decode_dir/normalized_feats.scp ark,t:$decode_dir/lattices.ark ark,t:$decode_dir/trans.txt || exit 1

$PROJ_HOME/utils/int2sym.pl -f 2- $model_dir/words.txt $decode_dir/trans.txt > $output_file || exit 1

rm -rf $decode_dir