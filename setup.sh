#!/bin/bash
if [[ ! -d Titan/webapp ]]; then
  echo "Titan is missing. Did you clone this repo with --recursive ?"
  exit 1
fi
basedir=$(pwd)

if (( 3 == 1 )); then

apt -y install build-essential checkinstall
apt -y install libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev
apt -y install python libffi-dev
apt -y install postgresql postgresql-client
apt -y install sudo

cd /tmp
mkdir python
cd pyton
wget https://www.python.org/ftp/python/3.7.3/Python-3.7.3.tgz
tar xzf Python-3.7.3.tgz
cd Python-3.7.3
./configure --enable-optimizations
make altinstall

cd $basedir
cd Titan
pip3.7 install -r requirements.txt

fi

# Create database
pip3.7 install postgres
echo "create database titan;
create user titan with encrypted password 'titan';
grant all privileges on database titan to titan;" | sudo -u postgres psql

# Install and setup Alembic
cd $basedir
pip3.7 install alembic

# Create config for Alembic
cd $basedir
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
" > Titan/webapp/alembic.ini

# update the database headers (do this after every git pull)
alembic upgrade head

# Install redis-server (it automatically gets enabled with systemd too)
apt -y install redis
