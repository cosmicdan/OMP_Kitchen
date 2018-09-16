#!/bin/bash

# Make src from base script
#
# This script is for unpacking port MIUI and base device images. It only needs to be done once when new port/base firmwares are provided. Various 
# parts of this script require sudo elevation. 
#
# All script tasks are as follows:
# 1) Unpack file system image files from ./base_{port|device}/ to ./src_{port|device}_{system|vendor}
#    - Will detect and unpack brotli, .dat and sparse image files if necessary.
#    - TODO: Optionally, provide only the device ROM to do mods to the device ROM without porting MIUI (it is assumed that the device ROM is already MIUI)
# 2) Backup the file ACL tree for extracted image files, then recursive mode 777 on extracted trees (for ease of development and research)
#    - The backed-up ACL list is used to restore ACL when packing the target image
# 3) Unpack device boot.img initramfs (RAMDisk) to ./src_device_initramfs/ and do the ACL backup and chmod stuff to it as in #2
#    - We do some manual patches to this later
#
# After this is done, you can delete any files in ./base_{port|device}/ if you want the space back. Just be sure to track your changes
# in the extracted ./src_* folders; these are expected to remain unmodified and original.
# 



source ./bin/common_functions.sh

echo ""
echo "------------------------------------------"
echo "[i] 00_make_src_from_base started."
echo ""
echo "[!] DO NOT INTERRUPT THIS PROCESS! You may corrupt the base_ if you do."
echo ""

checkAndMakeTmp

# Unpack filesystem images
for baseSuffix in "port" "device"; do
	echo "[#] Processing ./base_${baseSuffix} ...."
	if [ -d "./base_${baseSuffix}" ]; then
		if [ -f "./base_${baseSuffix}/file_contexts.bin" ]; then
			if [ ! -f "./base_${baseSuffix}/file_contexts" ]; then
				echo "    [#] Decompiling file_contexts.bin ..."
				./bin/sefcontext_decompile -o "./base_${baseSuffix}/file_contexts" "./base_${baseSuffix}/file_contexts.bin"
			else
				echo "    [i] file_contexts already exists, skipping."
			fi
		else
			echo     "    [!] file_contexts.bin missing. This is required."
			exit -1
		fi
	
		for imageName in "system" "vendor"; do
			echo "    [#] Processing ${imageName} ..."
			
			# unpack brotli image
			if [ -f "./base_${baseSuffix}/${imageName}.new.dat.br" ]; then
				if [ ! -f "./base_${baseSuffix}/${imageName}.new.dat" ]; then
					echo "        [#] Decompressing ./base_${baseSuffix}/${imageName}.new.dat.br to ./base_${baseSuffix}/${imageName}.new.dat ..."
					brotli -d "./base_${baseSuffix}/${imageName}.new.dat.br" -o "./tmp/${imageName}.new.dat"
					mv "./tmp/${imageName}.new.dat" "./base_${baseSuffix}/${imageName}.new.dat"
				else
					echo "        [i] Skipping brotli decompress since .dat file already exists"
				fi
			fi
			
			# unpack new.dat to img
			if [ -f "./base_${baseSuffix}/${imageName}.new.dat" -a -f "./base_${baseSuffix}/${imageName}.transfer.list" ]; then
				if [ ! -f "./base_${baseSuffix}/${imageName}.img" ]; then
					echo "        [#] Converting ./base_${baseSuffix}/${imageName}.new.dat to ./base_${baseSuffix}/${imageName}.img ..."
					./bin/sdat2img.py "./base_${baseSuffix}/${imageName}.transfer.list" "./base_${baseSuffix}/${imageName}.new.dat" "./tmp/${imageName}.img" >/dev/null
					mv "./tmp/${imageName}.img" "./base_${baseSuffix}/${imageName}.img"
				else
					echo "        [i] Skipping new.dat to img conversion since .img file already exists"
				fi
			fi
			
			# mount and extract the images
			if [ ! -d "./tmp_${baseSuffix}_${imageName}" ]; then
				if [ -f "./base_${baseSuffix}/${imageName}.img" ]; then
					# Check if sparse img, convert if so
					sparse_magic=`hexdump -e '"%02x"' -n 4 "./base_${baseSuffix}/${imageName}.img"`
					if [ "$sparse_magic" = "ed26ff3a" ]; then
						echo "        [#] Sparse image detected, converting to raw image..."
						mv "./base_${baseSuffix}/${imageName}.img" "./base_${baseSuffix}/${imageName}.simg"
						simg2img "./base_${baseSuffix}/${imageName}.simg" "./base_${baseSuffix}/${imageName}.img"
					fi
					
					if [ ! -d "./src_${baseSuffix}_${imageName}" ]; then
						echo "        [#] About to mount ./base_${baseSuffix}/${imageName}.img to ./tmp_${baseSuffix}_${imageName} [sudo mount required]"
						mkdir "./tmp_${baseSuffix}_${imageName}"
						sudo mount -t ext4 -o loop "./base_${baseSuffix}/${imageName}.img" "./tmp_${baseSuffix}_${imageName}"
						if [ $? -eq 0 ]; then
							echo "            [#] Copying contents of ./tmp_${baseSuffix}_${imageName} to ./src_${baseSuffix}_${imageName} [sudo rsync required]"
							mkdir "./src_${baseSuffix}_${imageName}"
							sudo rsync -a "./tmp_${baseSuffix}_${imageName}/" "./src_${baseSuffix}_${imageName}/"
							echo "            [#] About to unmount ./tmp_${baseSuffix}_${imageName} [sudo umount required]"
							sudo umount -f "./tmp_${baseSuffix}_${imageName}"
							if [ $? -eq 0 ]; then
								rm -d "./tmp_${baseSuffix}_${imageName}"
							else
								echo "                [!] Failed to umount ./tmp_${baseSuffix}_${imageName}. Please do so manually, and delete the directory after."
							fi
							# create facl
							echo "            [#] Creating ACL list at ./src_${baseSuffix}_metadata/${imageName}.acl [sudo getfacl required]..."
							if [ ! -d "./src_${baseSuffix}_metadata" ]; then
								mkdir "./src_${baseSuffix}_metadata"
							fi
							if [ -f "./src_${baseSuffix}_metadata/${imageName}.acl" ]; then
								rm "./src_${baseSuffix}_metadata/${imageName}.acl"
							fi
							cd "./src_${baseSuffix}_${imageName}/"
							sudo getfacl -R . > "../src_${baseSuffix}_metadata/${imageName}.acl"
							echo "            [#] Setting mode 777 recursive to ./src_${baseSuffix}_${imageName}/ [sudo chmod required]..."
							sudo chmod -R 777 .
							cd ..
						else
							echo "            [!] Mount failed. Skipping."
						fi
					else
						echo "        [i] ./src_${baseSuffix}_${imageName} already exists, skipping img extraction."
					fi
				else
					echo "        [!] Warning - ./src_${baseSuffix}_${imageName} does not exist and neither does ./base_${baseSuffix}/${imageName}.img."
				fi
			else
				echo "        [!] Warning - ./tmp_${baseSuffix}_${imageName} already exists. Skipping mount and extract of ./base_${baseSuffix}/${imageName}.img."
			fi
		done
	else
		echo "    [!] Warning - ./base_${baseSuffix} does not exist. Nothing to do."
	fi
done

# Unpack device kernel
for baseSuffix in "device"; do
	if [ -f "./base_${baseSuffix}/boot.img" ]; then
		if [ ! -d "./src_${baseSuffix}_boot" ]; then
			echo "[#] Unpacking kernel from ./base_${baseSuffix}/boot.img ..."
			mkdir "./src_${baseSuffix}_boot"
			./bin/aik/unpackimg.sh --nosudo ./base_${baseSuffix}/boot.img > "./src_${baseSuffix}_boot/unpackimg.log" 2>&1
			cd ./bin/aik
			mv ./split_img ../../src_${baseSuffix}_boot/split_img
			mv ./ramdisk ../../src_${baseSuffix}_boot/ramdisk
			# also backup facl and chmod
			#if [ ! -d "../src_${baseSuffix}_metadata" ]; then
			#	mkdir "../src_${baseSuffix}_metadata"
			#fi
			#if [ -f "../src_${baseSuffix}_metadata/ramdisk.acl" ]; then
			#	rm "../src_${baseSuffix}_metadata/ramdisk.acl"
			#fi
			#echo "    [#] Creating ACL list at ./src_${baseSuffix}_metadata/ramdisk.acl ..."
			#cd ../../src_${baseSuffix}_boot/ramdisk
			#getfacl -R . > "../../src_${baseSuffix}_metadata/ramdisk.acl"
			#echo "    [#] Setting mode 777 recursive to ./src_${baseSuffix}_boot/ramdisk ..."
			#sudo chmod -R 777 .
			cd ../..
			# put decompiled file_contexts into ramdisk too
			cp -a "./base_${baseSuffix}/file_contexts" "./src_${baseSuffix}_boot/ramdisk/"
			echo "    [i] Added file_contexts to ramdisk root"
		else
			echo "[i] ./src_${baseSuffix}_boot already exists, skipping boot.img ramdisk unpack."
		fi
	else
		echo "[!] Warning - ./base_${baseSuffix}/boot.img does not exist (needed for initramfs mods)."
	fi
done

echo ""
echo "[i] 00_make_src_from_base finished."
echo "------------------------------------------"
echo ""

cleanupTmp
