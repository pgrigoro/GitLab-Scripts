#!/bin/bash

TOKEN="GITLAB_API_TOKEN"
GITLAB_API="https://URL_TO_YOUR_GITLAB_INSTANCE/api/v4"
PROJECTS_API="$GITLAB_API/projects"
USER_API="$GITLAB_API/users"
REPOS_PATH="/var/opt/gitlab/git-data/repositories/"
LOG_FILE="/var/log/gitlab/scripts/checkSize.log"
ADMIN_EMAIL="admin@xyz.com"
GITLAB_EMAIL="gitlab@xyz.com"

MAX_ARCHIVE="100000"   # size to archive repo (100MB)
MAX_BLOCK="200000"     # size to lock user (200MB)

######################################################################################

writeLog(){
  logger -s "$1" 2>> "$LOG_FILE"
}

sendMail(){ # message subject receiver
  echo -e "$1 \n\n Do not reply to this email."  | mail -aFROM:$GITLAB_EMAIL -s "$2" "$3"
}

######################################################################################

echo "last run checkRepoSize.sh $(date)" > /var/log/gitlab/scripts/lastRun.log

for D in `find ${REPOS_PATH} -type d -name *.git`; do
  if [[ "$(du -s $D)" =~ ^([0-9]+)$'\t'"$REPOS_PATH"(.*)\.wiki\.git$ ]] ; then
    REPO_SIZE=${BASH_REMATCH[1]}
    REPO_PATH=`echo ${BASH_REMATCH[2]} | sed -e 's/\//%2F/g'`
  elif [[ "$(du -s $D)" =~ ^([0-9]+)$'\t'"$REPOS_PATH"(.*)\.git$ ]] ; then 
    REPO_SIZE=${BASH_REMATCH[1]} 
    REPO_PATH=`echo ${BASH_REMATCH[2]} | sed -e 's/\//%2F/g'`
  else  
    writeLog "could not get repo size "
    exit 1
  fi  

  if [ "$REPO_SIZE" -gt "$MAX_ARCHIVE" ] ; then
    REPO_STATUS=`curl -s --request GET --header "PRIVATE-TOKEN: $TOKEN" "$PROJECTS_API/$REPO_PATH"`
    REPO_ID=`echo $REPO_STATUS| jq '.id'`
    REPO_PATH_NAMESPACE=`echo $REPO_STATUS | jq '.path_with_namespace' | sed -e 's/"//g'`
    REPO_NAME=`echo $REPO_STATUS | jq '.name' | sed -e 's/"//g'`
    REPO_OWNER_ID=`echo $REPO_STATUS | jq '.owner.id'`
    REPO_ARCHIVED=`echo $REPO_STATUS | jq '.archived'`
    REPO_URL=`echo $REPO_STATUS | jq '.web_url' | sed -e 's/"//g'`
     
    if [[ $REPO_OWNER_ID -eq 2 ]] ; then
      # skip admin projects
      writeLog "skip $REPO_ID from $REPO_OWNER_ID"
    elif [ "$REPO_ARCHIVED" = false ] ; then
      # archive repo
      REPO_ARCHIVED=`curl -s --request POST --header "PRIVATE-TOKEN: $TOKEN" "$PROJECTS_API/$REPO_PATH/archive" | jq '.archived'`
      if [ "$REPO_ARCHIVED" = true ] ; then
        writeLog "\"$REPO_PATH_NAMESPACE\" was archived (size: $REPO_SIZE)"
        REPO_OWNER=`curl -s --request GET --header "PRIVATE-TOKEN: $TOKEN" "$USER_API/$REPO_OWNER_ID"` 
	    REPO_OWNER_NAME=`echo $REPO_OWNER | jq '.name' | sed -e 's/"//g'`
	    REPO_OWNER_MAIL=`echo $REPO_OWNER | jq '.email' | sed -e 's/"//g'`

        sendMail "Hello $REPO_OWNER_NAME,\n\nyour repository ($REPO_PATH_NAMESPACE) was archived because it has exceeded the maximum size." "$REPO_PATH_NAMESPACE was archived" "$REPO_OWNER_MAIL"
        sendMail "Hello Admin,\n\n$REPO_PATH_NAMESPACE was archived because it has exceeded the maximum size ($REPO_SIZE).\nLink: $REPO_URL " "GITLAB: $REPO_PATH_NAMESPACE was archived" "$ADMIN_EMAIL"
      fi
    fi
  fi
  if [ "$REPO_SIZE" -gt "$MAX_BLOCK" ] ; then
    MEMBERS=`curl -s --request GET --header "PRIVATE-TOKEN: $TOKEN" "$PROJECTS_API/$REPO_ID/members"`
    MEMBER_IDS=`echo $MEMBERS | jq '.[] .id'`
    for MEMBER_ID in $MEMBER_IDS ; do
      if [ $MEMBER_ID -eq 2 ] ; then
        continue # ADMIN
      fi
      MEMBER=`curl -s --request GET --header "PRIVATE-TOKEN: $TOKEN" "$USER_API/$MEMBER_ID"`
      MEMBER_NAME=`echo $MEMBER | jq '.name' | sed -e 's/"//g'`  
      MEMBER_USERNAME=`echo $MEMBER | jq '.username' | sed -e 's/"//g'`  
      MEMBER_USEREMAIL=`echo $MEMBER | jq '.email' | sed -e 's/"//g'`  
      MEMBER_STATUS=`echo $MEMBER | jq '.state' | sed -e 's/"//g'`
      if [ "$MEMBER_STATUS" = active ] ; then
        RESULT=`curl -s --request POST --header "PRIVATE-TOKEN: $TOKEN" "$USER_API/$MEMBER_ID/block"`
        if [ "$RESULT" = true ] ; then 
          writeLog "block ID:$MEMBER_ID NAME: $MEMBER_NAME USERNAME: $MEMBER_USERNAME"

          sendMail "Hello $MEMBER_USERNAME,\n\nyour gitlab account was blocked because you are a member of project that has exceeded the maximum size." "Your gitlab account $iMEMBER_USERNAME was blocked" "$REPO_OWNER_MAIL"
          sendMail "Hello Admin,\n\n$MEMBER_USERNAME ($MEMBER_NAME) (ID $MEMBER_ID) was blocked because the project ($REPO_PATH_NAMESPACE) exceeded the maximum size ($REPO_SIZE)." "GITLAB: $MEMBER_USERNAME was blocked" "$ADMIN_EMAIL"
        fi 
      fi 
    done
  fi
done
