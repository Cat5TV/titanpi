#!/bin/bash
basedir=$(pwd)

# Create titan user
useradd -m titan

# Get the Titan source code
if [[ ! -d /var/www ]]; then
  mkdir /var/www
fi

# Allow the titan user (systemd service runner) to read/write
chown titan:titan /var/www

if [[ ! -d /var/www/Titan/webapp ]]; then
  cd /var/www
  git clone https://github.com/TitanEmbeds/Titan
fi

# Install dependencies
apt -y install build-essential checkinstall
apt -y install libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev
apt -y install python libffi-dev
apt -y install postgresql postgresql-client
apt -y install sudo

# Install Python 3.7
cd /tmp
mkdir python
cd python
wget https://www.python.org/ftp/python/3.7.3/Python-3.7.3.tgz
tar xzf Python-3.7.3.tgz
cd Python-3.7.3
./configure --enable-optimizations
make altinstall

# Install requirements
cd /var/www/Titan
pip3.7 install -r requirements.txt

# Create database
pip3.7 install psycopg2-binary
echo "create database titan;
create user titan with encrypted password 'titan';
grant all privileges on database titan to titan;" | sudo -u postgres psql

# Install and setup Alembic
pip3.7 install alembic

# Create config for Alembic
echo "[alembic]
script_location = alembic
sqlalchemy.url = postgresql://titan:titan@localhost/titan
[loggers]
keys = root,sqlalchemy,alembic
[handlers]
keys = console
[formatters]
keys = generic
[logger_root]
level = WARN
handlers = console
qualname =
[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine
[logger_alembic]
level = INFO
handlers =
qualname = alembic
[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic
[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
" > /var/www/Titan/webapp/alembic.ini


# update the database headers (do this after every git pull)
alembic upgrade head

# Install redis-server (it automatically gets enabled with systemd too)
apt -y install redis

# Install web server
pip3.7 install gunicorn
pip3.7 install eventlet
pip3.7 install config

# Create config.py
./config.sh

# Create systemd service
# https://github.com/TitanEmbeds/ansible-playbooks/blob/master/roles/setup/files/titanembeds.service#L8
echo "
[Unit]
Description=gunicorn server instance configured to serve titanembeds
After=syslog.target

[Service]
User=titan
WorkingDirectory=/var/www/Titan/webapp
ExecStart=/usr/local/bin/gunicorn --worker-class eventlet -w 1 -b unix:/var/www/titanembeds.sock titanembeds.app:app
TimeoutSec=infinity
Restart=on-failure
KillSignal=SIGTERM
StandardError=syslog
NotifyAccess=all

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/titanembeds.service

# Reload service config
systemctl daemon-reload

# Start Titan Embeds service
systemctl start titanembeds
systemctl enable titanembeds
systemctl status titanembeds

# install nginx
apt -y install nginx

# Create nginx conf
echo 'upstream titan {
    server unix:/var/www/titanembeds.sock fail_timeout=0;
}
upstream titanws {
    server unix:/var/www/titanembeds.sock fail_timeout=0;
}
server {
    listen 80 default_server;
    server_name titanpi;

  location / {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;
        proxy_buffering off;
        proxy_pass http://titan;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Real-IP $remote_addr;
    }
    location /gateway/ {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;
        proxy_buffering off;
        proxy_pass http://titanws;
        proxy_set_header X-Forwarded-Proto https;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP $remote_addr;
    }
    location ^~ /static/ {
        include /etc/nginx/mime.types;
        root /var/www/Titan/webapp/titanembeds/;
        etag on;
        if_modified_since before;
    }
    location ^~ /.well-known/ {
        include /etc/nginx/mime.types;
        root /var/www/wellknown/;
    }
}' > /etc/nginx/conf.d/titanembeds.conf

# Disable the default welcome site
rm /etc/nginx/sites-enabled/default

systemctl restart nginx
