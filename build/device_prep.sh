#!/bin/bash

doDevicePrep() {
	lunchPath="${KITCHEN_ROOT}/devices/${MIUI_KITCHEN_CFG_LNCH}"
	
	overwriteOld=false
	if [ "$1" == "all" ]; then
		overwriteOld=true
	fi
	
	deleteOrg=false
	if [ "$2" == "clean" ]; then
		deleteOrg=true
	fi
	
	echo "[#] Extracting firmware files for ${MIUI_KITCHEN_CFG_LNCH} ..."
	
	# decompile file_contexts.bin
	if [ -f "${lunchPath}/file_contexts.bin" ]; then
		# bin found
		if [ -f "${lunchPath}/file_contexts" -a "${overwriteOld}" != true ]; then
			# already decompiled and we're only doing missing
			echo "    [i] file_contexts already decompiled"
		else
			# not decompiled or we're doing all
			rm -f "${lunchPath}/file_contexts"
			echo "    [#] Decompiling file_contexts.bin..."
			sefcontext_decompile -o "${lunchPath}/file_contexts" "${lunchPath}/file_contexts.bin"
			if [ -f "${lunchPath}/file_contexts" ]; then
				if [ "${deleteOrg}" == true ]; then
					# clean original file if decompile succeeded
					rm -f "${lunchPath}/file_contexts.bin"
				fi
			else
				echo "    [!] Error decompiling file_contexts.bin!"
				setError 66
				exit
			fi
		fi
	else
		if [ ! -f "${lunchPath}/file_contexts" ]; then
			# no file_contexts nor file_contexts.bin so error-out
			echo "    [!] Error - file_contexts is missing and no file_contexts.bin found!"
			setError 65
			exit
		fi
	fi
	
	# extract boot.img
	if [ -f "${lunchPath}/boot.img" ]; then
		# boot.img found
		if [ -d "${lunchPath}/boot" -a "${overwriteOld}" != true ]; then
			# already extracted and we're only doing missing
			echo "    [i] boot.img already extracted"
		else
			# not extracted or we're doing all
			rm -rf "${lunchPath}/boot"
			echo "    [#] Extracting boot.img..."
			mkdir "${lunchPath}/boot"
			"${KITCHEN_BIN}/aik/unpackimg.sh" --nosudo "${lunchPath}/boot.img" > "${lunchPath}/boot.img-unpack.log" 2>&1
			mv "${KITCHEN_BIN}/aik/split_img" "${lunchPath}/boot/split_img"
			mv "${KITCHEN_BIN}/aik/ramdisk" "${lunchPath}/boot/ramdisk"
		fi
	else
		if [ ! -d "${lunchPath}/boot" ]; then
			# no boot.img nor boot/ so error-out
			echo "    [!] Error - boot.img is missing and no boot/ found!"
			setError 65
			exit
		fi
	fi
	
	# extract system and vendor
	for imageName in "system" "vendor"; do
		echo "    [#] Processing ${imageName} ..."
		
		if [ -f "${lunchPath}/${imageName}.new.dat.br" ]; then
			# brotli-compressed image found
			if [ ! -f "${lunchPath}/${imageName}.new.dat" -o "${overwriteOld}" == true ]; then
				# .new.dat doesn't exist, or all requested
				echo "        [#] Decompressing ${imageName}.new.dat.br ..."
				rm -f "${lunchPath}/${imageName}.new.dat"
				brotli -d "${lunchPath}/${imageName}.new.dat.br" -o "${lunchPath}/${imageName}.new.dat"
				if [ $? -ne 0 ]; then
					# brotli decompress failed
					echo "    [!] Error decompressing ${lunchPath}/${imageName}.new.dat.br!"
					setError 66
					exit
				elif [ "${deleteOrg}" == true ]; then
					# clean on successful decompress
					rm -f "${lunchPath}/${imageName}.new.dat.br"
				fi
			else
				echo "        [i] Brotli decompression skipped; ${imageName}.new.dat.br already exists."
			fi
		fi
		
		if [ -f "${lunchPath}/${imageName}.new.dat" -a -f "${lunchPath}/${imageName}.transfer.list" ]; then
			# .new.dat and .transfer.list found
			if [ ! -f "${lunchPath}/${imageName}.img" -o "${overwriteOld}" == true ]; then
				# .img doesn't exist, or all requested
				echo "        [#] Converting ${imageName}.new.dat to ${imageName}.img ..."
				rm -f "${lunchPath}/${imageName}.img"
				"${KITCHEN_BIN}/sdat2img.py" "${lunchPath}/${imageName}.transfer.list" "${lunchPath}/${imageName}.new.dat" "${lunchPath}/${imageName}.img" >/dev/null
				if [ $? -ne 0 ]; then
					# convert failed
					echo "    [!] Error converting ${lunchPath}/${imageName}.new.dat!"
					setError 66
					exit
				elif [ "${deleteOrg}" == true ]; then
					# clean on successful decompress
					rm -f "${lunchPath}/${imageName}.transfer.list" "${lunchPath}/${imageName}.new.dat" "${lunchPath}/${imageName}.patch.dat"
				fi
			else
				echo "        [i] Img conversion skipped; ${imageName}.img already exists."
			fi
		fi
		
		if [ -f "${lunchPath}/${imageName}.img" ]; then
			# an .img is found
			if [ ! -d "${lunchPath}/${imageName}" -o "${overwriteOld}" == true ]; then
				# extracted filesystem doesn't exist, or all requested
				sparse_magic=`hexdump -e '"%02x"' -n 4 "${lunchPath}/${imageName}.img"`
				if [ "$sparse_magic" = "ed26ff3a" ]; then
					# sparse image found, convert to raw first
					echo "        [#] Sparse .img detected, converting to raw image..."
					mv "${lunchPath}/${imageName}.img" "${lunchPath}/${imageName}.simg"
					simg2img "${lunchPath}/${imageName}.simg" "${lunchPath}/${imageName}.img"
					if [ ! -f "${lunchPath}/${imageName}.img" ]; then
						# simg > img failed
						echo "    [!] Error converting sparse image!"
						setError 66
						exit
					fi
				fi
				
				echo "        [#] About to mount ${lunchPath}/${imageName}.img to ${lunchPath}/${imageName}_tmp [sudo mount required]"
				mkdir "${lunchPath}/${imageName}_tmp"
				sudo mount -t ext4 -o loop "${lunchPath}/${imageName}.img" "${lunchPath}/${imageName}_tmp"
				if [ $? -eq 0 ]; then
					# mount succeeded
					echo "            [#] Copying contents of ${lunchPath}/${imageName}_tmp/ to ${lunchPath}/${imageName}/ [sudo rsync required]"
					rm -f "${lunchPath}/${imageName}"
					mkdir "${lunchPath}/${imageName}"
					sudo rsync -a "${lunchPath}/${imageName}_tmp/" "${lunchPath}/${imageName}/"
					echo "            [#] About to unmount ${lunchPath}/${imageName}_tmp/ [sudo umount required]"
					sudo umount -f "${lunchPath}/${imageName}_tmp/"
					if [ $? -eq 0 ]; then
						# umount succeeded
						rm -d "${lunchPath}/${imageName}_tmp/"
						if [ "${deleteOrg}" == true ]; then
							rm "${lunchPath}/${imageName}.img"
						fi
					else
						echo "                [!] Failed to umount ${lunchPath}/${imageName}_tmp/ - please do so manually."
					fi
					# do permissions
					echo "            [#] Backing-up ACL  [sudo getfacl required]..."
					pushd "${lunchPath}/${imageName}/" >/dev/null
					sudo getfacl -R . > "../${imageName}.acl"
					echo "            [#] Clearing permissions [sudo chmod required]..."
					sudo chmod -R 777 .
					popd >/dev/null
				else
					echo "    [!] Failure mounting ext4 image!"
					setError 66
					exit
				fi
			else
				echo "        [i] Img extraction skipped; ${imageName}/ already exists."
			fi
		else
			if [ ! -d "${lunchPath}/${imageName}" ]; then
				# .img file not found, nor is extracted filesystem
				echo "    [!] Error - ${imageName}.img is missing and does not appear to be extracted either!"
				setError 65
				exit
			fi
		fi
	done
	echo ""
	echo "TODO: De-odex!"
	echo ""
	echo "[i] All done!"
	
}