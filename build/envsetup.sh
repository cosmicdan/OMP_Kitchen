#!/bin/bash
#
# envsetup.sh
# 
# Following AOSP build system conventions, this is the entry-point to the MIUI kitchen tasks.
#

if [ "${PS1_ORIGINAL}" == "" ]; then
	# backup original prompt
	PS1_ORIGINAL="${PS1}"
fi

# setup
KITCHEN_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null && pwd )"
KITCHEN_BIN="${KITCHEN_ROOT}/build"
export PATH="${PATH}:${KITCHEN_BIN}"
source "${KITCHEN_BIN}/error_handler.sh"

MIUI_KITCHEN_CFG_LNCH=NONE
MIUI_KITCHEN_CFG_BASE=NONE
MIUI_KITCHEN_CFG_FLAV=NONE

loadKitchenConfig() {
	# Specify possible prop file locations. Used for reading/writing keys and values across the build process.
	# Precendence matters:
	# - Merge props will be pulled from the first found match
	# - Additional props will go into the first file in the list
	# - Removals, however, will search and remove from all listed props
	prop_locations=("build.prop" "etc/prop.default")
}

help() {
	echo ""
	echo "  lunch           Sets a device/firmware to build from."
	echo "  rebase          [OPTIONAL] Sets a device/firmware to rebase the current lunch'd device/firmware to, i.e. port. EXPERIMENTAL."
	echo "  prep            Performs one-time preparation of the currently lunch'd device/firmware (i.e. extract and de-oat)."
	echo "  flavor          Selects a flavor to build."
	echo "  build           Perform a build/port task."
	echo ""
	echo "[i] All commands have mandatory arguments - simply run the command without any args to see specific command usage."
	echo ""
}


# function used for assigning and validating the lunch or base variables.
lunch_or_rebase() {
	echo ""
	inCommand="$1"
	if [ "${inCommand}" != "lunch" -a "${inCommand}" != "rebase" ]; then
		echo "[!] Invalid function call. NB: this is only supposed to be used internally."
		exit 0
	fi
	(
	source "${KITCHEN_BIN}/common_functions.sh"
	clearError
	shift
	echo "> ${inCommand} $@"
	echo ""
	if [ $# == 0 ]; then
		echo "[i] Syntax is..."
		echo "    ${inCommand} DEVICE"
		echo "...where..."
		echo "    DEVICE             Name or number of the device to select."
		echo ""
		echo "[i] Available devices are:"
		devicesAvailableIndex=0
		for deviceDir in ${KITCHEN_ROOT}/devices/*; do
			echo "    ${devicesAvailableIndex}) ${deviceDir/${KITCHEN_ROOT}\/devices\//}"
			((devicesAvailableIndex++))
		done
	elif [ $# -gt 1 ]; then
		echo "[!] Wrong number of arguments."
	else
		inArg="$1"
		if [ "${inArg}" -ge 0 ]; then
			# get device based on index
			devicesAvailableIndex=0
			for deviceDir in ${KITCHEN_ROOT}/devices/*; do
				if [ "${devicesAvailableIndex}" -eq "${inArg}" ]; then
					inArg="${deviceDir/${KITCHEN_ROOT}\/devices\//}"
					break;
				fi
				((devicesAvailableIndex++))
			done
		fi
		if [ -d "${KITCHEN_ROOT}/devices/${inArg}" ]; then
			# verify critical stuff exists
			for deviceContent in "firmware-update/" "META-INF/"; do
				if [ ! -e "${KITCHEN_ROOT}/devices/${inArg}/${deviceContent}" ]; then
					echo "[!] Error - device/firmware is missing '${deviceContent}' - aborted!"
					setError 64
					exit
				fi
			done
			# ensure the essential build scripts are present
			for essentialBuildScript in "config.sh" "include.sh"; do
				if [ ! -f "${KITCHEN_ROOT}/devices/${inArg}/${essentialBuildScript}" ]; then
					echo "[!] Error - device/firmware is missing '${essentialBuildScript}' - aborted!"
					setError 68
					exit
				fi
			done
			echo "[i] ${inCommand} set: ${inArg}"
			echo "${inArg}" > /tmp/miui_kitchen_cfg_lunch_or_rebase
		else
			echo "[!] Invalid device."
		fi
	fi
	) | tee -a ${KITCHEN_ROOT}/current_env.log
	
	if $(hasErrored); then return $(getErrorCode); fi
	if [ -f "/tmp/miui_kitchen_cfg_lunch_or_rebase" ]; then
		chosenDevice=$(cat "/tmp/miui_kitchen_cfg_lunch_or_rebase")
		# Check for prep
		for deviceContent in "system/" "vendor/" "boot/" "file_contexts"; do
			if [ ! -e "${KITCHEN_ROOT}/devices/${chosenDevice}/${deviceContent}" ]; then
				echo "[!] Warning - device/firmware is missing '${deviceContent}', be sure to run prep before building!"
			fi
		done
		echo "[i] Be sure to run prep if the firmware needs to be (re)prepared for building."
		
		if [ "${inCommand}" == "lunch" ]; then
			MIUI_KITCHEN_CFG_LNCH="${chosenDevice}"
		elif [ "${inCommand}" == "rebase" ]; then
			MIUI_KITCHEN_CFG_BASE="${chosenDevice}"
		fi
		rm "/tmp/miui_kitchen_cfg_lunch_or_rebase"
		
		# set build version here so it stays the same for multi-flavor builds
		# years since 2017
		romBuildMajor=$(( $(date '+%Y') - 2017 ))
		# hours elapsed this year
		romBuildMinor=$(( ( $(date '+%s') - $(date -d '1 Jan' '+%s') ) / 60 / 60 ))
		# full build number
		romBuildNum=${romBuildMajor}.${romBuildMinor}
		echo "[i] ROM build number set to ${romBuildNum}"
	fi
	echo ""
}

lunch() {
	lunch_or_rebase lunch "$@"
}

rebase() {
	echo "[!] Rebase is not yet implemented."
	#lunch_or_rebase rebase "$@"
}

prep() {
	(
	echo ""
	source "${KITCHEN_BIN}/common_functions.sh"
	source "${KITCHEN_BIN}/device_prep.sh"
	echo "> prep $@"
	echo ""
	if [ $# == 0 ]; then
		echo "[i] Syntax is..."
		echo "    prep TASK [OPTION]"
		echo "...where..."
		echo "    TASK is one of:"
		echo "        all              Prepare all firmware files (boot, system, vendor and file_contexts). Will overwrite existing prepared files."
		echo "        missing          Prepare only firmware files that are not detected as prepared."
		echo "    OPTION is zero or more of:"
		echo "        cleanup          If specified, will delete original unnecessary firmware files after they've been extracted/converted/etc."
		echo "        skip-deopt       If specified, de-optimization (a.k.a 'deodex') will NOT be performed. Advanced/debugging use only."
	else
		doDevicePrep "$@"
	fi
	) | tee -a ${KITCHEN_ROOT}/current_env.log
	
	echo ""
	if $(hasErrored); then return $(getErrorCode); fi
}

flavor() {
	(
	source "${KITCHEN_BIN}/common_functions.sh"
	clearError
	echo "> flavor $@"
	echo ""
	if [ $# == 0 ]; then
		echo "[i] Syntax:"
		echo "    flavor {flavor}"
		echo ""
		echo "[i] List of available flavors:"
		flavorsAvailableIndex=0
		for flavorDir in ${KITCHEN_ROOT}/flavors/*; do
			echo "    ${flavorsAvailableIndex}) ${flavorDir/${KITCHEN_ROOT}\/flavors\//}"
			# get info for display
			flavorInfo="{No info found}"
			if [ -f "${flavorDir}/info" ]; then
				flavorInfo=$(cat ${flavorDir}/info)
			fi
			echo "        ${flavorInfo}"
			((flavorsAvailableIndex++))
		done
	elif [ $# -gt 1 ]; then
		echo "[!] Wrong number of arguments."
	else
		inArg="$1"
		if [ "${inArg}" -ge 0 ]; then
			# get device based on index
			flavorsAvailableIndex=0
			for flavorDir in ${KITCHEN_ROOT}/flavors/*; do
				if [ "${flavorsAvailableIndex}" -eq "${inArg}" ]; then
					inArg="${flavorDir/${KITCHEN_ROOT}\/flavors\//}"
					break;
				fi
				((flavorsAvailableIndex++))
			done
		fi
		if [ -d "${KITCHEN_ROOT}/flavors/${inArg}" ]; then
			# verify critical stuff exists
			for flavorContent in "include.sh" "info"; do
				if [ ! -e "${KITCHEN_ROOT}/flavors/${inArg}/${flavorContent}" ]; then
					echo "[!] Error - flavor is missing critical file/folder '${flavorContent}' - aborted!"
					setError 69
					exit
				fi
			done
			echo "[i] flavor set: ${inArg}"
			echo "${inArg}" > /tmp/miui_kitchen_cfg_flavor
		else
			echo "[!] Invalid device."
		fi
	fi
	) | tee -a ${KITCHEN_ROOT}/current_env.log
	
	echo ""
	if $(hasErrored); then return $(getErrorCode); fi
	if [ -f "/tmp/miui_kitchen_cfg_flavor" ]; then
		MIUI_KITCHEN_CFG_FLAV=$(cat "/tmp/miui_kitchen_cfg_flavor")
		rm "/tmp/miui_kitchen_cfg_flavor"
	fi
}

build() {
	(
	echo ""
	source "${KITCHEN_BIN}/common_functions.sh"
	source "${KITCHEN_BIN}/build_rom.sh"
	echo "> build $@"
	echo ""
	if [ $# == 0 ]; then
		echo "[i] Syntax:"
		echo "    build [roots|dirty-roots|img|zip|all]"
		echo ""
		echo "  roots           Build the root directories, i.e. system, vendor and boot-ramdisk"
		echo "  dirty-roots     Like roots, but does not delete pre-existing system/vendor/boot-ramdisk"
		echo "  img             Build img files from existing roots i.e. system.img, vendor.img and boot.img. Does not imply roots."
		echo "  zip             Create .new.dat.br files and pack to flashable ZIP. Does not imply roots or img."
		echo "  all             Perform roots, img then zip all in one"
	elif [ $# -gt 1 ]; then
		echo "[!] Wrong number of arguments."
	elif [ "$1" != "roots" -a "$1" != "dirty-roots" -a "$1" != "img" -a "$1" != "zip" ]; then
		echo "[!] Unknown argument: '${1}'."
	else
		doBuild "$@"
	fi
	) | tee -a ${KITCHEN_ROOT}/current_env.log
	
	echo ""
	if $(hasErrored); then return $(getErrorCode); fi
}

echo ""
echo "[i] Ready. Run 'help' to see all kitchen commands."
echo ""
if [ -f "${KITCHEN_ROOT}/current_env.log" ]; then
	# TODO: Just delete for now, but should probably rotate this
	rm "${KITCHEN_ROOT}/current_env.log"
fi

# set prompt
PS1='( Lunch: '\${MIUI_KITCHEN_CFG_LNCH}'; Rebase: '\${MIUI_KITCHEN_CFG_BASE}'; Flavor: '\${MIUI_KITCHEN_CFG_FLAV}' )\n'${PS1_ORIGINAL}

loadKitchenConfig
