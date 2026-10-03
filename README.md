# vlckit-build

[VLCKit](https://code.videolan.org/videolan/VLCKit) for iOS, built from VideoLAN's
source without [zvbi](https://github.com/zapping-vbi/zvbi), as a Swift package.
NAS Wildcard uses it in place of VideoLAN's prebuilt VLCKit.

## Why

VideoLAN's Apple builds turn off GPL contribs (`--disable-gpl`) but turn on zvbi.
zvbi is LGPL-2+ except `src/pdc.c` and `src/packet-830.c`, which are GPL-2.0-only,
and the prebuilt VLCKit links their functions.
[`patches/libvlc/9001-apple-build-without-zvbi.patch`](patches/libvlc/9001-apple-build-without-zvbi.patch)
switches zvbi off in `extras/package/apple/build.conf`. libVLC then builds its own
`telx` decoder instead, which still decodes teletext subtitles; only teletext page
browsing goes.

The only other change,
[`patches/vlckit/0001-Build-the-iOS-framework-for-iOS-15.0-and-later.patch`](patches/vlckit/0001-Build-the-iOS-framework-for-iOS-15.0-and-later.patch),
raises the framework's deployment target from 9.0 to 15.0, the lowest Xcode 27
accepts.

## Using it

```swift
.package(url: "https://github.com/ahacop/vlckit-build", exact: "4.0.0-a25.1")
```

The product is `VLCKit`, so `import VLCKit` is unchanged. Only iOS and the iOS
simulator are built.

## Building a release

`versions.env` pins the VLCKit tag. To build it and publish it:

```bash
just build
just source
just release
```

`just build` clones VLCKit into `work/`, applies `patches/vlckit` to it, adds
`patches/libvlc` to its `libvlc/patches`, runs its `compileAndBuildVLCKit.sh -f -r`,
checks every slice has no zvbi symbols and has `telx`, and zips the xcframework
into `dist/`. It takes hours; rerunning
reuses `work/`. `just source` archives the complete corresponding source of that
build, and `just release` tags it, writes `Package.swift` and publishes both as a
GitHub release.

To move to a new VLCKit, update `versions.env`, check the patch still applies to
the libVLC commit its `compileAndBuildVLCKit.sh` names (`TESTEDHASH`), then
`just clean` and build again. To republish the same VLCKit, `just release 1`
tags it `<tag>.1`.

## License

VLCKit and libVLC are LGPL 2.1 ([LICENSE](LICENSE)); each release carries the
complete corresponding source of its binary.
