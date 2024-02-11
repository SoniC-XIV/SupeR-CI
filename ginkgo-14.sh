#!/usr/bin/env bash
#
# Copyright (C) 2021 a kucingabu property
#

# Main
MainPath="$(pwd)"
MainClangPath="${MainPath}/clang"
MainClangZipPath="${MainPath}/clang-zip"
ClangPath="${MainClangZipPath}"
GCCaPath="${MainPath}/GCC64"
GCCbPath="${MainPath}/GCC32"
MainZipGCCaPath="${MainPath}/GCC64-zip"
MainZipGCCbPath="${MainPath}/GCC32-zip"

ClangPath=${MainClangZipPath}
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
mkdir $ClangPath
rm -rf $ClangPath/*
git clone --depth 1 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 $ClangPath

mkdir $GCCaPath
mkdir $GCCbPath
git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git $GCCaPath
git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git $GCCbPath

#Main2
export TZ="Asia/Jakarta"
KERNEL_ROOTDIR=$(pwd) # IMPORTANT ! Fill with your kernel source root directory.
DEVICE_CODENAME=GINKGO
DEVICE_DEFCONFIG=vendor/ginkgo-perf_defconfig
export KERNEL_NAME=$(cat "arch/arm64/configs/$DEVICE_DEFCONFIG" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )
export KBUILD_BUILD_USER=[ASM-26]
export KBUILD_BUILD_HOST=Lek_N-XIV
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
CLANG_VER="$("$ClangPath"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
LLD_VER="$("$ClangPath"/bin/ld.lld --version | head -n 1)"
export KBUILD_COMPILER_STRING="$CLANG_VER with $LLD_VER"
DATE=$(date +"%F-%S")
VER=MIUI
START=$(date +"%s")
PATH=${ClangPath}/bin:${GCCaPath}/bin:${GCCbPath}/bin:${PATH}
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img
DTB=$(pwd)/out/arch/arm64/boot/dtb.img
# Post Main Information
tg_post_msg "<b>KernelCompiler</b>%0AKernel Name : <code>${KERNEL_NAME}</code>%0AKernel Version : <code>${KERVER}</code>%0ABuild Date : <code>${DATE}</code>%0ABuilder Name : <code>${KBUILD_BUILD_USER}</code>%0ABuilder Host : <code>${KBUILD_BUILD_HOST}</code>%0ADevice Defconfig: <code>${DEVICE_DEFCONFIG}</code>%0AClang Version : <code>${KBUILD_COMPILER_STRING}</code>%0AClang Rootdir : <code>${ClangPath}</code>%0AKernel Rootdir : <code>${KERNEL_ROOTDIR}</code>"

# Compile
compile(){
tg_post_msg "<b>KernelCompiler:</b><code>Compilation has started</code>"
cd ${KERNEL_ROOTDIR}
make -j$(nproc) O=out ARCH=arm64 $DEVICE_DEFCONFIG
make -j$(nproc) ARCH=arm64 O=out \
    LD_LIBRARY_PATH="${ClangPath}/lib64:${LD_LIBRARY_PATH}" \
    NM=${ClangPath}/bin/llvm-nm \
    AR=${ClangPath}/bin/llvm-ar \
    AS=${ClangPath}/llvm-as \
    LD=${ClangPath}/bin/ld.lld \
    OBJCOPY=${ClangPath}/bin/llvm-objcopy \
    OBJDUMP=${ClangPath}/bin/llvm-objdump \
    STRIP=${ClangPath}/bin/llvm-strip \
    CC=${ClangPath}/bin/clang \
    CROSS_COMPILE=${ClangPath}/aarch64-linux-android- \
    CROSS_COMPILE_ARM32=${ClangPath}/arm-linux-androideabi- \
    CLANG_TRIPLE=aarch64-linux-gnu- Image.gz-dtb dtbo.img
    2>&1 | tee error.log

   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi
  git clone --depth=1 https://github.com/SoniC-XIV/Anykernel3 -b master AnyKernel
	    cp $IMAGE AnyKernel
        cp $DTBO AnyKernel
}
# Push kernel to channel
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="✅Compile took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>$DEVICE_CODENAME</b> | <b>${KBUILD_COMPILER_STRING}</b>"
}
# Fin Error
function finerr() {
    LOG=$(echo error.log)
    curl -F document=@$LOG "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="❌ Compilation Failed. | For <b>${DEVICE_CODENAME}</b> | <b>${KBUILD_COMPILER_STRING}</b>"
    exit 1
}

# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 [$VER]$KERNEL_NAME[$DEVICE_CODENAME]${DATE}.zip *
    cd ..
}
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
