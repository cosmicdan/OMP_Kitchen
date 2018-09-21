#!/bin/bash

deviceDoRoots() {
	echo "    [i] FBE temporarily disabled (causes issues on xiaomi.eu ROM's for some reason"
	# Disabled for now (needs debugging)
	#echo "    [#] Modify vendor for file-based encryption (compatible TWRP required) ..."
	#verifyFilesExist "${miuiOutPath}/vendor/etc/fstab.qcom"
	#sed -i -e '/userdata/ s/forceencrypt=footer/fileencryption=ice/' "${miuiOutPath}/vendor/etc/fstab.qcom"
	#sed -i -e '/userdata/ s/encryptable=footer/fileencryption=ice/' "${miuiOutPath}/vendor/etc/fstab.qcom"
}

updaterScriptFooter() {
	echo "ui_print(\" \");"
	echo "ui_print(\"All done! Remember:\");"
	echo "ui_print(\"1) Flash Magisk to avoid fastboot-kick!\");"
	echo "ui_print(\"2) Flash FBE-Disable ZIP to REMOVE\");"
	echo "ui_print(\"   file-based encryption (optional)\");"
	echo "ui_print(\" \");"
}