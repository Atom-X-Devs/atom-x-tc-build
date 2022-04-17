#!/usr/bin/env bash

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

# Set Chat ID, to push Notifications
CHATID="-1001163106123"

# Set a directory
DIR="$(pwd ...)"

# Inlined function to post a message
BOT_MSG_URL="https://api.telegram.org/bot$TOKEN/sendMessage"
builder_commit="$(git rev-parse HEAD)"

tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}
tg_post_build() {
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3"
}

# Build Info
rel_date="$(date "+%Y%m%d")" # ISO 8601 format
rel_friendly_date="$(date "+%B %-d, %Y")" # "Month day, year" format

# Release Info
pushd llvm-project || exit
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<< "$llvm_commit")"
popd || exit

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$short_llvm_commit"
binutils_ver="$(ls | grep "^binutils-" | sed "s/binutils-//g")"
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"

# Push to Gitlab
# Update Git repository
git config --global user.name "Kunmun"
git config --global user.email "kunmun@aospa.co"
git clone "git@gitlab.com:ElectroPerf/atom-x-clang.git" rel_repo
pushd rel_repo || exit
rm -fr ./*
cp -r ../install/* .
git checkout README.md # keep this as it's not part of the toolchain itself
git add .
git commit -asm "Import Atom-X Clang Build Of $rel_friendly_date

Build completed on: $rel_friendly_date
LLVM commit: $llvm_commit_url
Clang Version: $clang_version
Binutils version: $binutils_ver
Builder commit: https://github.com/Atom-X-Devs/atom-x-tc-build/commit/$builder_commit"
git push -f
popd || exit
tg_post_msg "<b>🚀The Atom-X Toochain Have Been Successfully Pushed to </b><a href='https://gitlab.com/ElectroPerf/atom-x-clang'> Gitlab </a><b>. . . Enjoy Building With Atom-X Clang</b>

<b>1:00 ●━━━━━━─────── 2:00 ⇆ㅤㅤㅤ ㅤ◁ㅤㅤ❚❚ㅤㅤ▷ㅤㅤㅤㅤ↻</b> "
