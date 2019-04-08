#!/bin/bash
cd /var/www/Titan/webapp
/usr/local/bin/gunicorn --worker-class eventlet -w 1 -b unix:/var/www/titanembeds.sock titanembeds.app:app

