#!/bin/bash

data_dir=$1

if [[ -z $data_dir ]]; then
    data_dir=data
fi

data_dir=$PROJ_HOME/$data_dir

mkdir -p $data_dir/lang $data_dir/local/dict

cat $PROJ_HOME/lang/dict/lexicon.txt | sed '1,2d' > $data_dir/local/dict/lexicon_words.txt

cp -r $PROJ_HOME/lang/dict $data_dir/local