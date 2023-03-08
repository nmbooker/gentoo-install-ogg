#!/bin/bash

set -e

if which emacs
then
	if ! [ -d ~/.config/emacs ]
	then
		git clone --depth 1 \
			https://github.com/doomemacs/doomemacs \
			~/.config/emacs
	fi
	if ! [ -d ~/.config/doom ]
	then
		~/.config/emacs/bin/doom install
	fi
fi
