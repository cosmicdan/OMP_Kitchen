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
echo "[#] Building target/vendor.img ..."
./bin/make_ext4fs -l `getConfig vendor_size` -L system -a system -S "./tmp/file_contexts_all" -T 1 -s "./target/vendor.img" "./target/vendor"
echo "[#] Building target/boot.img ..."
cd ./bin/aik
# create symlinks instead of moving/copying
ln -s ../../target/boot/ramdisk ./ramdisk
ln -s ../../target/boot/split_img ./split_img
ln -s ../../target/boot/ramdisk-new.cpio.gz ./ramdisk-new.cpio.gz
./repackimg.sh
# cleanup
rm -f ./ramdisk ./split_img ./ramdisk-new.cpio.gz ./unsigned-new.img
mv ./image-new.img ../../target/boot.img
cd ../..






echo ""
echo "[i] 90_make_target_img finished."
echo "------------------------------------------"
echo ""

cleanupTmp