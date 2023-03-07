#!/bin/bash

sudo systemctl stop ntp.socket
sudo systemctl stop ntp.service
sudo apt update
sudo apt install -y git libncurses-dev rhash
