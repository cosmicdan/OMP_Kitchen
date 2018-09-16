#!/bin/bash

# Make target img script

source ./bin/common_functions.sh

checkAndMakeTmp

echo ""
echo "------------------------------------------"
echo "[i] make_target_img started."
echo ""


echo "[#] Building target/system.img ..."
./bin/make_ext4fs -l `getConfig system_size` -L system -a system -S "./target/boot/ramdisk/file_contexts" -T 1 -s "./target/system.img" "./target/system"
echo "[#] Building target/vendor.img ..."
./bin/make_ext4fs -l `getConfig vendor_size` -L vendor -a vendor -S "./target/boot/ramdisk/file_contexts" -T 1 -s "./target/vendor.img" "./target/vendor"
echo "[#] Building target/boot.img ..."
cd ./bin/aik
# create symlinks instead of moving/copying
ln -s ../../target/boot/ramdisk ./ramdisk
ln -s ../../target/boot/split_img ./split_img
ln -s ../../target/boot/ramdisk-new.cpio.gz ./ramdisk-new.cpio.gz
./repackimg.sh > ../../target/boot/repack.log 2>&1
# cleanup
rm -f ./ramdisk ./split_img ./ramdisk-new.cpio.gz ./unsigned-new.img ../../target/boot/ramdisk-new.cpio.gz
mv ./image-new.img ../../target/boot.img
cd ../..






echo ""
echo "[i] make_target_img finished."
echo "------------------------------------------"
echo ""

cleanupTmp