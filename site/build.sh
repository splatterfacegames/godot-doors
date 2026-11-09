#!/usr/bin/env bash
# Build https://doorproblem.splatterfacegames.com into site/dist: the page in
# site/public and the Web export of the demo (Compatibility renderer, no
# threads) in site/dist/play. Files over the Pages limit move to
# site/.r2-upload; site/functions serves them from the R2 bucket
# doorproblem-web.
#
#   GODOT=<godot 4.7.2> site/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"

rm -rf site/dist site/.r2-upload
mkdir -p site/dist/play

# The first import after a checkout can crash; a second one passes.
"$GODOT" --headless --path . --import || "$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release Web site/dist/play/index.html
test -s site/dist/play/index.pck

cp -R site/public/. site/dist/
node site/prepare_r2_assets.mjs site/dist site/.r2-upload
