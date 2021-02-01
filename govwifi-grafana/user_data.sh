#!/usr/bin/env bash
set -ueo pipefail

export DEBIAN_FRONTEND=noninteractive

function run-until-success() {
  until $*
  do
    echo "Executing $* failed. Sleeping..."
    sleep 5
  done
}


# Apt - Make sure everything is up to date
run-until-success apt-get update  --yes
run-until-success apt-get upgrade --yes


# We want to make sure that the journal does not write to syslog
# This would fill up the disk, with logs we already have in the journal
echo "Ensure journal does not write to syslog"
mkdir -p /etc/systemd/journald.conf.d/
cat <<JOURNAL > /etc/systemd/journald.conf.d/override.conf
[Journal]
SystemMaxUse=2G
RuntimeMaxUse=2G
ForwardToSyslog=no
ForwardToWall=no
JOURNAL

systemctl daemon-reload
systemctl restart systemd-journald


# Use Amazon NTP
# An implementation of Network Time Protocol (NTP). It can synchronise the system clock with NTP servers
echo 'Installing and configuring chrony'
run-until-success apt-get install --yes chrony
sed '/pool/d' /etc/chrony/chrony.conf \
| cat <(echo "server 169.254.169.123 prefer iburst") - > /tmp/chrony.conf
echo "allow 127/8" >> /tmp/chrony.conf
mv /tmp/chrony.conf /etc/chrony/chrony.conf
systemctl restart chrony


# Install Docker and Send Logs to CloudWatch
echo 'Installing and configuring docker'
mkdir -p /etc/systemd/system/docker.service.d
run-until-success apt-get install --yes docker.io
cat <<EOF > /etc/systemd/system/docker.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --log-driver awslogs --log-opt awslogs-region=eu-west-2 --log-opt awslogs-group=${grafana-log-group} --dns 10.0.0.2
EOF


echo 'Installing awscli'
run-until-success apt-get install --yes awscli


reboot
