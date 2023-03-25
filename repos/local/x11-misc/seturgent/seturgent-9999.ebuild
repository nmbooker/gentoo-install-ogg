# Copyright 2023 Nicholas Booker <NMBooker@gmail.com>
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Set urgent window manager hint for a window"
HOMEPAGE="https://github.com/ototo/seturgent"
EGIT_REPO_URI="https://github.com/ototo/seturgent.git"
SCM="git-r3"

inherit ${SCM}

LICENSE="WTFPL-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

DEPEND="
	x11-libs/libX11
"
RDEPEND=""
BDEPEND="
	virtual/pkgconfig
"

src_install() {
	dobin seturgent
	dodoc README.md
}

