#!/usr/bin/env bash

output_dir=$1
if [[ -z $output_dir ]] ; then
    echo "Location of output directory undefined"
    exit 1
fi
if [[ -z $output_dir ]]; then
    echo >&2 "The directory $output_dir does not exist"
    exit 1
fi

mkdir -p $output_dir/local/dict

# lexicon
touch $output_dir/local/dict/lexicon.txt
echo -e "<sil>\tSIL" >> $output_dir/local/dict/lexicon.txt
echo -e "<unk>\tSIL" >> $output_dir/local/dict/lexicon.txt
cat $PROJ_HOME/local/dict/lexicon.txt >> $output_dir/local/dict/lexicon.txt

cat $PROJ_HOME/local/dict/lexicon.txt | \
    perl -ane 'print join("\n", @F[1..$#F]) . "\n"; '  | \
    sort -u > $output_dir/local/dict/nonsilence_phones.txt

touch $output_dir/local/dict/extra_questions.txt
touch $output_dir/local/dict/optional_silence.txt

echo "SIL"   > $output_dir/local/dict/optional_silence.txt
echo "SIL"   > $output_dir/local/dict/silence_phones.txt
echo "<unk>" > $output_dir/local/dict/oov.txt

$PROJ_HOME/utils/prepare_lang.sh $output_dir/local/dict "<unk>" $output_dir/local/lang $output_dir/lang