#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

##apt install -y autopoint

wget -qO- uny.nu/pkg | bash -s buildsys

### Installing build dependencies
unyp install fontconfig freetype libjpeg-turbo libpng libtiff libwebp

#pip3_bin=(/uny/pkg/python/*/bin/pip3)
#"${pip3_bin[0]}" install --upgrade pip
#"${pip3_bin[0]}" install docutils pygments

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/git/unypkg/fn
uny_auto_github_conf

######################################################################################################################
### Timestamp & Download

uny_build_date

mkdir -pv /uny/sources
cd /uny/sources || exit

pkgname="ghostscript"
pkggit="https://git.ghostscript.com/ghostpdl.git refs/tags/*"
gitdepth=""

### Get version info from git remote
# shellcheck disable=SC2086
latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep -E "ghostpdl-[0-9.]+$" | sort --version-sort --field-separator=- --key=2 | tail --lines=1)"
latest_ver="$(echo "$latest_head" | grep -o "ghostpdl-[0-9.].*" | sed "s|ghostpdl-||")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

git_clone_source_repo

cd "$pkg_git_repo_dir" || exit
rm -rf gpdl pcl
rm -rf freetype jpeg libpng zlib
git clone $gitdepth --recurse-submodules -j8 --single-branch -b \
    "$(git ls-remote --refs --tags --sort="v:refname" https://github.com/DanBloomberg/leptonica.git refs/tags/* |
        grep -E "/[0-9.]+$" | tail --lines=1 | sed "s|.*refs/[^/]*/||")" https://github.com/DanBloomberg/leptonica.git
cd /uny/sources || exit

archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vx
source /uny/git/unypkg/fn

pkgname="ghostscript"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths

####################################################
### Start of individual build script

unset LD_RUN_PATH

./autogen.sh \
    --prefix=/uny/pkg/"$pkgname"/"$pkgver" \
    --disable-compile-inits \
    --with-system-libtiff

make -j"$(nproc)"
make -j"$(nproc)" so

make -j"$(nproc)" install
make -j"$(nproc)" soinstall &&
    install -v -m644 base/*.h /uny/pkg/"$pkgname"/"$pkgver"/include/ghostscript &&
    ln -sfvn ghostscript /uny/pkg/"$pkgname"/"$pkgver"/include/ps

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
