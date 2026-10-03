#!/usr/bin/env bash
# Publishes dist/ as a GitHub release and points Package.swift at its binary.
#
#   Tools/release.sh [REVISION]
#
# The release is tagged with the VLCKit tag from versions.env, or <tag>.REVISION
# to publish a rebuild of the same VLCKit (4.0.0-a25.1 sorts after 4.0.0-a25).
# Run Tools/build.sh and Tools/archive-source.sh first.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=/dev/null
source versions.env

tag=$VLCKIT_TAG${1:+.$1}
zip=dist/VLCKit.xcframework.zip
source_tar=dist/VLCKit-$VLCKIT_TAG-source.tar
for file in "$zip" "$zip.checksum" "$source_tar"; do
    test -f "$file" || { echo "No $file; run Tools/build.sh and Tools/archive-source.sh first" >&2; exit 1; }
done
if [ -n "$(git status --porcelain)" ]; then
    echo "Commit or stash your changes first" >&2
    exit 1
fi
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "Tag $tag exists; pass a revision, e.g. $0 1" >&2
    exit 1
fi

cat >Package.swift <<EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VLCKit",
    platforms: [.iOS(.v12)],
    products: [
        .library(name: "VLCKit", targets: ["VLCKit"])
    ],
    targets: [
        .binaryTarget(
            name: "VLCKit",
            url: "https://github.com/ahacop/vlckit-build/releases/download/$tag/VLCKit.xcframework.zip",
            checksum: "$(cat "$zip.checksum")"
        )
    ]
)
EOF
git add Package.swift
git commit -q -m "Release $tag"
git tag "$tag"
git push -q origin HEAD "$tag"

gh release create "$tag" "$zip" "$source_tar" --prerelease --title "VLCKit $tag without zvbi" --notes "VLCKit $VLCKIT_TAG for iOS, built without zvbi (see README.md). VLCKit-$VLCKIT_TAG-source.tar is its complete corresponding source under the LGPL 2.1."
echo "== released $tag"
