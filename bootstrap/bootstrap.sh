#!/bin/bash

max_jobs=6
max_load=3.5

if [ "$(id -u)" -ne 0 ]
then
	echo "$(basename "$0"): superuser access is required" >&2
	exit 6
fi

script_location="$(dirname "$(realpath $0)")"
echo "Script directory is $script_location, will find files relative to that, not current working directory" >&2
sleep 5


function my_emerge()
{
	emerge --load-average=$max_load --jobs=$max_jobs "$@"
	return $?
}


function possibly_set_password_for_nick
{
	if passwd --status nick | egrep 'L|NP'
	then
		echo "Set password for nick:" >&2
		passwd nick
	fi
}

# Before initialising etckeeper - resolved makes etckeeper commit hang
if [ -e /etc/resolv.conf ] && ! [ -L /etc/resolv.conf ]
then
	# systemd-resolved hangs when resolving domain names from,
	# say, wget, even though dig, host and nslookup use resolv.conf
	# directly.  This causes problems emerging things.
	# Therefore, until I know how to fix this the systemd way I'm
	# going old-school
	systemctl disable systemd-resolved.service
	systemctl stop systemd-resolved.service
fi

my_emerge --verbose --noreplace \
	app-crypt/gnupg \
	dev-vcs/git \
	net-misc/openssh



if ! id nick
then
	useradd -m --user-group --groups wheel nick
fi
possibly_set_password_for_nick

su -c "cd /home/nick && git clone --recursive https://github.com/nmbooker/gentoo-install-ogg" nick
