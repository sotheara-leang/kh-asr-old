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

cp $PROJ_HOME/local/dict/nonsilence_phones.txt   $output_dir/local/dict/nonsilence_phones.txt
cp $PROJ_HOME/local/dict/oov.txt                 $output_dir/local/dict/oov.txt
cp $PROJ_HOME/local/dict/optional_silence.txt    $output_dir/local/dict/optional_silence.txt
cp $PROJ_HOME/local/dict/silence_phones.txt      $output_dir/local/dict/silence_phones.txt