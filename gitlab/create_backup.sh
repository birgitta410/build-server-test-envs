#!/usr/bin/env bash
set -e

# https://docs.gitlab.com/ee/raketasks/backup_restore.html
echo "Creating a new backup..."
rm /var/opt/gitlab/backups/*_gitlab_backup.tar
gitlab-backup create
backupFilename=`ls /var/opt/gitlab/backups/*_gitlab_backup.tar`
cp $backupFilename /etc/gitlab/backups/new_gitlab_backup.tar
