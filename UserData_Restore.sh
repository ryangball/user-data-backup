#!/bin/bash

migAsstIcon="/Applications/Utilities/Migration Assistant.app/Contents/Resources/MigrateAsst.icns"
errorIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
scriptName=$(basename "$0")
log="/Volumes/$share/_Logs/$loggedInUser.log"
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
    finish "$1"
}

writelog "======== Starting $scriptName ========"

# Open a full screen jamfHelper window
writelog "Launching jamfHelper..."
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -title "" -icon "$migAsstIcon" \
    -heading "Please wait as your account data is restored..." -description "
This process may take some time.
Do not turn off your machine until this message closes." &
jamfHelperPID=$(/bin/echo $!)

# Mount network share
/bin/mkdir "/Volumes/$share" | while read -r LINE; do writelog "$LINE"; done;
/sbin/mount_smbfs "//${shareUser}:${sharePass}@${server}/${share}" "/Volumes/$share" | while read -r LINE; do writelog "$LINE"; done;

if [[ "$?" -ne "0" ]]; then
    writelog "Mount failed, exiting"
    /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -title "Restore Failed" -icon "$errorIcon" -description "Restore failed. Could not mount $server/$share" -button1 "OK" -defaultButton "1" &
    kill "$jamfHelperPID" > /dev/null 2>&1 && wait $! > /dev/null
    finish 1
fi

# Check for Existing Backup
if [ ! -d "/Volumes/$share/$loggedInUser" ]; then
    /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -title "Restore Failed" -icon "$errorIcon" -description "No backups found for $loggedInUser. Restore cancelled." -button1 "OK" -defaultButton "1" &
else
    # Stamp Log File - Starting rsync
    writelog " "
    writelog "Starting rSync RESTORE of $loggedInUser"

    # Restore Users Home Directory
    /usr/bin/rsync -vzrpog --update --ignore-errors --force --progress --log-file="/Volumes/$share/_Logs/$loggedInUser.log" /Volumes/$share/"$loggedInUser"/ /Users/"$loggedInUser"/

    # Stamp Log File - rsync Complete
    writelog " "
    writelog "Completed rSync RESTORE of $loggedInUser"

    /bin/sleep 10

    # Deletes Remote Backup of Users Files
    /bin/rm -fdr "/Volumes/$share/$loggedInUser" | while read -r LINE; do writelog "$LINE"; done;

	# Run CHOWN
	/usr/sbin/chown -R "$loggedInUser:staff" "/Users/$loggedInUser/" | while read -r LINE; do writelog "$LINE"; done;

	# Kill Finder
    /usr/bin/killall Finder

    /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -title "Restore Complete" -icon "$migAsstIcon" -description "Restore completed for $loggedInUser" -button1 "OK" -defaultButton "1" &
fi

# Unmount network share
/sbin/umount "/Volumes/$share" | while read -r LINE; do writelog "$LINE"; done;

kill "$jamfHelperPID" > /dev/null 2>&1 && wait $! > /dev/null

finish 0