#!/usr/bin/env bash

. $PROJ_HOME/local/init_env.sh || exit 1

data_dir=$1
output_dir=$2
lm_order=$3

if [[ -z $output_dir ]]; then
    output_dir=data/exp
fi

if [[ -z $lm_order ]]; then
    lm_order=1
fi

word_file=$output_dir/lang/words.txt
if [[ ! -f $word_file ]]; then
    echo "$output_dir/lang/words.txt not found"
    exit 1
fi

loc=`which ngram-count`;
if [[ -z $loc ]]; then
        if uname -a | grep 64 >/dev/null; then
            sdir=$KALDI_ROOT/tools/srilm/bin/i686-m64
        else
            sdir=$KALDI_ROOT/tools/srilm/bin/i686
        fi
        if [[ -f $sdir/ngram-count ]]; then
            echo "Using SRILM language modelling tool from $sdir"
            export PATH=$PATH:$sdir
        else
            echo "SRILM toolkit is probably not installed. Instructions: tools/install_srilm.sh"
            exit 1
        fi
fi

[[ ! -d $output_dir/lm ]] && mkdir $output_dir/lm/

sort $word_file | awk '{print $1}' | grep -v '\#0' | grep -v '<eps>' | grep -v -F "<unk>" > $output_dir/lm/vocab.txt

ngram-count -order $lm_order -gt1min 1 -gt2min 1 -gt3min 1 -wbdiscount -interpolate -vocab $output_dir/lm/vocab.txt \
    -write-vocab $output_dir/lm/vocab.txt -text $data_dir/corpus.txt -lm $output_dir/lm/lm.arpa

ngram -lm $output_dir/lm/lm.arpa -prune 1e-8 -write-lm $output_dir/lm/lm.arpa

cat $output_dir/lm/lm.arpa | $PROJ_HOME/utils/find_arpa_oovs.pl $output_dir/lang/words.txt  > $output_dir/lang/oovs.txt

cat $output_dir/lm/lm.arpa |    \
    grep -v '<s> <s>' | \
    grep -v '</s> <s>' | \
    grep -v '</s> </s>' | \
    arpa2fst - | fstprint | \
    $PROJ_HOME/utils/remove_oovs.pl $output_dir/lang/oovs.txt | \
    $PROJ_HOME/utils/eps2disambig.pl | $PROJ_HOME/utils/s2eps.pl | fstcompile --isymbols=$output_dir/lang/words.txt \
        --osymbols=$output_dir/lang/words.txt  --keep_isymbols=false --keep_osymbols=false | \
    fstrmepsilon | fstarcsort --sort_type=ilabel > $output_dir/lang/G.fst
