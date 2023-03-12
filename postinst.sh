#!/bin/bash

max_jobs=6
max_load=3.5
	# number of real cores, plus 1 to maybe possibly take advantage of hypertghreading and IO bound work

USE="X gpm png pulseaudio unicode xinerama -llvm"
VIDEO_CARDS="nouveau intel vesa"

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

function commit_etc()
{
	if which etckeeper && [ -d /etc/.git ]
	then
		etckeeper commit "$1 [postinst.sh]"
	else
		echo "Warning from $0::commit_etc: etckeeper not yet installed, skipping commit" >&2
	fi
}

function installed_etckeeper_version()
{
	emerge --info sys-apps/etckeeper \
	| grep 'was built with the following' \
	| perl -n -E 'say s/sys-apps\/etckeeper-([0-9.]+)::gentoo.*$/\1/r;'
}

function initialise_etckeeper()
{
	if which etckeeper && ! [ -d /etc/.git ]
	then
		etckeeper init -d /etc
		commit_etc "Initial commit"
		local etckeeper_ver="$(installed_etckeeper_version)"
		cat "/usr/share/doc/etckeeper-$etckeeper_ver/profile.example" >> /etc/portage/bashrc
		commit_etc "Integrate etckeeper with portage"
		env-update
		commit_etc "Run env-update"
	fi
}

function initialise_vimrc()
{
	if ! [  -e "$1" ]
	then
		# as suggested by gentoosyntax
		cat > "$1" <<-END
			filetype plugin on
			filetype indent on
			nohlsearch
			colorscheme torte
			END
	fi
}

function install_basics()
{
	commit_etc "Commit before installing basic utilities"
	# Install the basic things I need to be able to debug the system
	# and develop this script
	my_emerge --noreplace \
		sys-libs/gpm \
		app-shells/bash-completion \
		app-misc/tmux \
		net-misc/openssh \
		app-editors/vim \
		sys-process/lsof \
		sys-fs/ntfs3g \
		dev-util/dialog \
		www-client/links
		# ntfs3g - for IODD0 disk this script often resides on
		# dialog - for gentoo-install's 'configure' script
	eselect vi set vim
	eselect visual set vi
	eselect editor set vi
	commit_etc "Select vim as the default editor with eselect"
	. /etc/profile
	initialise_vimrc /root/.vimrc
	initialise_vimrc /etc/skel/.vimrc
	commit_etc "Install a default .vimrc according to gentoosyntax recommentations"
}

function possibly_set_password_for_nick
{
	if passwd --status nick | egrep 'L|NP'
	then
		echo "Set password for nick:" >&2
		passwd nick
		commit_etc "Set password for nick"
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

if which etckeeper
then
	initialise_etckeeper
fi

if ! id nick
then
	useradd -m --user-group --groups wheel nick
	commit_etc "Add user nick"
fi
possibly_set_password_for_nick

initialise_vimrc /home/nick/.vimrc
chown nick:nick /home/nick/.vimrc

commit_etc "Committing changes made before running script"


emerge --jobs --load-average=$max_load --noreplace sys-apps/etckeeper || exit 4

initialise_etckeeper

if "${STOP_FOR_REMOTE:-false}"
then
	# Get things working just enough for nick to tolerate
	# working remotely on this system
	install_basics
	possibly_set_password_for_nick
	systemctl enable --now sshd.service
	commit_etc "Enable sshd because STOP_FOR_REMOTE=true"
	exit 0
fi


function select_desktop_profile()
{
	eselect profile set default/linux/amd64/17.1/desktop/systemd
	# TODO compute desktop edition of whatever version is currently selected
	commit_etc "Select desktop/systemd profile"
}
select_desktop_profile


if ! grep '^USE=' /etc/portage/make.conf
then
	echo 'USE="'$USE'"' >> /etc/portage/make.conf
	commit_etc "Set USE flags for ogg"
fi

if ! grep '^VIDEO_CARDS' /etc/portage/make.conf
then
	echo 'VIDEO_CARDS="'$VIDEO_CARDS'"' >> /etc/portage/make.conf
	commit_etc "Set up VIDEO_CARDS for ogg"
fi

if ! grep '^L10N=' /etc/portage/make.conf
then
	echo 'L10N="en-GB"' >> /etc/portage/make.conf
	commit_etc "Set up LION (used by at least firefox-bin)"
fi


echo 'media-libs/libsndfile minimal' > /etc/portage/package.use/firefox-bin-temp
commit_etc "Temporarily USE minimal for libsndfile to allow for dependency cycle"

emerge --sync
echo "Ensuring we install rust-bin instead of compiling rust..." >&2
my_emerge --verbose --noreplace dev-lang/rust-bin
	# ^ By default things that need rust will compile from scratch.
	# ^ Preinstalling rust-bin prevents this time sink
echo "Rebuilding @world with new use flags" >&2
my_emerge --verbose --newuse --deep @world || exit 5
echo "env-update..." >&2
env-update

install_basics

echo "=x11-wm/fvwm3-1.0.4-r2 ~amd64" > /etc/portage/package.accept_keywords/fvwm3
echo "=x11-wm/fvwm3-1.0.6a::local ~amd64" >> /etc/portage/package.accept_keywords/fvwm3
commit_etc "Allow fvwm3 to be installed"
my_emerge --verbose --newuse \
	app-eselect/eselect-repository \
	dev-util/pkgcheck \
	dev-util/pkgdev \
	net-misc/rsync
commit_etc "Emerged eselect-repository, pkgcheck, pkgdev and rsync"

eselect repository enable guru
commit_etc "Add guru repository"
emerge --sync guru
commit_etc "Synced guru repository"

if ! [ -d /var/db/repos/local ]
then
	eselect repository create local
	rsync -r "$script_location/repos/local/" /var/db/repos/local/
fi

# When creating and modifying ebuilds:
# cd /var/db/repos/local
# pkgcheck scan
# pkgdev manifest
# rsync -r ./ /home/nick/gentoo-install-ogg/repos/local/

function set_up_sudo()
{
	commit_etc "Commit before setting up sudo"
	my_emerge --verbose --newuse app-admin/sudo
	commit_etc "Emerged app-admin/sudo"
	mkdir -p /etc/sudoers.d
	# according to sudoers manpage don't put a dot in the filename
	# except to disable
	cat > /etc/sudoers.d/50-wheel-group <<-END
		%wheel ALL=(ALL:ALL) ALL
		END
	commit_etc "Configure wheel group's sudo access"
}
set_up_sudo

function set_up_sound_userland()
{
	# TUI and services only, GUI stuff comes later
	commit_etc "Before setting up userland sound tools"
	my_emerge --verbose --newuse media-sound/alsa-utils
	commit_etc "Emerged media-sound/alsa-utils"
	systemctl enable --now alsa-restore.service
	commit_etc "Enable alsa-restore.service"
	systemctl --global enable pulseaudio.service pulseaudio.socket
	commit_etc "Enabled pulseaudio systemd units"
}
set_up_sound_userland

my_emerge --verbose --newuse \
	app-arch/unzip \
	app-arch/zip
commit_etc "Emerged zip and unzip"

# The basics of X, a terminal, filer, a GUI editor and a simple WM
my_emerge --verbose --newuse \
	x11-apps/setxkbmap \
	x11-apps/xinit \
	x11-base/xorg-server \
	x11-apps/xset \
	x11-terms/xterm \
	app-misc/rox-filer \
	app-editors/gvim \
	x11-wm/twm
	# twm: For testing and in case all else breaks
# See screenshot for USE flags we might want to enable (xinerama, X, truetype)
# Shall I enable +toolbar on x11-terms/xterm?
#	What about Xaw3d?
commit_etc "emerged the bare minimum for a GUI environment"
mkdir -p /etc/X11/xorg.conf.d
install \
	--owner root \
	--group root \
	--mode 644 \
	"$script_location/30-keyboard.conf" \
	/etc/X11/xorg.conf.d/30-keyboard.conf
commit_etc "Configure the keyboard in X"

# FVWM
# TODO unmask and install fvwm3 instead of fvwm (2)
echo "x11-wm/fvwm3 doc go lock netpbm vanilla" > /etc/portage/package.use/fvwm3
commit_etc "Set USE flags for fvwm3"
# if ! [ -e /etc/portage/package.use/fvwm ]
# then
# 	echo 'x11-wm/fvwm truetype xinerama lock netpbm' \
# 	> /etc/portage/package.use/fvwm
# 	# TODO
# 	# echo 'x11-wm/fvwm png svg tk truetype xinerama' \
# 	# > /etc/portage/package.use/fvwm
# 	commit_etc "Set additional use flags for fvwm"
# fi
my_emerge --newuse --verbose \
	x11-wm/fvwm3 \
	app-misc/rox-filer

function install_firefox()
{
	my_emerge --noreplace --verbose www-client/firefox-bin
}
install_firefox

function install_nscde_deps()
{
	mkdir -p /etc/portage/sets
	cat > /etc/portage/sets/nscde-deps <<-END
		app-shells/ksh 
		x11-base/xorg-server
		x11-misc/dunst 
		x11-apps/xdpyinfo 
		x11-apps/xprop 
		x11-misc/xdotool 
		media-gfx/imagemagick 
		x11-misc/xscreensaver 
		dev-python/pyyaml 
		dev-python/PyQt5 
		x11-misc/qt5ct 
		dev-qt/qtstyleplugins 
		x11-misc/stalonetray 
		x11-terms/xterm 
		dev-lang/python 
		dev-python/pyxdg 
		dev-libs/libstroke 
		x11-misc/xsettingsd 
		x11-wm/fvwm3
		dev-perl/File-MimeInfo 
		app-admin/gkrellm 
		x11-misc/xclip 
		x11-misc/rofi
		END
	mkdir -p /etc/portage/package.accept_keywords
	# this is what autounmask gave us, but following this
	# wiki page's manual method instead:
	# https://wiki.gentoo.org/wiki/Knowledge_Base:Unmasking_a_package
	echo "=dev-qt/qtstyleplugins-5.0.0_p20170311-r1 ~amd64" \
		> /etc/portage/package.accept_keywords/qtstyleplugins
	commit_etc "Unmask qtstyleplugins for @nscde-deps"
	mkdir -p /etc/portage/package.use
	cat > /etc/portage/package.use/qtmultimedia-use-widgets <<-END
		# required by dev-python/PyQt5-5.15.7::gentoo[multimedia]
		# required by @nscde-deps (argument)
		>=dev-qt/qtmultimedia-5.15.8 widgets
		END
	commit_etc "Set use flags for qtmultimedia on behalf of @nscde-deps"
	my_emerge --verbose --noreplace @nscde-deps
	commit_etc "Installed the @nscde-deps"
}
install_nscde_deps
(cd "$script_location" && ./install-nscde.sh)
commit_etc "Ran install-nscde.sh"
mkdir -p /etc/xdg/menus
if ! [ -e /etc/xdg/menus/.gitkeep ]
then
	touch /etc/xdg/menus/.gitkeep
	commit_etc "Add /etc/xdg/menus so fvwm-menu-desktop doesn't get upset"
fi

# If release version of nscde turns out to be crashy even with fvwm3-1.0.6a,
# then install the master snapshot I took on 2023-03-05
# (cd "$script_location" && ./install-nscde-master.sh)
# commit_etc "Ran install-nscde-master.sh"


function set_up_printing()
{
	cat > /etc/portage/package.use/avahi <<-END
		# required by net-print/hplip-3.22.10::gentoo[snmp,-minimal]
		# required by net-print/hplip (argument)
		>=net-dns/avahi-0.8-r7 python
		END
	commit_etc "Set USE flags for net-dns/avahi on behalf of net-print/hplip"
	echo "net-print/cups zeroconf" > /etc/portage/package.use/cups
	commit_etc "Set USE flags for net-print/cups to allow network autodiscovery"
	cat > /etc/portage/package.use/hplip <<-END
		net-print/hplip scanner
		END
	commit_etc "Set USE flags for net-print/hplip"
	my_emerge --verbose --newuse net-print/hplip net-print/cups
	commit_etc "Emerged hplip and cups"
	systemctl enable --now cups.service
	commit_etc "Enable cups.service"
	systemctl restart cups.service
}
set_up_printing


cat > /etc/portage/package.use/xfce4-power-manager <<-END
	xfce-base/xfce4-power-manager networkmanager -panel-plugin
	END
commit_etc "Set USE flags for xfce-base/xfce4-power-manager"
my_emerge --verbose --newuse xfce-base/xfce4-power-manager
commit_etc "Emerged xfce-base/xfce4-power-manager"
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
install \
	--mode u=rw,go=r \
	--owner root \
	--group root \
	"$script_location/xfce4-power-manager.xml" \
	/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml

cat > /etc/portage/package.use/keepassxc <<-END
	app-admin/keepassxc autotype browser doc
	END
commit_etc "Set USE flags for app-admin/keepassxc"
my_emerge --verbose --newuse app-admin/keepassxc
commit_etc "Emerged app-admin/keepassxc"

echo "app-editors/emacs toolkit-scroll-bars" > /etc/portage/package.use/emacs
commit_etc "Set USE flags for app-editors/emacs"
echo "x11-misc/dex ~amd64" > /etc/portage/package.accept_keywords/dex
commit_etc "Accept keyword ~amd64 for x11-misc/dex (autostart)"
echo "app-backup/deja-dup ~amd64" > /etc/portage/package.accept_keywords/deja-dup
commit_etc "Accept keyword ~amd64 for app-backup/deja-dup"
cat > /etc/portage/package.use/gvfs <<-END
	# required by app-backup/deja-dup-43.4-r1::gentoo
	# required by app-backup/deja-dup (argument)
	>=gnome-base/gvfs-1.50.3 fuse
	END
commit_etc "USE fuse for gnome-base/gvfs, on behalf of deja-dup"
echo "app-misc/remind tk" > /etc/portage/package.use/remind
commit_etc "Set custom USE flags for app-misc/remind"
echo "net-p2p/syncthing ~amd64" > /etc/portage/package.accept_keywords/syncthing
commit_etc "Accept testing version of syncthing due to go version conflict"
echo "app-backup/timeshift::guru ~amd64" > /etc/portage/package.accept_keywords/timeshift
commit_etc "Allow installation of app-backup/timeshift from guru repo"
cat > /etc/portage/package.use/libdbusmenu <<-END
	# required by x11-libs/xapp-2.4.2::gentoo
	# required by app-backup/timeshift-22.11.1-r1::guru
	# required by app-backup/timeshift (argument)
	>=dev-libs/libdbusmenu-16.04.0-r2 gtk3
	END
commit_etc "Set some USE flags to allow installation of app-backup/timeshift"
cat > /etc/portage/package.accept_keywords/stripansi <<-END
	=app-misc/stripansi-9999::local ~amd64
	>=dev-lang/ghc-9.0 ~amd64
	app-admin/haskell-updater ~amd64
	END
commit_etc "Allow installation of app-misc/stripansi from my local repo"
commit_etc "Commit before emerging desktop utilities"
my_emerge --verbose --newuse \
	app-admin/stow \
	app-admin/system-config-printer \
	app-arch/xarchiver \
	app-backup/deja-dup \
	app-backup/duply \
	app-backup/timeshift \
	app-editors/emacs \
	app-misc/stripansi \
	app-misc/remind \
	gnome-extra/nm-applet \
	media-gfx/ristretto \
		xfce-base/tumbler \
	media-sound/pavucontrol-qt \
	media-sound/pnmixer \
	net-misc/networkmanager \
	net-p2p/syncthing \
	net-print/gtklp \
	sci-calculators/galculator \
	sys-apps/the_silver_searcher \
	sys-fs/udiskie \
	sys-process/cronie \
	x11-terms/xfce4-terminal \
	x11-apps/xinput \
	x11-misc/dex \
	x11-misc/gigolo \
	x11-misc/redshift \
	x11-themes/gentoo-artwork
	# pfl provides e-file
		# https://forums.gentoo.org/viewtopic-t-822242-start-0.html
commit_etc "emerged desktop utilities"

systemctl enable --now cronie.service
commit_etc "Enable cronie for task scheduling"

echo "app-editors/vscode ~amd64" > /etc/portage/package.accept_keywords/vscode
commit_etc "Accept keyword ~amd64 for app-editors/vscode"
echo "You need to unmask the license yourself if you haven't already - a simple way to do so is:"
echo 'echo "app-editors/vscode Microsoft-vscode" >> /etc/portage/package.license'
echo ""
my_emerge --verbose --newuse app-editors/vscode
commit_etc "emerged app-editors/vscode"


echo "Mark nano and gnome-keyring as manually installed"
# depclean wanted to remove them after a new install, but things will be
# relying on gnome-keyring and I want to keep nano installed as a backup
# in case I mess up vim
my_emerge --verbose --newuse --deep gnome-base/gnome-keyring app-editors/nano
commit_etc "Added gnome-keyring and nano to selected packages"

if which nscde
then
	echo "XSESSION=nscde" > /etc/env.d/90xsession
	env-update
	commit_etc "Set default xsession to nscde"
fi

commit_etc "Commit before installing lightdm"
echo "x11-misc/lightdm gtk -gnome" > /etc/portage/package.use/lightdm
commit_etc "Set USE flags for x11-misc/lightdm"
my_emerge --verbose --newuse x11-misc/lightdm
commit_etc "Emerged x11-misc/lightdm"
systemctl enable lightdm.service

if [ -x /usr/bin/ssh-agent ]
then
	sed -i \
		'/^Exec=/cExec=/usr/bin/ssh-agent /usr/local/bin/nscde' \
		/usr/share/xsessions/nscde.desktop
fi


# TODO Install nocsd (maybe make a local ebuild?)
# 	https://github.com/PCMan/gtk3-nocsd
# 	deja-dup is working horribly with CSD.
# TODO fix font and widget sizes in deja-dup
# TODO consider using eix https://wiki.gentoo.org/wiki/Eix
# TODO Add shortcut to Gentoo Cheatsheet to the help subpanel
# TODO media-gfx/sane-airscan
# TODO is there a way to re-display the post-install messages from emerge?
# TODO https://wiki.gentoo.org/wiki/Printing#Printing-related_applications
# TODO equery depends dev-lang/ruby
# TODO warpinator https://github.com/linuxmint/warpinator
# TODO webapp-manager https://github.com/linuxmint/webapp-manager
# TODO a real MTA for local mail delivery
# TODO portage update notifications (porticron?)
# TODO a lightweight mail reader for local mail
# https://www.fvwm.org/Wiki/Config/Bindings/
# TODO Bind border right click to raise/lower
# TODO Bind in-window Super-Left-Drag to move
# TODO Remove keybindings for Shift-Arrow to switch windows (I want to use that in apps!)
# TODO Warp pointer to titlebar of new window?
# TODO fix backspace key in xterm

# Stuff for work (probably add to boxbuild)
# TODO gambas (or port my tool to tkinter)
# TODO thunderbird
# TODO Gajim
# TODO brave-bin

commit_etc "Commit before reverting tempoaray USE flags"
rm /etc/portage/package.use/firefox-bin-temp
commit_etc "REVERT: Temporarily USE minimal for libsndfile to allow for dependency cycle"
my_emerge --newuse media-libs/libsndfile
commit_etc "Rebuild libsndfile with its intended USE flags"


commit_etc "Commit before emerging world for updated USE flags"
my_emerge --ask --verbose --newuse --deep @world
commit_etc "Remerged world for updated USE flags"

possibly_set_password_for_nick

eselect news list new
echo 'See `eselect news` to find out how to read news'
echo "A reboot may be required if PAM was emerged and starts playing up"
