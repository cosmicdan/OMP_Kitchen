#!/bin/bash

# Make target img script

source ./bin/common_functions.sh

checkAndMakeTmp

echo ""
echo "------------------------------------------"
echo "[i] 90_make_target_img started."
echo ""


echo "[#] Building file_contexts ..."
# Collate file_contexts
cat \
	"./base_port/file_contexts" \
	> "./tmp/file_contexts_all"

# Sort and remove duplicate entries.
#sort -u -k1,1 "./tmp/file_contexts_all" > "./tmp/file_contexts_all_sorted"

# append additionals
#if [ -f "./patches/file_contexts.additional" ]; then
#	cat "./patches/file_contexts.additional" >> "./tmp/file_contexts_all_sorted"
#fi

echo "[#] Building target/system.img ..."
./bin/make_ext4fs -l `getConfig system_size` -L system -a system -S "./tmp/file_contexts_all" -T 1 -s "./target/system.img" "./target/system"
./bin/make_ext4fs -l `getConfig vendor_size` -L system -a system -S "./tmp/file_contexts_all" -T 1 -s "./target/vendor.img" "./target/vendor"




echo ""
echo "[i] 90_make_target_img finished."
echo "------------------------------------------"
echo ""

cleanupTmp