#!/usr/bin/env bash
# Builds VLCKit for iOS (device and simulator) at the tag in versions.env, with
# patches/ applied to libVLC on top of VLCKit's own libvlc/patches, and checks
# that no zvbi code made it into the binary.
#
#   Tools/build.sh
#
# writes dist/VLCKit.xcframework.zip and dist/VLCKit.xcframework.zip.checksum.
# Works in work/VLCKit-<tag>, which is kept so a rerun picks up where the last
# one stopped and Tools/archive-source.sh can archive what was built. Needs git,
# Xcode, and on PATH a python3 of 3.10+ and a gmake of 4.4+ (Homebrew's python
# and make will do); VLC builds its other tools itself. Takes hours and tens of
# GB.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=/dev/null
source versions.env

work=work/VLCKit-$VLCKIT_TAG
if [ ! -d "$work" ]; then
    mkdir -p work
    git -c advice.detachedHead=false clone --quiet --branch "$VLCKIT_TAG" https://code.videolan.org/videolan/VLCKit.git "$work"
fi
actual=$(git -C "$work" rev-parse HEAD)
if [ "$actual" != "$VLCKIT_COMMIT" ]; then
    echo "$work is at $actual, but versions.env pins $VLCKIT_COMMIT" >&2
    exit 1
fi

# compileAndBuildVLCKit.sh applies libvlc/patches/*.patch in name order, so ours
# (9xxx) go after VLCKit's. It resets libvlc/vlc and reapplies them on every run.
cp patches/*.patch "$work/libvlc/patches/"

# compileAndBuildVLCKit.sh replaces PATH with only python.org's framework Python
# and /usr/bin, whose tools are too old for this build:
#   - VLC's meson needs Python 3.10+; Apple's is 3.9.
#   - The ninja VLC builds joins make's jobserver and leaves its pipe
#     non-blocking, which Apple's make 3.81 fails on ("read jobs pipe: Resource
#     temporarily unavailable"); GNU make 4.4 copes.
# Its extras/tools/build/bin stays first on PATH throughout, so newer ones
# linked there win. Cloning vlc ourselves gives that folder a place to live;
# the script then checks out its tested commit and applies the patches as on
# any rerun.
python=$(command -v python3)
if ! "$python" -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then
    echo "$python is $("$python" --version); VLC's meson needs Python 3.10+" >&2
    exit 1
fi
gmake=$(command -v gmake) || { echo "No gmake; install GNU make 4.4+ (brew install make)" >&2; exit 1; }
if ! "$gmake" --version | head -1 | grep -qE 'GNU Make (4\.([4-9]|[1-9][0-9])|[5-9])'; then
    echo "$gmake is $("$gmake" --version | head -1); the build needs GNU Make 4.4+" >&2
    exit 1
fi
vlc=$work/libvlc/vlc
if [ ! -d "$vlc" ]; then
    git clone --quiet https://code.videolan.org/videolan/vlc.git --branch master --single-branch "$vlc"
fi
mkdir -p "$vlc/extras/tools/build/bin"
ln -sf "$python" "$vlc/extras/tools/build/bin/python3"
ln -sf "$gmake" "$vlc/extras/tools/build/bin/make"

echo "== building VLCKit $VLCKIT_TAG (log: $work/build.log)"
(cd "$work" && ./compileAndBuildVLCKit.sh -f -r) >"$work/build.log" 2>&1 || {
    tail -40 "$work/build.log" >&2
    exit 1
}

xcframework=$work/build/iOS/VLCKit.xcframework
echo "== checking $xcframework"
for binary in "$xcframework"/*/VLCKit.framework/VLCKit; do
    symbols=$(nm "$binary")
    if grep -q -e ' _vbi_' -e 'vlc_entry__codec_zvbi' <<<"$symbols"; then
        echo "$binary still contains zvbi" >&2
        exit 1
    fi
    if ! grep -q 'vlc_entry__codec_telx' <<<"$symbols"; then
        echo "$binary has no telx module, so teletext subtitles won't decode" >&2
        exit 1
    fi
    echo "   ${binary#"$xcframework"/}: no zvbi, telx present"
done

rm -rf dist
mkdir dist
ditto -c -k --keepParent "$xcframework" dist/VLCKit.xcframework.zip
swift package compute-checksum dist/VLCKit.xcframework.zip >dist/VLCKit.xcframework.zip.checksum
echo "== dist/VLCKit.xcframework.zip ($(du -h dist/VLCKit.xcframework.zip | cut -f1), checksum $(cat dist/VLCKit.xcframework.zip.checksum))"
