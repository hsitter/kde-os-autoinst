#!/bin/sh

apt update
apt install -y ruby sudo

exec ./axiom.rb
