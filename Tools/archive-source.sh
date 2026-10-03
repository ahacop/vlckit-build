#!/usr/bin/env bash
# Archives the complete corresponding source of the last Tools/build.sh run,
# for the LGPL's source requirement. The release publishes it next to the
# binary.
#
#   Tools/archive-source.sh
#
# writes dist/VLCKit-<tag>-source.tar with:
#   VLCKit-<tag>.tar.gz        VLCKit at the tag in versions.env, with
#                              patches/vlckit applied and patches/libvlc
#                              added to libvlc/patches
#   vlc-<hash>-patched.tar.gz  libVLC at the commit VLCKit builds on, with all
#                              of libvlc/patches applied, as the build did
#   contrib-tarballs/          the source of every third-party library the
#                              build compiled, as VLC's contrib system fetched
#                              and checked them
#   README.txt, SHA256SUMS
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=/dev/null
source versions.env

work=work/VLCKit-$VLCKIT_TAG
vlc=$work/libvlc/vlc
test -d "$vlc/contrib/tarballs" || { echo "No build in $work; run Tools/build.sh first" >&2; exit 1; }
tested=$(sed -n 's/^TESTEDHASH="\([0-9a-f]*\)".*/\1/p' "$work/compileAndBuildVLCKit.sh")
described=$(git -C "$vlc" describe --tags --match '4.0.0-dev' HEAD)
vlckit_patches=$(cd patches/vlckit && ls *.patch)
libvlc_patches=$(cd patches/libvlc && ls *.patch)

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
name=VLCKit-$VLCKIT_TAG-source
out=$stage/$name
mkdir -p "$out/contrib-tarballs"

echo "== VLCKit $VLCKIT_TAG"
git -C "$work" archive --format=tar --prefix="VLCKit-$VLCKIT_TAG/" -o "$stage/vlckit.tar" HEAD
for patch in $libvlc_patches; do
    tar -rf "$stage/vlckit.tar" -s ",^patches/libvlc/,VLCKit-$VLCKIT_TAG/libvlc/patches/," "patches/libvlc/$patch"
done
gzip -c "$stage/vlckit.tar" >"$out/VLCKit-$VLCKIT_TAG.tar.gz"

echo "== libVLC $described"
git -C "$vlc" archive --format=tar.gz --prefix="vlc/" -o "$out/vlc-$tested-patched.tar.gz" HEAD

echo "== contrib sources"
cp "$vlc/contrib/tarballs/"* "$out/contrib-tarballs/"

cat >"$out/README.txt" <<EOF
Complete corresponding source of the VLCKit $VLCKIT_TAG built by
https://github.com/ahacop/vlckit-build, provided under the GNU LGPL 2.1.

VLCKit-$VLCKIT_TAG.tar.gz
    VLCKit at tag $VLCKIT_TAG (commit $VLCKIT_COMMIT), from
    https://code.videolan.org/videolan/VLCKit, with these patches applied:
$(sed 's/^/      /' <<<"$vlckit_patches")
    and these added to libvlc/patches:
$(sed 's/^/      /' <<<"$libvlc_patches")
    compileAndBuildVLCKit.sh is the build script.

vlc-$tested-patched.tar.gz
    libVLC (https://code.videolan.org/videolan/vlc) at commit $tested, the
    TESTEDHASH in compileAndBuildVLCKit.sh, with libvlc/patches applied.
    git describe: $described

contrib-tarballs/
    Source of the third-party libraries built into libVLC, as fetched by VLC's
    contrib system (contrib/src/*/rules.mak) and checked against its SHA512SUMS.

To rebuild VLCKit from this archive:
    tar xzf VLCKit-$VLCKIT_TAG.tar.gz
    tar xzf vlc-$tested-patched.tar.gz -C VLCKit-$VLCKIT_TAG/libvlc
    mkdir -p VLCKit-$VLCKIT_TAG/libvlc/vlc/contrib/tarballs
    cp contrib-tarballs/* VLCKit-$VLCKIT_TAG/libvlc/vlc/contrib/tarballs/
    cd VLCKit-$VLCKIT_TAG && ./compileAndBuildVLCKit.sh -n -f -r
-n keeps the script from cloning vlc and applying the patches again, and the
contrib build takes its sources from contrib/tarballs. VLC's build tools
(extras/tools: autoconf, meson and so on) may still be downloaded.
EOF

(cd "$out" && find . -type f ! -name SHA256SUMS | sort | xargs shasum -a 256 >SHA256SUMS)
mkdir -p dist
tar -cf "dist/$name.tar" -C "$stage" "$name"
echo "== dist/$name.tar ($(du -h "dist/$name.tar" | cut -f1))"
