#!/bin/bash

deviceDoRoots() {
	echo "    [i] FBE temporarily disabled (causes userdata permission issues on xiaomi.eu ROM's; still investigating cause)"
	# Disabled for now (needs debugging)
	#echo "    [#] Modify vendor for file-based encryption (compatible TWRP required) ..."
	#verifyFilesExist "${miuiOutPath}/vendor/etc/fstab.qcom"
	#sed -i -e '/userdata/ s/forceencrypt=footer/fileencryption=ice/' "${miuiOutPath}/vendor/etc/fstab.qcom"
	#sed -i -e '/userdata/ s/encryptable=footer/fileencryption=ice/' "${miuiOutPath}/vendor/etc/fstab.qcom"
}

updaterScriptFooter() {
	echo "ui_print(\" \");"
	echo "ui_print(\"All done! Remember:\");"
	echo "ui_print(\" - Flash FBE-Disable ZIP to REMOVE\");"
	echo "ui_print(\"   file-based encryption (optional)\");"
	echo "ui_print(\" \");"
}