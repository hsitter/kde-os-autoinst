#!/bin/sh

apt update
apt install -y ruby sudo ruby-dev

exec ./bootstrap.rb
