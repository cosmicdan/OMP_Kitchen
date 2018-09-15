#!/bin/bash

# Make target from src script
#
# This script is for creating the MIUI target (port/mod). This is where most of the work happens.
#

source ./bin/common_functions.sh



###############
### Config
###############

# Entries in MIUI BOOTCLASSPATH that should be skipped
bootclasspath_miui_blacklist=()
# This was taken from the GSI experiment, kept only for posterity and future reference, in case this is ever needed
#bootclasspath_miui_blacklist=("com.qualcomm.qti.camera.jar" "QPerformance.jar")
	# TODO: These BOOTCLASSPATH entries are also unique to MIUI, but may be vendor specific - need to investigate:
		# /system/framework/tcmiface.jar
		# /system/framework/telephony-ext.jar
		# /system/framework/WfdCommon.jar
		# /system/framework/oem-services.jar

# Specify possible prop file locations. Used for reading/writing keys and values across the build process.
# Precendence matters:
# - Merge props will be pulled from the first found match
# - Additional props will go into the first file in the list
# - Removals, however, will search and remove from all listed props
prop_locations=("build.prop" "etc/prop.default")


###############
### Get arguments
###############

# Defaults
SHOW_HELP=TRUE
QUICK=FALSE

POSITIONAL=()
while [[ $# -gt 0 ]]; do
	key="$1"

	case $key in
		user)
		SHOW_HELP=FALSE
		DEBUG=FALSE
		shift
		;;
		debug)
		SHOW_HELP=FALSE
		DEBUG=TRUE
		shift
		;;
		quick)
		SHOW_HELP=FALSE
		QUICK=TRUE
		shift
		;;
		-h)
		SHOW_HELP=TRUE
		shift
		;;
		# TODO: nomods flag to exclude custom mods (i.e. essential fixes only)
		*)    # unknown option
		POSITIONAL+=("$1") # add it to an array for later
		shift
		;;
	esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# For extra unrecognized arguments
#if [[ -n $1 ]]; then
    
#fi

# Show usage if -h was specified
echo ""
if [ "${SHOW_HELP}" == "TRUE" ]; then
	echo "[i] Usage for 01_make_target_from_src.sh:"
	echo "    [user|debug]"
	echo "        # Do user or debug build. Debug build is ADB-insecure-on-boot for development purposes, or if you're a l33t hax0r who doesn't need basic security."
	echo "    [quick]"
	echo "        # Do a quick build, which will only copy main target files if the directory doesn't exist."
	echo "        # Useful for testing kitchen development changes."
	echo ""
	exit -1
fi



###############
### Verify arguments
###############

if [ "${DEBUG}" == "FALSE" ]; then
	echo "[!] User build requested but currently unsupported."
	echo ""
	exit -1
fi



###############
### Build environment checks
###############

echo ""
echo "------------------------------------------"
echo "[i] 01_make_target_from_src started."
echo ""

if [ -d "./target" -a "${QUICK}" == "FALSE" ]; then
	echo "[!] A ./target/ folder already exists."
	echo "    Aborting for safety reasons."
	exit -1
fi

if [ "${QUICK}" == "TRUE" ]; then
	echo "[i] Quick mode enabled. Will only copy the bulk of files if target does not exist."
fi

mkdir ./target

{
IFS=
echo "[#] Verifying config and sources..."
# sed is used here to skip over blank lines (kind of)
sed '/^[ \t]*$/d' "./config.deviceid.cfg" | while read -r LINE; do
	if [[ "${LINE}" == "#"* ]]; then
		# skip comments
		continue
	fi
	if grep -q ${LINE} "./src_device_system/${prop_locations[0]}" | tail -1; then
		deviceId="${LINE#*=}"
		# verified config key=value exists in device source, now get the value from port
		propKey="${LINE%=*}="
		propPortSearch=`grep ${propKey} "./src_port_system/${prop_locations[0]}" | tail -1`
		if [ "${propPortSearch}" == "" ]; then
			echo "[!] Error - could not find ${propKey} in port source ${prop_locations[0]}"
			echo "    Aborted."
			setError
		fi
		portId="${propPortSearch#*=}"
		setBuildInfo deviceId=${deviceId}
		setBuildInfo portId=${portId}
	else
		# Error-out if the prop key wasn't found in the device source
		echo "[!] Error - config.deviceid.cfg is incorrect (could not find ${LINE} in device source ${prop_locations[0]})."
		echo "    Aborted."
		setError
	fi
	# always break - config.deviceid.cfg can only have one key=value entry
	break;
done

checkError
refreshBuildInfo
echo "    [i] Base device is '${deviceId}', port device is '${portId}'"

checkAndMakeTmp


###############
### Copy files
###############

if [ "${QUICK}" == "FALSE" -o ! -d "./target/system" ]; then
	echo "[#] Copying port system..."
	mkdir -p "./target/system"
	rsync -a "src_port_system/" "target/system/"
	echo "[#] Copying device vendor..."
	mkdir -p "./target/vendor"
	rsync -a "src_device_vendor/" "target/vendor/"
	echo "[#] Copying device boot..."
	mkdir -p "./target/boot/ramdisk"
	rsync -a "src_device_boot/" "target/boot/"
fi

# Debug = god-mode ADBD
if [ "${DEBUG}" == "TRUE" ]; then
	echo "[#] Making insecure ADB on boot changes..."
	addOrReplaceTargetProp ro.adb.secure= ro.adb.secure=0
	addOrReplaceTargetProp ro.debuggable= ro.debuggable=1
	addOrReplaceTargetProp persist.sys.usb.config= persist.sys.usb.config=mtp,adb
	# 'God-mode' adbd (allows root daemon on user-builds)
	cp -af "./patches/adbd_godmode" "./target/system/bin/adbd"
	sed -i -e 's/u:r:adbd:s0/u:r:su:s0/' "./target/boot/ramdisk/init.usb.rc"
else
	echo "[i] Making secure/user-mode changes..."
	addOrReplaceTargetProp ro.adb.secure= ro.adb.secure=1
	addOrReplaceTargetProp ro.debuggable= ro.debuggable=0
	addOrReplaceTargetProp persist.sys.usb.config= persist.sys.usb.config=mtp
fi



###############
### Mods/Patches
###############

echo "[#] Patches and mods ..."
echo "    [#] Enabling file-based encryption for Userdata (compatible TWRP required)..."
verifyFilesExist ./target/vendor/etc/fstab.qcom
sed -i -e '/userdata/ s/forceencrypt=footer/fileencryption=ice/' "./target/vendor/etc/fstab.qcom"
sed -i -e '/userdata/ s/encryptable=footer/fileencryption=ice/' "./target/vendor/etc/fstab.qcom"



###############
### Props
###############

echo "" >> "./target/system/${prop_locations[0]}"
echo "######" >> "./target/system/${prop_locations[0]}"
echo "# Additional by CosmicDan's kitchen" >> "./target/system/${prop_locations[0]}"
echo "######" >> "./target/system/${prop_locations[0]}"
echo "" >> "./target/system/${prop_locations[0]}"

# First, remove desired props listed in props.remove
echo "    [#] Removing specific props..."
if [ -f "./patches/props.remove" ]; then
	# sed is used here to skip over blank/empty lines
	sed '/^[ \t]*$/d' "./patches/props.remove" | while read -r LINE; do
		if [[ "${LINE}" == "#"* ]]; then
			# skip comments
			continue
		fi
		propKey="${LINE%=*}="
		addOrReplaceTargetProp "${propKey}"
	done
fi

# Merge in device-provided props
echo "    [#] Merging device-provided props..."
if [ -f "./patches/props.merge" ]; then
	# sed is used here to skip over blank/empty lines
	sed '/^[ \t]*$/d' "./patches/props.merge" | while read -r LINE; do
		if [[ "${LINE}" == "#"* ]]; then
			# skip comments
			continue
		fi
		propKey="${LINE%=*}="
		for propFile in "${prop_locations[@]}"; do
			# we only check system here because we're expected to be using device original vendor and initramfs
			propSearch=`grep ${propKey} "./src_device_system/${propFile}" | tail -1`
			if [ "${propSearch}" != "" ]; then
				propFound="${propSearch}"
				# break because our prop list is expected to be in order of highest-to-lowest precedence
				break
			fi
		done
		if [ "${propFound}" == "" ]; then
			# Error-out if the prop key wasn't found in the device source
			echo "[!] Error - cannot find prop from device source with key: ${propKey}"
			echo "    Aborted."
			setError
		else
			addOrReplaceTargetProp "${propKey}" "${propFound}"
			propFound=""
		fi
	done
fi

checkError

# Add/replace literal props from props.additional
echo "    [#] Additional custom props..."
if [ -f "./patches/props.additional" ]; then
	# sed is used here to skip over blank/empty lines
	sed '/^[ \t]*$/d' "./patches/props.additional" | while read -r LINE; do
		if [[ "${LINE}" == "#"* ]]; then
			# skip comments
			continue
		fi
		propKey="${LINE%=*}="
		addOrReplaceTargetProp "${propKey}" "${LINE}"
	done
fi

}

###############
### Device conversion
###############

echo "[#] Device conversion tasks..."
# Device feature definitions
# TODO: Have a closer look at this XML; might be able to unlock some hidden or experimental features
echo "    [i] Copy device features..."
addToTargetFromDevice "system/etc/device_features/"
echo "    [i] Copy services, frameworks and permissions [TODO: deodex so this actually matters; GitHub issue #1]..."
addToTargetFromDevice "system/etc/init/"
addToTargetFromDevice "system/etc/permissions/"
echo "    [i] Copy extra media files from device..."
addToTargetFromDevice "system/media/audio/"
addToTargetFromDevice "system/media/lockscreen/"
# Replace all prop occurances of portId with deviceId
echo "    [i] Mass-rebrand from '${portId}' to '${deviceId}'..."
for propFile in "${prop_locations[@]}"; do
	sed -i "s|${portId}|${deviceId}|g" "./target/system/${propFile}"
done
# Rename some MIUI theme stuff
# TODO: Change to a global find-and-rename
mv ./target/system/media/wallpaper/${portId}_wallpaper.jpg ./target/system/media/wallpaper/${deviceId}_wallpaper.jpg 
mv ./target/system/media/lockscreen/${portId}_lockscreen.jpg ./target/system/media/lockscreen/${deviceId}_lockscreen.jpg 





###############
### Misc. fixups
###############

#echo "[#] Misc. fixups..."
# Nothing yet




###############
### Finished
###############

echo ""
echo "[i] 01_make_target_from_src finished."
echo "------------------------------------------"
echo ""

cleanupTmp

