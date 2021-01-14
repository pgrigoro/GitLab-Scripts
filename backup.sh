#!/bin/bash
# backup script triggered by cron daily, weekly, monthly -> save backup with raketask to nfs share and delete old backups

BACKUP_DIR=$(grep "gitlab_rails\['backup_path'\]" /etc/gitlab/gitlab.rb | cut -d= -f2 | tr -d ' ' | sed 's/"//g') # see /etc/gibtlab/gitlab.rb -> gitlab_rails['backup_path']

LOG_FILE="/var/log/gitlab/scripts/gitlab_backup.log"
ADMIN_EMAIL="admin@xyz.com"
GITLAB_EMAIL="gitlab@xyz.com"
######################################################################################

writeLog(){
  logger -s "$1" 2>> "$LOG_FILE"
}

sendMail(){ # message subject receiver
  echo -e "$1 \n\n Do not reply to this email."  | mail -aFROM:$GITLAB_EMAIL -s "$2" "$3"
}

######################################################################################

case $1 in
  d) # daily 7 days
  gitlab-rake gitlab:backup:create SKIP=registry > $BACKUP_DIR/daily_latest.log 2>&1
  BACKUP_FILE=$(grep "Creating backup archive:" $BACKUP_DIR/daily_latest.log | cut -d ' ' -f4)
  mv $BACKUP_DIR/$BACKUP_FILE $BACKUP_DIR/daily
  RM=$(ls -rt -d $BACKUP_DIR/daily/* | head -n-7 | sed '/^\s*$/d')
  if [ -n "$RM"  ] ; then
    writeLog "Delete oldest daily backup: $RM"
    rm -r $(ls -rt -d $BACKUP_DIR/daily/* | head -n-7 | sed '/^\s*$/d')
  fi
  # sendMail "$(cat $BACKUP_DIR/daily_latest.log)\n" "Gitlab daily backup finish" "$ADMIN_EMAIL"
  writeLog "daily backup done"
  ;; 

  w) # weekly 4
  gitlab-rake gitlab:backup:create > $BACKUP_DIR/weekly_latest.log 2>&1
  BACKUP_FILE=$(grep "Creating backup archive:" $BACKUP_DIR/weekly_latest.log | cut -d ' ' -f4)
  mv $BACKUP_DIR/$BACKUP_FILE $BACKUP_DIR/weekly
  RM=$(ls -rt -d $BACKUP_DIR/weekly/* | head -n-4 | sed '/^\s*$/d')
  if [ -n "$RM"  ] ; then
    writeLog "Delete oldest weekly backup: $RM"
    rm -r $(ls -rt -d $BACKUP_DIR/weekly/* | head -n-4 | sed '/^\s*$/d')
  fi
  # sendMail "$(cat $BACKUP_DIR/weekly_latest.log)\n" "Gitlab weeklweekly backup finish" "$ADMIN_EMAIL"
  writeLog "weekly backup done"
  ;; 

  m) # monthly 6 month
  gitlab-rake gitlab:backup:create > $BACKUP_DIR/monthly_latest.log 2>&1
  BACKUP_FILE=$(grep "Creating backup archive:" $BACKUP_DIR/monthly_latest.log | cut -d ' ' -f4)
  mv $BACKUP_DIR/$BACKUP_FILE $BACKUP_DIR/monthly
  RM=$(ls -rt -d $BACKUP_DIR/monthly/* | head -n-6 | sed '/^\s*$/d')
  if [ -n "$RM"  ] ; then
    writeLog "Delete oldest monthly backup: $RM"
    rm -r $(ls -rt -d $BACKUP_DIR/monthly/* | head -n-6 | sed '/^\s*$/d')
  fi
  sendMail "$(cat $BACKUP_DIR/monthly_latest.log)\n Please test" "Gitlab monthly backup finish" "$ADMIN_EMAIL"
  writeLog "monthly backup done"
  ;; 
  *) echo "wrong param"
  ;;
esac


