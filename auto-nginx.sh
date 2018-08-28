#!/bin/bash
######################################################################
# centminmod.com auto update Nginx script with automated nginx binary
# backup and auto restore nginx binary to previous version on failed
# auto nginx updates
######################################################################
DT=$(date +"%d%m%y-%H%M%S")
MASTER='y'
MASTER_OVERRIDE='n'
CENTMINLOGDIR='/root/centminlogs'
LASTEST_NGINXVERS=$(curl -4sL https://nginx.org/en/download.html 2>&1 | egrep -o "nginx\-[0-9.]+\.tar[.a-z]*" | grep -v '.asc' | awk -F "nginx-" '/.tar.gz$/ {print $2}' | sed -e 's|.tar.gz||g' | head -n1 2>&1)
CURRENT_NGINXVERS=$(nginx -v 2>&1 | awk '{print $3}' | awk -F '/' '{print $2}')

if [[ "$MASTER" = [yY] ]]; then
  ngxver='master'
else
  ngxver=$LASTEST_NGINXVERS
fi

if [[ "$CURRENT_NGINXVERS" != "$LASTEST_NGINXVERS" ]] || [[ "$MASTER_OVERRIDE" = [yY] ]]; then
  if [ -f /usr/local/src/centminmod/centmin.sh ]; then
    if [ -f tools/nginx-binary-backup.sh ]; then
      tools/nginx-binary-backup.sh backup | tee "$CENTMINLOGDIR/auto-nginx-$DT.log"
      pre_backupdir=$(cat "$CENTMINLOGDIR/auto-nginx-$DT.log" |awk '/backup created at/ {print $4}')
      tools/nginx-binary-backup.sh list
    fi
    yum -y update --disableplugin=priorities --enablerepo=remi
    cmupdate
    cd /usr/local/src/centminmod/
expect << EOF
set timeout -1
spawn ./centmin.sh
expect "Enter option"
send -- "4\r"
expect "Do you want to run YUM install checks ?"
send -- "n\r"
expect "Nginx Upgrade - Would you like to continue?"
send -- "y\r"
expect "Install which version of Nginx"
send -- "$ngxver\r"
expect "Enter option"
send -- "24\r"
expect eof
EOF
   nginx -t
   errorcheck=$?
   if [ -f tools/nginx-binary-backup.sh ]; then
      if [ "$errorcheck" -eq '0' ]; then
        tools/nginx-binary-backup.sh backup
        tools/nginx-binary-backup.sh list
      else
        tools/nginx-binary-backup.sh restore $pre_backupdir
      fi
    fi
    nginx -V
  fi
else
  echo "No update available. Running latesting Nginx Version: $CURRENT_NGINXVERS"
fi