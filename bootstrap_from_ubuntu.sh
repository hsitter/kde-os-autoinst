#!/bin/sh

apt update
apt install -y ruby sudo ruby-dev wget gnupg2

exec ./bootstrap.rb
