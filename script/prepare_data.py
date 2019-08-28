import os
import csv
import random
import math
import re
import argparse
import subprocess

PROJ_HOME = os.getcwd() + '/..'

def generate_datasets(options):
    with open(options.data_dir + '/data.csv', mode='r', encoding='utf-8') as csv_file:
        reader = csv.reader(csv_file)

        records = []
        for idx, line in enumerate(reader):

            if line == '':
                break

            line.append(line[0][:-5])  # utterance id

            records.append(line)

        random.shuffle(records)

        num_test_ds = math.ceil(options.test_ratio * len(records))

        train_set = records[num_test_ds:]
        test_set = records[:num_test_ds]

        # sort data

        wav_id_pattern = 'KM-\\d{2}-\\w{1}-\\d{2}-\\d{5}-\\d{4}'
        wav_id_regex = re.compile(wav_id_pattern)

        train_set = sorted(train_set, key=lambda record: tuple(re.findall(wav_id_regex, record[0])))
        test_set = sorted(test_set, key=lambda record: tuple(re.findall(wav_id_regex, record[0])))

        # write data - train set

        train_dir = options.data_dir + '/' + 'train'
        if not os.path.exists(train_dir):
            os.makedirs(train_dir)

        with open(train_dir + '/text', mode='w', encoding='utf-8') as text_writer, \
                open(train_dir + '/wav.scp', mode='w', encoding='utf-8') as wav_writer, \
                open(train_dir + '/utt2spk', mode='w', encoding='utf-8') as utt2spk_writer, \
                open(train_dir + '/spk2utt', mode='w', encoding='utf-8') as spk2utt_writer:

            for record in train_set:
                text_writer.write('%s %s\n' % (record[0], record[1].strip()))
                wav_writer.write('%s %s\n' % (record[0], os.path.abspath(options.data_dir + '/wav/' + record[0] + '.wav')))

            spk_id_pattern = 'KM-\\d{2}-\\w{1}-\\d{2}-\\d{5}'
            spk_id_regex = re.compile(spk_id_pattern)

            train_set = sorted(train_set, key=lambda record: tuple(re.findall(spk_id_regex, record[2])))
            for record in train_set:
                utt2spk_writer.write('%s %s\n' % (record[0], record[2]))

            subprocess.Popen(['%s/utils/utt2spk_to_spk2utt.pl' % PROJ_HOME, '%s/utt2spk' % train_dir], stdout=spk2utt_writer)

        # test set

        if test_set is None or len(test_set) == 0:
            return

        test_dir = options.data_dir + '/' + 'test'
        if not os.path.exists(test_dir):
            os.makedirs(test_dir)

        with open(test_dir + '/text', mode='w', encoding='utf-8') as text_writer, \
                open(test_dir + '/wav.scp', mode='w', encoding='utf-8') as wav_writer, \
                open(test_dir + '/utt2spk', mode='w', encoding='utf-8') as utt2spk_writer, \
                open(test_dir + '/spk2utt', mode='w', encoding='utf-8') as spk2utt_writer:

            for record in test_set:
                text_writer.write('%s %s\n' % (record[0], record[1].strip()))
                wav_writer.write('%s %s\n' % (record[0], os.path.abspath(options.data_dir + '/wav/' + record[0] + '.wav')))

            spk_id_pattern = 'KM-\\d{2}-\\w{1}-\\d{2}-\\d{5}'
            spk_id_regex = re.compile(spk_id_pattern)

            test_set = sorted(test_set, key=lambda record: tuple(re.findall(spk_id_regex, record[2])))
            for record in test_set:
                utt2spk_writer.write('%s %s\n' % (record[0], record[2]))

            subprocess.Popen(['%s/utils/utt2spk_to_spk2utt.pl' % PROJ_HOME, '%s/utt2spk' % test_dir], stdout=spk2utt_writer)


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument('--data_dir', type=str)
    parser.add_argument('--test_ratio', type=int, default=0.05)

    options = parser.parse_args()

    generate_datasets(options)


if __name__ == '__main__':
    main()
