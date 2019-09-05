#!/usr/bin/env bash

# load configuration
. $PROJ_HOME/conf/main.conf

data_dir=$1
output_dir=$2

# prepare train and test data
echo 'Generate train and test set'
python3 $PROJ_HOME/local/prepare_data.py --data_dir $data_dir --output_dir $output_dir --test_ratio $test_set_ratio

# prepare dictionary
echo 'Generate dictionary'
$PROJ_HOME/local/prepare_dict.sh $output_dir

# prepare language model
echo 'Generate language model'
$PROJ_HOME/local/prepare_lm.sh $data_dir $output_dir $lm_order