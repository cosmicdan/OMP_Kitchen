#!/bin/bash

# Common functions shared by multiple scripts

checkAndMakeTmp() {
	if [ -d "./tmp" ]; then
		echo "[!] An old ./tmp/ folder exists. This is usually cleaned up; there may be WIP changes here or an error previously occured."
		echo "    Aborting for safety reasons. Please delete or move ./tmp/ when you're sure you want to discard it."
		exit -1
	fi
	mkdir ./tmp
}

cleanupTmp() {
	rm -rf "./tmp"
}

verifyFilesExist() {
	for filepath in "$@"; do
		if [ ! -f "${filepath}" -a ! -d "${filepath}" ]; then
			echo "[!] Error - cannot find file/directory '${filepath}'"
			echo "    Aborted."
			exit -1
		fi
	done
}

# Arguments must specify full path without leading slash, e.g. system/somedir/someFile.ext
# If a directory is provided, it will NOT overwrite anything unless the first argument is -f
addToTargetFromDevice() {
	RSYNC_OPTS=--ignore-existing
	for srcPath in "$@"; do
		if [ "${srcPath}" == "-f" ]; then 
			RSYNC_OPTS=
			continue
		fi
		if [ -d "./src_device_${srcPath}" ]; then
			# is a directory
			mkdir -p "./target/${srcPath}" > /dev/null
			rsync -a ${RSYNC_OPTS} "src_device_${srcPath}" "target/${srcPath}"
		else 
			verifyFilesExist "./src_device_${srcPath}"
			cp -af "./src_device_${srcPath}" "./target/${srcPath}"
		fi
	done
}

# Arguments must specify full path without leading slash, e.g. system/somedir/someFile.ext
removeFromTarget() {
	for targetFilePath in "$@"; do
		(
		shopt -s extglob # expands any wildcards inside arguments
		# Should I verifyFilesExist first?
		rm -r ./target/${targetFilePath}
		)
	done
}

# Thanks to "Nominal Animal" @ linuxquestions.org
getEscapedVarForSed() {
	 # start with the original pattern
    escaped="$1"

    # escape all backslashes first
    escaped="${escaped//\\/\\\\}"

    # escape slashes
    escaped="${escaped//\//\\/}"

    # escape asterisks
    escaped="${escaped//\*/\\*}"

    # escape full stops
    escaped="${escaped//./\\.}"    

    # escape [ and ]
    escaped="${escaped//\[/\\[}"
    escaped="${escaped//\[/\\]}"

    # escape ^ and $
    escaped="${escaped//^/\\^}"
    escaped="${escaped//\$/\\\$}"

    # remove newlines
    escaped="${escaped//[$'\n']/}"

    # Now, "$escape" should be safe as part of a normal sed pattern.
    # Note that it is NOT safe if the -r option is used.
	echo "${escaped}"
}

# Args:
# 1) prop keyname with trailing =
# 2) full replacement prop keyname=value string. If empty, the prop will be commented-out instead
addOrReplaceTargetProp() {
	propKey="$1"
	propKeyValueNew="$2"
	propReplaced=FALSE
	for propFile in "${prop_locations[@]}"; do
		if grep -q ${propKey} "./target/system/${propFile}"; then
			propKeyEscaped=`getEscapedVarForSed "${propKey}"`
			if [ "${propKeyValueNew}" == "" ]; then
				# missing second parameter = comment-out instead of replace
				sed -i "/${propKeyEscaped}/s/^/### Removed by CosmicDan's MIUI kitchen ### /g" "./target/system/${propFile}"
			else
				replacementEscaped=`getEscapedVarForSed "${propKeyValueNew}"`
				sed -i "s|${propKeyEscaped}.*|${replacementEscaped}|g" "./target/system/${propFile}"
			fi
			propReplaced=TRUE
			# don't break - we want to find and replace all occurances (in every prop file)
		fi
	done
	if [ "${propReplaced}" == "FALSE" ]; then
		if [ "${propKeyValueNew}" == "" ]; then
			# missing second parameter = comment-out instead of replace
			echo "    [!] Property was not found for removal, continuing anyway: ${propKey}"
		else
			# prop wasn't found, add it
			echo "${propKeyValueNew}" >> "./target/system/${prop_locations[0]}"
		fi
	fi
}

# Args:
# 1) Literal string to search for
# 2) File to do insertion on
# n) Literal string(s) to insert before that line (can use empty string for empty lines)
# Don't try and use this where partial matches are possible (i.e. ensure the before String is 100% unique) - it's too simple for that :)
addLineBefore() {
	searchString="$1"
	fileToInsert="$2"
	searchStringEscaped=`getEscapedVarForSed "${searchString}"`
	
	# loop over remaining arguments
	shift 2
	for insertString in "$@"; do
		insertStringEscaped=`getEscapedVarForSed "${insertString}"`
		sed -i "/${searchStringEscaped}/ { N; s/${searchStringEscaped}\n/${insertStringEscaped}\n&/ }" "${fileToInsert}"
	done
}

getConfig() {
	configKey="$1"
	configLine=`grep ${configKey} "./config.device.cfg" | tail -1`
	echo "${configLine#*=}"
}

setError() {
	touch ./tmp/has_errored
	exit -1
}

checkError() {
	if [ -f ./tmp/has_errored ]; then
		exit
	fi
}