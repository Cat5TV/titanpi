#!/bin/bash
basedir=$(pwd)

# Create titan user
if [[ ! -d /home/titan ]]; then
  useradd -m titan
fi

apt update

# Get the Titan source code
if [[ ! -d /var/www ]]; then
  mkdir /var/www
fi

if [[ ! -d /var/www/Titan/webapp ]]; then
  cd /var/www
  git clone https://github.com/TitanEmbeds/Titan
  # We will be adding configs, so let's just let this be a local version
  rm -rf /var/www/Titan/.git
fi

# Allow the titan user (systemd service runner) to read/write
chown -R titan:www-data /var/www

# Install dependencies
apt -y install build-essential checkinstall
apt -y install libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev
apt -y install python libffi-dev
apt -y install postgresql postgresql-client
apt -y install sudo
apt -y install tcl8.5
apt -y install libpq-dev # required for psycopg2/psycopg2-binary

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

# Install redis-server (it automatically gets enabled with systemd too)
apt -y install redis-server

# update the database headers (do this after every git pull)
cd /var/www/Titan/webapp
alembic upgrade head

# Install web server
pip3.7 install gunicorn
pip3.7 install eventlet
pip3.7 install config

# Create config.py
./config.sh

# Install make-ssl-cert if it isn't already installed
if [[ ! -e /usr/sbin/make-ssl-cert ]]; then
  apt -y install ssl-cert
fi

# Generating new Snakeoil cert
/usr/sbin/make-ssl-cert generate-default-snakeoil --force-overwrite

# Combine for Webmin and other interfaces
cat /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/ssl/private/ssl-cert-snakeoil.key > /etc/ssl/certs/ssl-cert-snakeoil-combined.pem
# Cert is owned by root:root
chmod 600 /etc/ssl/certs/ssl-cert-snakeoil-combined.pem
# Generate unique SSH certs
/bin/rm /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server
systemctl restart ssh

# Create systemd service
# https://github.com/TitanEmbeds/ansible-playbooks/blob/master/roles/setup/files/titanembeds.service#L8
echo "[Unit]
Description=TitanPi gunicorn server
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
systemctl --no-pager status titanembeds

# Install nginx
apt -y install nginx

# Create nginx conf
echo 'server {
  listen 80;
  listen [::]:80;

  root /var/www/dashboard/;
  index index.php index.html index.htm;

  location ~ \.php$ {
      try_files $uri =404;
      fastcgi_split_path_info ^(.+\.php)(/.+)$;
      fastcgi_pass unix:/var/run/php/php7.3-fpm.sock;
      fastcgi_index index.php;
      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          include fastcgi_params;
      }
}
upstream titan {
    server unix:/var/www/titanembeds.sock fail_timeout=0;
}
upstream titanws {
    server unix:/var/www/titanembeds.sock fail_timeout=0;
}
server {
    listen 8080 default_server;
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
    listen 443 ssl;
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
    if ($scheme != "https") {
        return 301 https://$host$request_uri;
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

# Install TitanPi dashboard on Port 80
cd $basedir
cp -R dashboard /var/www/
chown -R www-data:www-data /var/www/dashboard

# Install PHP
apt -y install php-fpm

# Start everything up
systemctl restart nginx


# Install and enable the bot
echo "[Unit]
Description=TitanPi Discord Bot
After=network.target

[Service]
User=titan
WorkingDirectory=/var/www/Titan/discordbot/
ExecStart=/usr/local/bin/python3.7 /var/www/Titan/discordbot/run.py
Restart=always
KillSignal=SIGQUIT
StandardError=syslog

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/titanbot.service

# Reload service config
systemctl daemon-reload

# Enable bot
systemctl start titanbot
systemctl enable titanbot

# Install and configure monit
apt -y install monit
echo "

" > /etc/monit/conf.d/titanpi.conf
