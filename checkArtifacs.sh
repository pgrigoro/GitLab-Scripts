#!/bin/bash

ARTIFACTS_DIR="/var/opt/gitlab/gitlab-rails/shared/artifacts/$(date +%Y_%m)/"
LOG_FILE="/var/log/gitlab/scripts/checkArtifacts.log"
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

for proj in $(ls "$ARTIFACTS_DIR") ; do 
  # echo $ARTIFACTS_DIR$proj
  RM=$(ls -rt -d $ARTIFACTS_DIR$proj/* | head -n-3 | sed '/^\s*$/d')
  if [ -n "$RM"  ] ; then
    writeLog "Delete: $RM"
    rm -r $(ls -rt -d $ARTIFACTS_DIR$proj/* | head -n-3 | sed '/^\s*$/d')
  fi
done
