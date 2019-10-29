import os
import csv
import math
import re
import argparse
import subprocess

PROJ_HOME = os.environ['PROJ_HOME']

def read_dataset(data_file):
    if not os.path.exists(data_file):
        raise Exception('data.csv not exist: ' + data_file)

    dataset = []
    with open(data_file, mode='r', encoding='utf-8') as csv_file:
        reader = csv.reader(csv_file)

        for idx, line in enumerate(reader):
            if line == '':
                break

            line.append(line[0][:-5])  # utterance id

            dataset.append(line)

    return dataset

def generate_dataset(dataset, in_dataset_dir, out_dataset_dir):
    if not os.path.exists(out_dataset_dir):
        os.makedirs(out_dataset_dir)

    wav_id_pattern = 'KM-\\d{2}-\\w{1}-\\d{2}-\\d{5}-\\d{4}'
    wav_id_regex = re.compile(wav_id_pattern)

    dataset = sorted(dataset, key=lambda record: tuple(re.findall(wav_id_regex, record[0])))

    # write data
    with open(out_dataset_dir + '/text', mode='w', encoding='utf-8') as text_writer, \
            open(out_dataset_dir + '/wav.scp', mode='w', encoding='utf-8') as wav_writer, \
            open(out_dataset_dir + '/utt2spk', mode='w', encoding='utf-8') as utt2spk_writer:

        invalid_examples = []

        for record in dataset:
            wav_path = os.path.abspath(in_dataset_dir + '/wav/' + record[0] + '.wav')
            if not os.path.exists(wav_path):
                print('!!!!! Wave file not found: %s' % wav_path)

                invalid_examples.append(record[0])
                continue

            text_writer.write('%s %s\n' % (record[0], record[1].strip()))
            wav_writer.write('%s %s\n' % (record[0], wav_path))

        spk_id_pattern = 'KM-\\d{2}-\\w{1}-\\d{2}-\\d{5}'
        spk_id_regex = re.compile(spk_id_pattern)

        dataset = sorted(dataset, key=lambda record: tuple(re.findall(spk_id_regex, record[2])))
        for record in dataset:
            utt_id = record[0]
            if utt_id in invalid_examples:
                continue

            utt2spk_writer.write('%s %s\n' % (utt_id, record[2]))

    with open(out_dataset_dir + '/spk2utt', mode='w', encoding='utf-8') as spk2utt_writer:
        subprocess.call(
            ['%s/utils/utt2spk_to_spk2utt.pl' % PROJ_HOME, '%s/utt2spk' % (PROJ_HOME + '/' + out_dataset_dir)],
            stdout=spk2utt_writer)

def generate_datasets(options):
    data_dir = options.data_dir

    ds_mode = 0 # 0 : all, 1: train-test
    if os.path.exists(data_dir + '/train') and os.path.exists(data_dir + '/test'):
        ds_mode = 1

    if ds_mode == 0:
        if not os.path.exists(data_dir + '/all'):
            raise Exception('Folder "all" not exist')

        # prepare data
        dataset = read_dataset(data_dir + '/all/data.csv')

        num_test_ds = math.ceil(options.test_ratio * len(records))
        train_set = dataset[num_test_ds:]
        test_set = dataset[:num_test_ds]

        # generate data
        print(">>>>> Generate train data")
        generate_dataset(train_set, data_dir + '/all', options.output_dir + '/' + 'train')

        print(">>>>> Generate test data")
        generate_dataset(test_set, data_dir + '/all', options.output_dir + '/' + 'test')

    elif ds_mode == 1:
        if not os.path.exists(data_dir + '/train'):
            raise Exception('Folder "train" not exist')

        if not os.path.exists(data_dir + '/test'):
            raise Exception('Folder "test" not exist')

        # train
        print(">>>>> Generate train data")
        train_set = read_dataset(data_dir + '/train/data.csv')
        generate_dataset(train_set, data_dir + '/train', options.output_dir + '/' + 'train')

        # test
        print(">>>>> Generate test data")
        train_set = read_dataset(data_dir + '/test/data.csv')
        generate_dataset(train_set, options.data_dir + '/test', options.output_dir + '/' + 'test')

def main():
    parser = argparse.ArgumentParser()

    parser.add_argument('--data_dir', type=str)
    parser.add_argument('--output_dir', type=str)
    parser.add_argument('--test_ratio', type=str, default='0.05')

    options = parser.parse_args()

    options.test_ratio = float(options.test_ratio)

    generate_datasets(options)


if __name__ == '__main__':
    main()
