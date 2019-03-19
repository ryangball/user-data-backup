#!/bin/bash

timeMachineIcon="/Applications/Time Machine.app/Contents/Resources/backup.icns"
errorIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
scriptName=$(basename "$0")
log="/private/tmp/user_data_backup.log"
loggedInUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

# Pass in parameters into script for server/share, and user/pass for authentication to the network share
# If no auth required you can leave parameters 6 and 7 blank
[[ -n "$4" ]] && server=$4
[[ -n "$5" ]] && share=$5
[[ -n "$6" ]] && shareUser=$6
[[ -n "$7" ]] && sharePass=$7

function writelog () {
    DATE=$(date +%Y-%m-%d\ %H:%M:%S)
    /bin/echo "${1}"
    /bin/echo "$DATE" " $1" >> "$log"
}

function finish () {
    writelog "======== Finished $scriptName ========"
    kill "$jamfHelperPID" > /dev/null 2>&1 && wait $! > /dev/null
    exit "$1"
}

writelog "======== Starting $scriptName ========"

# Open a full screen janfHelper window
writelog "Launching jamfHelper..."
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon "$timeMachineIcon" \
    -heading "Please wait as your account data is backed up..." -description "
This process may take some time.
Do not turn off your machine until this message closes." &
jamfHelperPID=$(/bin/echo $!)

# Mount network share
/bin/mkdir "/Volumes/$share" | while read -r LINE; do writelog "$LINE"; done;
/sbin/mount_smbfs "//${shareUser}:${sharePass}@${server}/${share}" "/Volumes/$share" | while read -r LINE; do writelog "$LINE"; done;

if [[ "$?" -ne "0" ]]; then
	writelog "Mount failed; exiting."
    kill "$jamfHelperPID" > /dev/null 2>&1 && wait $! > /dev/null
	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -title "Backup Failed" \
        -icon "$errorIcon" -description "Backup failed. Could not mount $server/$share" -button1 "OK" -defaultButton "1" &
    finish 1
fi

 # Migrate the log from the temporary local directory, to the share
/bin/mv "$log" "/Volumes/$share/_Logs/$loggedInUser.log"
log="/Volumes/$share/_Logs/$loggedInUser.log"
/usr/sbin/chown admin:staff "$log"
/bin/chmod 777 "$log"

writelog "Starting rSync backup of $loggedInUser..."
writelog " "

# Create a directory to store the user's data on the share
/bin/mkdir -p "/Volumes/$share/$loggedInUser" | while read -r LINE; do writelog "$LINE"; done;

# Backup Users Home Directory
writelog "======== Begining rSync logging ========"
/usr/bin/rsync -vzrpog --update --delete --ignore-errors --force \
    --exclude='Library' --exclude='Microsoft User Data' --exclude='.DS_Store' --exclude='.Trash' --exclude='iTunes' --exclude='Downloads' \
    --progress --log-file="$log" "/Users/$loggedInUser/" "/Volumes/$share/$loggedInUser/"
writelog "======== Finished rSync logging ========"

writelog " "
writelog "Completed rSync backup of $loggedInUser"

# Unmount share
/sbin/umount "/Volumes/$share" | while read -r LINE; do writelog "$LINE"; done;

# Kill jamfHelper
kill "$jamfHelperPID" > /dev/null 2>&1 && wait $! > /dev/null

# Let the user know the process is completed
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -title "Backup Complete" \
    -icon "$timeMachineIcon" \
    -description "Backup completed for $loggedInUser. Please verify the data on the $share Share on \"$server\" before you erase data on this machine." \
    -button1 "OK" -defaultButton "1" -timeout "120" &

finish 0