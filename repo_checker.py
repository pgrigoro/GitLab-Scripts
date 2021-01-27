#!/usr/bin/python3
# python script to overcome the problem of hashed repository pathes (GitLab 13.0, hashed storage is enabled by default, Support for legacy storage is scheduled to be removed in GitLab 14.0)

import gitlab
import os
import time
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

DRY_RUN                 = True # if True, only log entries are created

GITLAB_URL, SSL_VERIFY  = 'https://xyz.com', True
ADMIN_TOKEN             = '123456789012345667890'
LOG_FILE                = '/var/log/gitlab/scripts/checkSize.log'
ADMIN_EMAIL             = 'admin@xyz.com'
                        
ARCHIVE_MSG             = 'Hello {REPO_OWNER_NAME},\n\nyour repository ({REPO_PATH_NAMESPACE}) was archived because it has exceeded the maximum size.'
ARCHIVE_SUB             = '{REPO_PATH_NAMESPACE} was archived'
BLOCK_MSG               = 'Hello {MEMBER_USERNAME},\n\nyour gitlab account was blocked because you are a member of project that has exceeded the maximum size ({REPO_PATH_NAMESPACE}).' 
BLOCK_SUB               = 'Your gitlab account {MEMBER_USERNAME} was blocked'
                        
ARCHIVE_ADMIN_MSG       = 'Hello Admin,\n\n{REPO_PATH_NAMESPACE} was archived because it has exceeded the maximum size ({REPO_SIZE}).\nLink: {REPO_URL}'
ARCHIVE_ADMIN_SUBJECT   = 'GITLAB: {REPO_PATH_NAMESPACE} was archived'
BLOCK_ADMIN_MSG         = 'Hello Admin,\n\n{MEMBER_USERNAME} ({MEMBER_NAME}) (ID {MEMBER_ID}) was blocked because the project ({REPO_PATH_NAMESPACE}) exceeded the maximum size ({REPO_SIZE}).'
BLOCK_ADMIN_SUBJECT     = 'GITLAB: {MEMBER_USERNAME} was blocked'


IGNORE_USER_IDS          = [
  1  , # root
  ]
IGNORE_PROJECT_IDS       = [
  #1,
  ] 

ARCHIVE_LIMIT            = 200_000_000 # 200 MB 
IGNORE_ARCHIVE_LIMIT_IDS = [
  #1,
  ]

BLOCK_LIMIT              = 300_000_000 # 300MB
IGNORE_BLOCK_LIMIT_IDS   = [
  #1,
]

  
gl = gitlab.Gitlab(GITLAB_URL, private_token=ADMIN_TOKEN, ssl_verify=SSL_VERIFY)
gl.auth()

def send_mail(msg, subject, receiver):
  msg_oneline = msg.replace('\n','\\n') 
  log(f'send mail SUB:{subject} MSG:"{msg_oneline}" to "{receiver}"')
  if not DRY_RUN: os.system(f'echo -e "{msg} \n\n Do not reply to this email."  | mail -aFROM:gitlab@xyz.com -s "{subject}" "{receiver}"')


def log(msg):
  msg = msg.replace('\n','\\n')
  os.system(f'logger -s "{msg}" 2>> "{LOG_FILE}"')

def archive_repo(project):
  try:
    if not DRY_RUN: project.archive()
    for member in project.members.all(all=True): 
      send_mail(
        msg      = ARCHIVE_MSG.format(                       # 'Hello {REPO_OWNER_NAME},\n\nyour repository ({REPO_PATH_NAMESPACE}) was archived because it has exceeded the maximum size.'
          REPO_OWNER_NAME     = member.name                , 
          REPO_PATH_NAMESPACE = project.path_with_namespace,
          )                                                , 
        subject  = ARCHIVE_SUB.format(                       # '"{REPO_PATH_NAMESPACE} was archived"'
          REPO_PATH_NAMESPACE = project.path_with_namespace,
          )                                                ,  
        receiver = gl.users.get(member.id).email           , # user mail
        )
      
    send_mail(
      msg      = ARCHIVE_ADMIN_MSG.format(                     # '"Hello Admin,\n\n{REPO_PATH_NAMESPACE} was archived because it has exceeded the maximum size ({REPO_SIZE}).\nLink: {REPO_URL}"'
        REPO_PATH_NAMESPACE = project.path_with_namespace    ,  
        REPO_SIZE           = project.statistics['storage_size'], 
        REPO_URL            = project.http_url_to_repo       ,
        )                                                    ,  
      subject  = ARCHIVE_ADMIN_SUBJECT.format(                 # '"GITLAB: {REPO_PATH_NAMESPACE} was archived"'
        REPO_PATH_NAMESPACE = project.path_with_namespace    ,
        )                                                    ,  
      receiver = ADMIN_EMAIL                                 ,
      )
  except Exception as ex:
    log(f'could not archive project {project.id} ({ex})')

    
def block_users(project):
  log(f'block users for repository {project.path_with_namespace} ({project.id}) size {project.statistics["storage_size"]}')
  try:
    for member in project.members.all(all=True):
      if member.id in IGNORE_USER_IDS:
        log(f'{member.name} is in IGNORE_USER_IDS ({member.id})') 
        continue
      
    log(f'try block user {member.name} (member.id)')
    user = gl.users.get(member.id)
    if not DRY_RUN: user.block()
    log(f'user {member.name} ({member.id}) blocked')

    send_mail(
      msg      = BLOCK_MSG.format(                         # 'Hello {MEMBER_USERNAME},\n\nyour gitlab account was blocked because you are a member of project that has exceeded the maximum size ({REPO_PATH_NAMESPACE}).'
        MEMBER_USERNAME     = member.name                , 
        REPO_PATH_NAMESPACE = project.path_with_namespace,
        )                                                , 
      subject  = BLOCK_SUB.format(                         # 'Your gitlab account {MEMBER_USERNAME} was blocked'
        MEMBER_USERNAME     = member.name                ,
        )                                                ,  
      receiver = gl.users.get(member.id).email           , # user mail
      )
    
    send_mail(
      msg      = BLOCK_ADMIN_MSG.format(                          # 'Hello Admin,\n\n{MEMBER_USERNAME} ({MEMBER_NAME}) (ID {MEMBER_ID}) was blocked because the project ({REPO_PATH_NAMESPACE}) exceeded the maximum size ({REPO_SIZE}).'
        MEMBER_USERNAME     = member.username                       ,
        MEMBER_NAME         = member.name                       ,
        MEMBER_ID           = member.id                         ,
        REPO_PATH_NAMESPACE = project.path_with_namespace       ,  
        REPO_SIZE           = project.statistics['storage_size'], 
        )                                                       ,  
      subject  = BLOCK_ADMIN_SUBJECT.format(                      # 'GITLAB: {MEMBER_USERNAME} was blocked'
        MEMBER_USERNAME = member.name                           ,
        )                                                       ,  
      receiver = ADMIN_EMAIL                                    ,
      )
  except Exception as ex:
    log(f'could not block user ({repr(ex)})')
    raise ex


def ignore(project):
  if project.id in IGNORE_PROJECT_IDS:
    log(f'{project.id} is in IGNORE_PROJECT_IDS skip') 
    return True
  if project.archived == True:
    log(f'{project.id} is already archived skip') 
    return True 
  return False
  

def check_project(project):
  if ignore(project): return # skip project 

  if project.statistics['storage_size'] > ARCHIVE_LIMIT:
    if project.id not in IGNORE_ARCHIVE_LIMIT_IDS:
      archive_repo(project)
  
  if project.statistics['storage_size'] > BLOCK_LIMIT:
    if project.id not in IGNORE_BLOCK_LIMIT_IDS: 
      block_users(project)

if __name__ == '__main__':
  start = time.time()
  try:
    elements_processed = 0
    for page in range(1, 1000):
      projects = gl.projects.list(page=page, per_page=10, order_by='storage_size', statistics=True)
      for project in projects:
        check_project(project)
        elements_processed += 1
        if project.statistics['storage_size'] < ARCHIVE_LIMIT: raise StopIteration('No more checks needed')
  except StopIteration as stop: 
    log(f'{elements_processed} elements processed (used time: {time.time() - start:.2f}s)')
  
