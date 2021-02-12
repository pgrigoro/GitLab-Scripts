mkdir gitlab.bak
mkdir gitlab.bak/gitlab.etc
sudo gitlab-rake gitlab:backup:create
sudo cp -r /var/opt/gitlab/backups/ ./gitlab.bak
sudo cp -r /etc/gitlab/* ./gitlab.bak/gitlab.etc
