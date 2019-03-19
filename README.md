# User Data Backup/Restore
These scripts will allow you to backup a specific user's home folder on a Mac to a network share. Then on a new machine you can restore that data easily after the user logs in for the first time. These scripts are intended to be used as policies in Jamf Pro but could be modified to fit the needs of other environments.

#### Requirements:
- Two policies in Jamf Pro (one for backup, one for restore) with their associated scripts set as payloads
    - Parameter 4 field in both policies set to the name of the server where the data will be backed up to/restored from, i.e. server.contoso.com
    - Parameter 5 field in both policies set to the name of the share on the server, i.e. share_name
    - Parameter 6 field in both policies set to a user account that has read/write access to the share (if authentication is required)
    - Parameter 7 field in both policies set to the password of the above user account (if authentication is required)
*Note: Full path using examples above would be: smb://server.contoso.com/share_name*

#### Instructions for Technicians:
1) Login to the Mac **as the end user you want to backup**
2) Run the **User Data Backup Tool**
3) Either re-image or obtain the new machine for the user
4) Login to the new machine **as the end user**
5) Run the **User Data Restore Tool**

*Note: Backups are deleted from the network share upon successful restore*
