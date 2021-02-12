#!/bin/bash
# Update crontab to include a daily 2 AM backup of gitlab secrets and configuration
echo "0 2 * * * /opt/gitlab/bin/gitlab-rake gitlab:backup:create CRON=1" >> /etc/crontab
echo "0 2 * * * /bin/cp /etc/gitlab/gitlab.rb \"/mnt/gitlab-bucket/backup/$(/bin/date '+\%s_\%Y_\%m_\%d')_gitlab.rb\"" >> /etc/crontab
echo "0 2 * * * /bin/cp /etc/gitlab/gitlab-secrets.json \"/mnt/gitlab-bucket/backup/$(/bin/date '+\%s_\%Y_\%m_\%d')_gitlab-secrets.json\"" >> /etc/crontab
