#!/bin/bash

doBuild() {
	buildArg="$1"

	lunchPath="${KITCHEN_ROOT}/devices/${MIUI_KITCHEN_CFG_LNCH}"
	if [ -f "${lunchPath}/include.sh" ]; then
		source "${lunchPath}/include.sh"
		echo "[i] Including ${lunchPath/${KITCHEN_ROOT}\//}/include.sh"
	fi
	
	# lunch already verified that config.sh exists
	source "${lunchPath}/config.sh"
	deviceConfig
	
	rebasePath="${KITCHEN_ROOT}/devices/${MIUI_KITCHEN_CFG_BASE}"
	doRebase=false
	if [ -d "${rebasePath}" ]; then
		doRebase=true
	fi
	
	# verify flavor
	if [ "${MIUI_KITCHEN_CFG_FLAV}" == "" -o "${MIUI_KITCHEN_CFG_FLAV}" == "NONE" ]; then
		echo "[!] You must select a flavor first!"
		setError 67
		exit
	fi
	
	flavorPath="${KITCHEN_ROOT}/flavors/${MIUI_KITCHEN_CFG_FLAV}"
	if [ -f "${flavorPath}/include.sh" ]; then
		source "${flavorPath}/include.sh"
		echo "[i] Including ${flavorPath/${KITCHEN_ROOT}\//}/include.sh"
	fi
	
	if [ ! -d "${flavorPath}" ]; then
		echo "[!] Selected flavor is missing or invalid!"
		setError 67
		exit
	fi
	
	miuiOutPath="${KITCHEN_ROOT}/out/${MIUI_KITCHEN_CFG_LNCH}-${MIUI_KITCHEN_CFG_FLAV}"
	mkdir -p "${miuiOutPath}"
	rm -f "${miuiOutPath}/build.cfg"
	
	# get device/base MIUI version string
	if [ "${doRebase}" = true ]; then
		echo "[!] TODO: Rebase not yet implemented."
	else
		setBuildInfo verIncremental=$(file_getprop "${lunchPath}/system/build.prop" "ro.build.version.incremental")
	fi
	
	refreshBuildInfo
	# YYMMDD-MinutesSinceMidnight
	#setBuildInfo buildTimestamp=`$(( $(date '+%s / 60') ))`
	
	miuiOutZip="${KITCHEN_ROOT}/out/miui-cosmicdan-${MIUI_KITCHEN_CFG_LNCH}-${verIncremental}-${romBuildNum}-${MIUI_KITCHEN_CFG_FLAV}.zip"
	
	echo "[i] Build info:"
	echo "    Device: ${MIUI_KITCHEN_CFG_LNCH}"
	echo "    Rebase: ${MIUI_KITCHEN_CFG_BASE}"
	echo "    Flavor: ${MIUI_KITCHEN_CFG_FLAV}"
	echo "    Build: ${romBuildNum}"
	echo "    Incremental: ${verIncremental}"
	echo "    Out path: ${miuiOutPath}"
	echo "    Out ZIP: ${miuiOutZip}"

	if [ "${buildArg}" == "roots" -o "${buildArg}" == "dirty-roots" -o "${buildArg}" == "all" ]; then
		doBuildRoots
	fi
	
	if [ "${buildArg}" == "img" -o "${buildArg}" == "all" ]; then
		doBuildImg
	fi
	
	if [ "${buildArg}" == "zip" -o "${buildArg}" == "all" ]; then
		doBuildZip
	fi
	
	
	#########################################################################################################################################################################################
	# finished
	
	echo "[i] All done!"
}

#########################################################################################################################################################################################
# buildArg = roots or dirty-roots (or all)
doBuildRoots() {
	echo ""
	
	buildRootsArg="${buildArg}"
	if [ "${buildRootsArg}" == "all" ]; then
		# do a clean build for `build all`
		buildRootsArg="roots"
	fi
	
	if [ -d "${miuiOutPath}/system" ]; then
		if [ "${buildRootsArg}" == "roots" ]; then
			rm -rf "${miuiOutPath}/system"
		fi
	fi
	if [ -d "${miuiOutPath}/vendor" ]; then
		if [ "${buildRootsArg}" == "roots" ]; then
			rm -rf "${miuiOutPath}/vendor"
		fi
	fi
	if [ -d "${miuiOutPath}/boot" ]; then
		if [ "${buildRootsArg}" == "roots" ]; then
			rm -rf "${miuiOutPath}/boot"
		fi
	fi
	
	if [ "${buildRootsArg}" == "dirty-roots" ]; then
		echo "[!] Warning - performing dirty build!"
	fi
	

	echo "[#] Copying device system..."
	mkdir -p "${miuiOutPath}/system"
	rsync -a "${lunchPath}/system/" "${miuiOutPath}/system"
	echo "[#] Copying device vendor..."
	mkdir -p "${miuiOutPath}/vendor"
	rsync -a "${lunchPath}/vendor/" "${miuiOutPath}/vendor/"
	echo "[#] Copying device boot..."
	mkdir -p "${miuiOutPath}/boot"
	rsync -a "${lunchPath}/boot/" "${miuiOutPath}/boot/"
	# also copy file_contexts to initramfs
	cp -a "${lunchPath}/file_contexts" "${miuiOutPath}/boot/ramdisk/file_contexts"
	echo ""
	
	# execute flavorDoRoots from flavor's include.sh
	if [ $(functionExists flavorDoRoots) == true ]; then
		echo "[#] Running flavorDoRoots() ..."
		flavorDoRoots
	else
		echo "[i] Skipping flavorDoRoots because flavor '${MIUI_KITCHEN_CFG_FLAV}' does not provide it."
	fi
	
	# execute deviceDoRoots from lunched device's include.sh
	if [ $(functionExists deviceDoRoots) == true ]; then
		echo "[#] Running deviceDoRoots() ..."
		deviceDoRoots
	else
		echo "[i] Skipping deviceDoRoots because device '${MIUI_KITCHEN_CFG_LNCH}' does not provide it."
	fi
	
	# TODO: modify branding to avoid potential OTA conflicts. Modify the following properties:
	# ro.build.display.id
	# ro.modversion
	# ro.xiaomi.developerid
	# ro.build.host
	
	echo ""
}



#########################################################################################################################################################################################
# buildArg = img (or all)
doBuildImg() {
	echo ""
	
	rm -f "${miuiOutPath}/system.img"
	rm -f "${miuiOutPath}/vendor.img"
	rm -f "${miuiOutPath}/boot.img"
	
	echo "[#] Packing system.img ..."
	"${KITCHEN_BIN}/make_ext4fs" -l ${deviceSystemSize} -L system -a system -S "${lunchPath}/file_contexts" -T 1 -s "${miuiOutPath}/system.img" "${miuiOutPath}/system"
	echo "[#] Building vendor.img ..."
	"${KITCHEN_BIN}/make_ext4fs" -l ${deviceVendorSize} -L vendor -a vendor -S "${lunchPath}/file_contexts" -T 1 -s "${miuiOutPath}/vendor.img" "${miuiOutPath}/vendor"
	echo "[#] Building boot.img ..."
	pushd "${KITCHEN_BIN}/aik/" >/dev/null
	# create symlinks instead of moving/copying
	ln -s "${miuiOutPath}/boot/ramdisk" ./ramdisk
	ln -s "${miuiOutPath}/boot/split_img" ./split_img
	ln -s "${miuiOutPath}/boot/ramdisk-new.cpio.gz" ./ramdisk-new.cpio.gz
	./repackimg.sh > "${miuiOutPath}/boot/repack.log" 2>&1
	# cleanup
	rm -f ./ramdisk ./split_img ./ramdisk-new.cpio.gz ./unsigned-new.img "${miuiOutPath}/boot/ramdisk-new.cpio.gz"
	mv ./image-new.img "${miuiOutPath}/boot.img"
	popd >/dev/null
	
	echo ""
}



#########################################################################################################################################################################################
# buildArg = zip (or all)
doBuildZip() {
	echo ""
	
	rm -f "${miuiOutPath}/release.log"
	echo "[#] Building system|vendor.new.dat..."
	"${KITCHEN_BIN}/img2sdat/img2sdat.py" -o "${miuiOutPath}" -p system -v 4 "${miuiOutPath}/system.img" >> "${miuiOutPath}/release.log" &
	"${KITCHEN_BIN}/img2sdat/img2sdat.py" -o "${miuiOutPath}" -p vendor -v 4 "${miuiOutPath}/vendor.img" >> "${miuiOutPath}/release.log" &
	wait
	echo "[#] Compressing system|vendor.new.dat.br..."
	brotli -j -v -q 5 "${miuiOutPath}/system.new.dat" &
	brotli -j -v -q 5 "${miuiOutPath}/vendor.new.dat" &
	wait
	
	echo "[#] Preparing ZIP contents..."
	rm -rf "${miuiOutPath}/zip"
	mkdir -p "${miuiOutPath}/zip"
	cp "${miuiOutPath}/boot.img" "${miuiOutPath}/zip/boot.img"
	mv "${miuiOutPath}/"*.new.dat.br "${miuiOutPath}/zip/"
	mv "${miuiOutPath}/"*.patch.dat "${miuiOutPath}/zip/"
	mv "${miuiOutPath}/"*.transfer.list "${miuiOutPath}/zip/"
	cp "${miuiOutPath}/build.cfg" "${miuiOutPath}/zip/build.cfg"
	cp "${lunchPath}/file_contexts" "${miuiOutPath}/zip/file_contexts"
	rsync -a "${lunchPath}/firmware-update/" "${miuiOutPath}/zip/firmware-update/"
	rsync -a "${lunchPath}/META-INF/" "${miuiOutPath}/zip/META-INF/"
	
	# updater-script has our own header and optional footer
	{
	echo "ui_print(\" \");"
	echo "ui_print(\"#############################\");"
	echo "ui_print(\"#  CosmicDan's MIUI Builds  #\");"
	echo "ui_print(\"#############################\");"
	echo "ui_print(\" \");"
	echo "ui_print(\"Device-base: ${MIUI_KITCHEN_CFG_LNCH}\");"
	#echo "ui_print(\"Rebase: ${MIUI_KITCHEN_CFG_BASE}\");"
	echo "ui_print(\"Flavor: ${MIUI_KITCHEN_CFG_FLAV}\");"
	echo "ui_print(\"MIUI version: ${verIncremental}\");"
	echo "ui_print(\"Kitchen build: ${buildTimestamp}\");"
	echo "ui_print(\" \");"
	} > "${miuiOutPath}/zip/META-INF/com/google/android/updater-script"

	cat "${lunchPath}/META-INF/com/google/android/updater-script" >> "${miuiOutPath}/zip/META-INF/com/google/android/updater-script"

	if [ $(functionExists updaterScriptFooter) == true ]; then
		updaterScriptFooter >> "${miuiOutPath}/zip/META-INF/com/google/android/updater-script"
	else
		echo "[i] Notice: '${MIUI_KITCHEN_CFG_LNCH}' does not provide an updaterScriptFooter implementation."
	fi

	echo ""
	
	echo "[#] Creating ${miuiOutZip} ..."
	rm -f "${miuiOutZip}"
	pushd "${miuiOutPath}/zip/" >/dev/null
	zip -r2 "${miuiOutZip}" . >> "${miuiOutPath}/release.log"
	popd >/dev/null
}