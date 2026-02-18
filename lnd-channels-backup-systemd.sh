#!/bin/bash

sudo su -

    echo "Adding backup-channels.service to systemd"
    echo "
[Service]
ExecStart=/root/btcpayserver/lnd-channels-remote-backup-on-change.sh
Restart=always
RestartSec=1
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=backup-channels
User=root
Group=root

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/backup-channels.service

systemctl daemon-reload
systemctl start backup-channels
systemctl enable backup-channels
    echo "OK"