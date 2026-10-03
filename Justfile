# List the recipes
default:
    @just --list

# Build VLCKit for iOS without zvbi into dist/ (takes hours)
build:
    Tools/build.sh

# Archive the complete corresponding source of the last build into dist/
source:
    Tools/archive-source.sh

# Publish dist/ as a GitHub release and point Package.swift at it; pass a revision to republish the same VLCKit tag
release revision="":
    Tools/release.sh {{revision}}

# Delete the build tree and dist/
clean:
    rm -rf work dist
