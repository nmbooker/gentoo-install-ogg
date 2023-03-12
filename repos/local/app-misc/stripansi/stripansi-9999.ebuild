# Copyright 2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Strip ANSI colour ESC sequences out of a stream"
HOMEPAGE="https://github.com/nmbooker/stripansi"
EGIT_REPO_URI="https://github.com/nmbooker/stripansi.git"
SCM="git-r3"
CABAL_FEATURES=""

inherit ${SCM}

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"

DEPEND=""
RDEPEND=""
BDEPEND="
	>=dev-lang/ghc-9.0
"
DOCS=( README.md LICENSE )

src_prepare() {
	default
}

src_configure() {
	default
}

src_compile() {
	ghc -o stripansi src/Main.hs || die "compiling stripansi failed"
}

src_install() {
	default
	dobin stripansi
}

