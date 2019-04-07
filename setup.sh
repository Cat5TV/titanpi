#!/bin/bash
if [[ ! -d Titan ]]; then
  echo "Titan is missing. Did you clone this repo with --recursive ?"
  exit 1
fi
basedir=$(pwd)

apt -y install build-essential checkinstall
apt -y install libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev
apt -y install python libffi-dev
apt -y install postgresql postgresql-client


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

