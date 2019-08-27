#!/bin/bash

mkdir -p $PROJ_HOME/data/lang $PROJ_HOME/data/local/dict

cat $PROJ_HOME/lang/dict/lexicon.txt | sed '1,2d' > $PROJ_HOME/data/local/dict/lexicon_words.txt

cp -r $PROJ_HOME/lang/dict $PROJ_HOME/data/local