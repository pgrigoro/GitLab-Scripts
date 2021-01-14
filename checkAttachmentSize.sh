#!/bin/bash
# check attachment size for each repo/group

UPLOADS="/var/opt/gitlab/gitlab-rails/uploads/"
TOKEN="YOUR API TOKEN"
GITLAB_API="https://YOUR_GITLAB_URL.XYZ.COM/api/v4"
PROJECTS_API="$GITLAB_API/projects"
USER_API="$GITLAB_API/users"

MAX_ARCHIVE="20000" # size to cleanup repo (20MB)
MAX_BLOCK="50000" # size to archive repo (50MB)

LOG_FILE="/var/log/gitlab/scripts/checkAttachments.log"
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

CHECK=$(du $UPLOADS --exclude='-' --exclude="tmp" | grep -oP "^.*(?=/[0-9a-f]{32}$)" | cut -f2 | sort | uniq  | xargs du -s |sed -e "s|$UPLOADS||g" ) 

while read -r line; do
  if [[ "$line" =~ ^([0-9]+)$'\t'+(.*)$ ]] ; then
    REPO_SIZE=${BASH_REMATCH[1]}
    REPO_PATH=$(echo ${BASH_REMATCH[2]} | sed -e 's/\//%2F/g')

    REPO_STATUS=`curl -s --request GET --header "PRIVATE-TOKEN: $TOKEN" "$PROJECTS_API/$REPO_PATH"`
    REPO_ID=`echo $REPO_STATUS| jq '.id'`
    REPO_PATH_NAMESPACE=`echo $REPO_STATUS | jq '.path_with_namespace' | sed -e 's/"//g'`
    REPO_NAME=`echo $REPO_STATUS | jq '.name' | sed -e 's/"//g'`
    REPO_OWNER_ID=`echo $REPO_STATUS | jq '.owner.id'`
    REPO_ARCHIVED=`echo $REPO_STATUS | jq '.archived'`
    REPO_URL=`echo $REPO_STATUS | jq '.web_url' | sed -e 's/"//g'`

    echo "$SIZE $REPO_PATH + $REPO_SIZE"
    if [ "$REPO_SIZE" -gt "$MAX_BLOCK" ] ; then
      writeLog "$REPO_PATH is greater $MAX_BLOCK ($REPO_SIZE)"
      echo "$REPO_PATH is greater $MAX_BLOCK ($REPO_SIZE)"
      # delete some old things?
      # REPO_ARCHIVED=$(curl -s --request POST --header "PRIVATE-TOKEN: $TOKEN" "$PROJECTS_API/$REPO_PATH/archive" | jq '.archived')
      # writeLog "archive $REPO_PATH because its greater than $MAX_ARCHIVE ($REPO_SIZE)"
      echo "archive $REPO_PATH because its greater than $MAX_ARCHIVE ($REPO_SIZE)"
      REPO_OWNER=`curl -s --request GET --header "PRIVATE-TOKEN: $TOKEN" "$USER_API/$REPO_OWNER_ID"`
      REPO_OWNER_NAME=`echo $REPO_OWNER | jq '.name' | sed -e 's/"//g'`
      REPO_OWNER_MAIL=`echo $REPO_OWNER | jq '.email' | sed -e 's/"//g'`

      # sendMail "Hello Admin,\n\n$REPO_PATH_NAMESPACE was archived because it has exceeded the maximum size ($REPO_SIZE).\nLink: $REPO_URL " "GITLAB: $REPO_PATH_NAMESPACE was archived" "$ADMIN_EMAIL"
      # sendMail "Hello $REPO_OWNER_NAME,\n\nyour repository ($REPO_PATH_NAMESPACE) was archived because it has exceeded the maximum size." "$REPO_PATH_NAMESPACE was archived" "$REPO_OWNER_MAIL"
      continue
    fi


    if [ "$REPO_SIZE" -gt "$MAX_ARCHIVE" ] ; then
      # cleanup
      # deleteLostAttachments "$REPO_ID" "$line"
      ATTACHMENT_PATH=$(echo $line | cut -d" " -f2)
      ISSUES=$(curl -s --request GET --header "PRIVATE-TOKEN: $TOKEN" "$PROJECTS_API/$REPO_ID/issues" | jq '.[].description')
      MILESTONES=$(curl -s --request GET --header "PRIVATE-TOKEN: $TOKEN" "$PROJECTS_API/$REPO_ID/milestones" | jq '.[].description')

      INPUT=$(echo $ISSUES$MILESTONES| grep -oP "([0-9a-f]{32})")
      INPUT=$(echo $INPUT | sed -e "s/ / -not -name /g")
      while read line; do
        FIND=$(find $UPLOADS$ATTACHMENT_PATH ! -path $UPLOADS$ATTACHMENT_PATH -type d -not -name $line)
        writeLog "remove $FIND"
        find $UPLOADS$ATTACHMENT_PATH ! -path $UPLOADS$ATTACHMENT_PATH -type d -not -name $line 
        find $UPLOADS$ATTACHMENT_PATH ! -path $UPLOADS$ATTACHMENT_PATH -type d -not -name $line -exec rm -r {} \;
      done <<< $INPUT
    fi
  fi
done <<< "$CHECK"


