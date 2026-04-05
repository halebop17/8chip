#!/bin/zsh
# deploy.sh — sync the repo plugin folder to Renoise's tools directory
# Usage: ./deploy.sh

SRC="/Users/denis-scholvien/git repos/8chip/com.halebop.8chip.xrnx"
DEST="$HOME/Library/Preferences/Renoise/V3.5.4/Scripts/Tools/com.halebop.8chip.xrnx"

rsync -av --delete "$SRC/" "$DEST/"
echo "\n✓ Deployed to Renoise tools. Reload all Tools in Renoise to apply."
