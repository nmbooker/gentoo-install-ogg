# Copyright 2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Strip ANSI colour ESC sequences out of a stream"
HOMEPAGE="https://github.com/nmbooker/stripansi"
EGIT_REPO_URI="https://github.com/nmbooker/stripansi.git"
SCM="git-r3"
CABAL_FEATURES=""

inherit ${SCM} haskell-cabal

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"

DEPEND=""
RDEPEND=""
BDEPEND="
	>=dev-lang/ghc-9.0
	>=dev-haskell/cabal-2.2.0.1
"
DOCS=( README.md )

src_prepare() {
	default
}

src_configure() {
	haskell-cabal_src_configure \
		--flag=-pedantic
}

src_install() {
	default
	cabal_src_install
}

pkg_postinst() {
	haskell-cabal_pkg_postinst
}
