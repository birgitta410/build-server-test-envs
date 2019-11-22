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

# https://docs.gitlab.com/ee/raketasks/backup_restore.html#reset-runner-registration-tokens
echo "Resetting runner tokens..."

resetScriptPath=/etc/gitlab/backups/reset_after_backup.sql
echo "UPDATE projects SET runners_token = null, runners_token_encrypted = null;" >> ${resetScriptPath}
echo "UPDATE namespaces SET runners_token = null, runners_token_encrypted = null;" >> ${resetScriptPath}
echo "UPDATE application_settings SET runners_registration_token_encrypted = null;" >> ${resetScriptPath}
echo "UPDATE ci_runners SET token = null, token_encrypted = null;" >> ${resetScriptPath}
echo "\q" >> ${resetScriptPath}
echo "" >> ${resetScriptPath}

echo "\i /etc/gitlab/backups/reset_after_backup.sql" | gitlab-rails dbconsole
