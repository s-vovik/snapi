#!/bin/bash
# single end read taxonomic classification
export CURDIR=`pwd`
export RESULTS=${CURDIR}/results
export MPLCONFIGDIR=${CURDIR}/tmp
export TMPDIR=${CURDIR}/tmp
export NUMBA_CACHE_DIR=${TMPDIR}
export THREADS=24

#export CLASSIFIER=gg-13-8-99-515-806-nb-classifier.qza
export CLASSIFIER=silva-138-99-515-806-nb-classifier.qza

mkdir ${RESULTS}
mkdir ${RESULTS}/data
mkdir ${MPLCONFIGDIR}

rm ${RESULTS}/*
rm ${RESULTS}/data/*

if [ ! -f ./${CLASSIFIER} ]; then
echo "Download qiime classifier"
wget \
  -O ${CLASSIFIER} \
  "https://data.qiime2.org/2021.11/common/${CLASSIFIER}"
fi

qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path ./manifest_paired.tsv \
  --output-path ${RESULTS}/data/paired-end-demux.qza \
  --input-format PairedEndFastqManifestPhred33V2

qiime demux summarize \
  --i-data ${RESULTS}/data/paired-end-demux.qza \
  --o-visualization ${RESULTS}/data/demux-summarize.qzv \
  --p-n 10000


# prepare data2 denoise
qiime dada2 denoise-paired \
  --i-demultiplexed-seqs ${RESULTS}/data/paired-end-demux.qza \
  --p-trim-left-f 5 \
  --p-trim-left-r 5 \
  --p-trunc-len-f 150 \
  --p-trunc-len-r 150 \
  --o-table ${RESULTS}/data/table.qza \
  --p-n-threads ${THREADS} \
  --o-representative-sequences ${RESULTS}/data/rep-seqs.qza \
  --o-denoising-stats ${RESULTS}/data/denoising-stats.qza \
  --verbose

qiime quality-filter q-score \
 --i-demux ${RESULTS}/data/paired-end-demux.qza \
 --o-filtered-sequences ${RESULTS}/data/demux-filtered.qza \
 --o-filter-stats ${RESULTS}/data/demux-filter-stats.qza


# summarize

qiime feature-table summarize \
  --i-table ${RESULTS}/data/table.qza \
  --o-visualization ${RESULTS}/data/table.qzv

qiime feature-table tabulate-seqs \
  --i-data ${RESULTS}/data/rep-seqs.qza \
  --o-visualization ${RESULTS}/data/rep-seqs.qzv

qiime metadata tabulate \
  --m-input-file ${RESULTS}/data/denoising-stats.qza \
  --o-visualization ${RESULTS}/data/denoising-stats.qzv

qiime feature-table summarize \
  --i-table ${RESULTS}/data/table.qza \
  --o-visualization ${RESULTS}/data/table.qzv \
  --verbose

# get representative sequences
qiime feature-table tabulate-seqs \
  --i-data ${RESULTS}/data/rep-seqs.qza \
  --o-visualization ${RESULTS}/data/rep-seqs.qzv

# create phylogeny
qiime phylogeny align-to-tree-mafft-fasttree \
  --i-sequences ${RESULTS}/data/rep-seqs.qza \
  --o-alignment ${RESULTS}/data/aligned-rep-seqs.qza \
  --o-masked-alignment ${RESULTS}/data/masked-aligned-rep-seqs.qza \
  --o-tree ${RESULTS}/data/unrooted-tree.qza \
  --o-rooted-tree ${RESULTS}/data/rooted-tree.qza \
  --p-n-threads ${THREADS} \
  --verbose

#alpha rarefaction
qiime diversity alpha-rarefaction \
  --i-table ${RESULTS}/data/table.qza \
  --i-phylogeny ${RESULTS}/data/rooted-tree.qza \
  --p-max-depth 4000 \
  --o-visualization ${RESULTS}/data/alpha-rarefaction.qzv \
  --verbose

# taxonomy classification
qiime feature-classifier classify-sklearn \
  --i-classifier ${CLASSIFIER} \
  --i-reads ${RESULTS}/data/rep-seqs.qza \
  --o-classification ${RESULTS}/data/taxonomy.qza \
  --p-n-jobs ${THREADS} \
  --verbose

qiime metadata tabulate \
  --m-input-file ${RESULTS}/data/taxonomy.qza \
  --o-visualization ${RESULTS}/data/taxonomy.qzv \
  --verbose

qiime taxa barplot \
  --i-table ${RESULTS}/data/table.qza \
  --i-taxonomy ${RESULTS}/data/taxonomy.qza \
  --o-visualization ${RESULTS}/data/taxa-bar-plots.qzv

# Extract biom & tsv files
unzip -j ${RESULTS}/data/table.qza "*.biom" -d ${RESULTS}
unzip -j ${RESULTS}/data/taxonomy.qza "*.tsv" -d ${RESULTS}

# Normalize results as json
biom convert -i ${RESULTS}/feature-table.biom -o ${RESULTS}/feature-table.tsv --to-tsv

jq -R -s 'split("\n") | map(split("\t"))' ${RESULTS}/feature-table.tsv > ${RESULTS}/feature-table.json
cat ${RESULTS}/taxonomy.tsv | jq --raw-input --slurp 'split("\n") | map(split("\t")) | .[0:-1] | map( { "id": .[0], "taxonomy": .[1], "confidence": .[2] } )' >> ${RESULTS}/taxonomy.json

jq -s '{ "taxonomy":.[0], "frequency":.[1]}' ${RESULTS}/taxonomy.json ${RESULTS}/feature-table.json >> ${RESULTS}/report.json

echo "Done"

