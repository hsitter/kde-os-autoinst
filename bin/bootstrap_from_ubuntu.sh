#!/bin/sh

export DEBIAN_FRONTEND=noninteractive

apt update
apt install -y ruby sudo ruby-dev wget gnupg2

exec bin/bootstrap.rb
