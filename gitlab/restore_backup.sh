#!/usr/bin/env bash
set -e

# https://docs.gitlab.com/ee/raketasks/backup_restore.html
echo "Restoring 'baseline' backup..."
cp /etc/gitlab/backups/gitlab_backup.tar /var/opt/gitlab/backups/baseline_gitlab_backup.tar
chown git.git /var/opt/gitlab/backups/baseline_gitlab_backup.tar
gitlab-ctl stop unicorn
gitlab-ctl stop sidekiq
! gitlab-ctl status

yes yes | gitlab-backup restore BACKUP=baseline

echo "Restarting..."

gitlab-ctl reconfigure
gitlab-ctl restart
gitlab-rake gitlab:check SANITIZE=true