#!/bin/bash

PROJ_HOME=`pwd`/..

data_dir=$1

if [[ -z $data_dir ]]; then
    data_dir=data
fi

mkdir -p $data_dir/lang $data_dir/local/dict

touch $data_dir/local/dict/lexicon.txt
echo -e "<SIL>\tsil" >> $data_dir/local/dict/lexicon.txt
echo -e "<UNK>\tsil" >> $data_dir/local/dict/lexicon.txt
cat $PROJ_HOME/lang/dict/lexicon.txt >> $data_dir/local/dict/lexicon.txt

cp $PROJ_HOME/lang/dict/nonsilence_phones.txt   $data_dir/local/dict/nonsilence_phones.txt
cp $PROJ_HOME/lang/dict/oov.txt                 $data_dir/local/dict/oov.txt
cp $PROJ_HOME/lang/dict/optional_silence.txt    $data_dir/local/dict/optional_silence.txt
cp $PROJ_HOME/lang/dict/silence_phones.txt      $data_dir/local/dict/silence_phones.txt