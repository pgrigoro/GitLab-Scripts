o#!/bin/bash
if [ `id -u` -ne 0 ];then
   echo "this backup script must be exec as root." exit
fi

save_days=30 #keep days
# gitlab_rails['backup_path'] = "/var/opt/gitlab/backups" configed in /etc/gitlab/gitlab.rb
bakdir_gitlab="/var/opt/gitlab/backups" 
bakdir_authorized_keys="/var/opt/gitlab/.ssh/"
bakdir_sshhostkeys="/etc/ssh/"
bakdir_gitlabrb="/etc/gitlab/"

# mount dir
mountDir=/mnt/gitlabbackup
remoteServer=/10.193.90.156/gitlab_backup_donot_move

echo =====================================================
echo "daily backup begin"
date

#check the backup files
if [ -e $mountDir ];then
   echo "The $mountDir exists"
else
   echo "Create the dictionary:$mountDir"
   mkdir -p $mountDir
fi
#check the backup files mounted status
mount -l -t cifs | grep "$mountDir"
if [ $? -eq 0 ]; then
   echo "the $mountDir is mounted"
else
   echo "$mountDir not a mountpoint,backup failed"
   exit 1
fi

# gitlab backup 
gitlab-rake gitlab:backup:create

cd $mountDir
#delete the old files--15 days 
find -maxdepth 1 -name "*.tgz" -mtime +"$save_days" -exec rm -f {} \;

filename=gitlabbackup_$(date +%Y%m%d_%H%M)
tar -czPf $filename.tgz $bakdir_gitlab $bakdir_authorized_keys $bakdir_sshhostkeys $bakdir_gitlabrb

echo "daily backup end"
date
echo =====================================================
