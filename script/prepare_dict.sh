#!/bin/bash

PROJ_HOME=`pwd`/..

data_dir=$1

if [[ -z $data_dir ]]; then
    data_dir=data
fi

mkdir -p $data_dir/lang $data_dir/local/dict

cat $PROJ_HOME/lang/dict/lexicon.txt | sed '1,2d' > $data_dir/local/dict/lexicon_words.txt

cp -r $PROJ_HOME/lang/dict $data_dir/local