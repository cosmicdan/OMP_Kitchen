#!/bin/bash

clearError() {
	rm -f /tmp/miui_kitchen_last_error
}

# Error codes start at 64
# 64 = Device firmware files are missing critical content
# 65 = Device firmware files missing for preparation
# 66 = Device firmware preparation failure
# 67 = Attempted build with flavor not set or missing
# 68 = Device tree is missing essential build script include
# 69 = Flavor is missing critical files
# 70 = Generic invalid or unrecognized function argument
setError() {
	echo $1 > /tmp/miui_kitchen_last_error
}

# TODO: need to actually test this
hasErrored() {
	if [ -f "/tmp/miui_kitchen_last_error" ]; then
		if [ "$(cat /tmp/miui_kitchen_last_error)" -gt 0 ]; then
			true
		fi
	fi
	false
}

getErrorCode() {
	errorCode="$(cat /tmp/miui_kitchen_last_error)"
	rm -f "/tmp/miui_kitchen_last_error"
	if [ "${errorCode}" -gt 0 ]; then
		echo "${errorCode}"
	fi
}