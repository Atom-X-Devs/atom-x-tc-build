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
builder_commit="$(git rev-parse HEAD)"

# Send a notificaton to TG
tg_post_msg "<b>🔨 Atom-X ToolChain Compilation Started</b>

<b>Date : </b><code>$rel_friendly_date</code>

<b>Toolchain Script Commit : </b><a href='https://github.com/Atom-X-Devs/atom-x-tc-build/commit/$builder_commit'> Check Here </a>"

# Build LLVM
msg "Building LLVM..."
tg_post_msg "<b>🔨 Progress Building LLVM. . .</b>

<b>Linker Used : </b><code>lld</code>"

BUILD_START=$(date +"%s")
LLVM_START=$(date +"%s")
./build-llvm.py \
	--clang-vendor "AtomX" \
	--targets "ARM;AArch64;X86" \
	--defines LLVM_PARALLEL_COMPILE_JOBS=$(nproc) LLVM_PARALLEL_LINK_JOBS=$(nproc) CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3 LLVM_USE_LINKER=lld \
	--pgo kernel-defconfig \
	--lto full \
	--shallow-clone

LLVM_END=$(date +"%s")
LLVM_DIFF=$(($LLVM_END - $LLVM_START))
tg_post_msg "<b> Building LLVM Successfully Completed </b>

<b>LLVM Build Time: </b><code>$((LLVM_DIFF / 60)) minute(s) $((LLVM_DIFF % 60)) second(s)</code>"

# Check if the final clang binary exists or not.
[ ! -f install/bin/clang-1* ] && {
	err "Building LLVM failed ! Kindly check errors !!"
tg_post_msg "<b> LLVM Failed To Build </b>

<b>LLVM Build Error Time: </b><code>$((LLVM_DIFF / 60)) minute(s) $((LLVM_DIFF % 60)) second(s)</code>"
}

# Build binutils
msg "Building binutils..."
BIN_START=$(date +"%s")
tg_post_msg "<b>🔨 Progress Building Binutils. . .</b>"
./build-binutils.py --targets arm aarch64 x86_64
BIN_END=$(date +"%s")
BIN_DIFF=$(($BIN_END - $BIN_START))

tg_post_msg "<b> Building Binutils Successfully Completed </b>

<b>Binutils Build Time: </b><code>$((BIN_DIFF / 60)) minute(s) $((BIN_DIFF % 60)) second(s)</code>"

# Remove unused products
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip -s "${f: : -1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	echo "$bin"
	patchelf --set-rpath "$DIR/install/lib" "$bin"
done

# Release Info
pushd llvm-project || exit
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<< "$llvm_commit")"
popd || exit

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$short_llvm_commit"
binutils_ver="$(ls | grep "^binutils-" | sed "s/binutils-//g")"
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"
BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

tg_post_msg "✅ <b>The Atom-X ToolChain Compilation Finished</b>

<b>Clang Version : </b><code>$clang_version</code>

<b>LLVM Commit : </b><a href='$llvm_commit_url'> Check Here </a>

<b>Binutils Version : </b><code>$binutils_ver</code>

<b>Atom-X Build Time : </b><code>$((DIFF / 60)) minute(s) $((DIFF % 60)) second(s)</code>"

bash atom-x-push.sh
