#!/bin/bash

flavorDoRoots() {
	echo "    [#] Debug/insecure mode changes..."
	addOrReplaceOutProp persist.sys.usb.config= persist.sys.usb.config=mtp,adb
	addOrReplaceOutProp ro.adb.secure= ro.adb.secure=0
	#addOrReplaceOutProp ro.debuggable= ro.debuggable=1
	#addOrReplaceOutProp ro.secure= ro.secure=0
	cp -af "${flavorPath}/adbd_insecure" "${miuiOutPath}/system/bin/adbd"
	
	# DISABLED: godmode adbd needs SEPolicy changes which I can't figure out. Can probably do something with magisk's runtime sepolicy injection if I ever really need this.
	# 'God-mode' adbd (allows root daemon on user-builds)
	#cp -af "${flavorPath}/adbd_godmode" "${miuiOutPath}/system/bin/adbd"
	#sed -i -e 's/u:r:adbd:s0/u:r:init:s0/' "${miuiOutPath}/boot/ramdisk/init.usb.rc"
	#sed -i -e 's/u:object_r:adbd_exec:s0/u:object_r:system_file:s0/' "./target/boot/ramdisk/file_contexts"
}