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
echo -e "<SIL>\tsil" >> $output_dir/local/dict/lexicon.txt
echo -e "<UNK>\tsil" >> $output_dir/local/dict/lexicon.txt
cat $PROJ_HOME/local/dict/lexicon.txt >> $output_dir/local/dict/lexicon.txt

cat $output_dir/local/dict/lexicon.txt | \
    perl -ane 'print join("\n", @F[1..$#F]) . "\n"; '  | \
    sort -u | grep -v 'sil' > $output_dir/local/dict/nonsilence_phones.txt

touch $output_dir/local/dict/extra_questions.txt
touch $output_dir/local/dict/optional_silence.txt

echo "sil"   > $output_dir/local/dict/optional_silence.txt
echo "sil"   > $output_dir/local/dict/silence_phones.txt
echo "<UNK>" > $output_dir/local/dict/oov.txt