import collections

def extract_phonemes(lexicon_file, phoneme_file):
    with open(lexicon_file, mode='r', encoding='utf-8') as lexicon_reader, \
            open(phoneme_file, mode='w', encoding='utf-8') as phone_writer:

        phoneme_counter = collections.Counter()

        for line in lexicon_reader:
            if line == '':
                break

            phoneme_counter.update(line.strip().split('\t')[1].split())

        for phoneme in phoneme_counter:
            phone_writer.write(phoneme + '\n')

def replace_ipa2latin(ipa_file, latin_file, ipa_latin_mapping_file):
    with open(ipa_file, mode='r', encoding='utf-8') as lexicon_reader, \
            open(latin_file, mode='w', encoding='utf-8') as new_lexicon_reader, \
            open(ipa_latin_mapping_file, mode='r', encoding='utf-8') as ipa_latin_mapping_reader:

        # read ipa-latin mapping
        mapping = {}
        for line in ipa_latin_mapping_reader:
            if line == '':
                break

            elements = line.strip().split()
            mapping[elements[0]] = elements[1]

        # replace ipa with latin
        for line in lexicon_reader:
            elements = line.strip().split('\t')

            ipa_phonemes = elements[1].split()

            try:
                latin_phonemes = []
                for phoneme in ipa_phonemes:
                    latin_phonemes.append(mapping[phoneme])
            except KeyError:
                print('phoneme %s not found: %s' % (phoneme, elements[1]))
                continue

            new_lexicon_reader.write('%s\t%s\n' % (elements[0], ' '.join(latin_phonemes)))
