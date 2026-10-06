#!/bin/bash
# wine-proton-9.0-arm64ec for Android (arm64ec + aarch64 + i386).
#
# Toolchain/termuxfs setup follows the existing proton CI scripts. Configure flags are the ones
# from this tree's build.sh, with one change: --with-xinput --with-xinput2 (instead of
# --without-xinput --without-xinput2), so winex11 takes raw mouse input (WM_INPUT / DirectInput)
# from the X server's XI_RawMotion / XI_RawButton* events.

export ARCH="aarch64"
export WIN_ARCH="arm64ec,aarch64,i386"
export OUTPUT_DIR="$HOME/compiled-files-aarch64"
export PACKAGE_NAME="proton-9.0-arm64ec"

export deps="$HOME/termuxfs/aarch64/data/data/com.termux/files/usr"
export RUNTIME_PATH="/data/data/com.termux/files/usr"
export install_dir=$deps/../opt/wine

export TOOLCHAIN="$HOME/Android/Sdk/ndk/27.3.13750724/toolchains/llvm/prebuilt/linux-x86_64/bin"
export LLVM_MINGW_TOOLCHAIN="$HOME/toolchains/llvm-mingw-20250920-ucrt-ubuntu-22.04-x86_64/bin"
export TARGET=aarch64-linux-android28
export PATH=$LLVM_MINGW_TOOLCHAIN:$PATH

# ccache (when installed): wraps the NDK clang and, through the clang symlinks first on PATH,
# the llvm-mingw cross compiler, so CI rebuilds reuse unchanged objects.
if command -v ccache >/dev/null 2>&1; then
  export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
  ccache -M 3G >/dev/null 2>&1 || true
  mkdir -p "$HOME/ccache-bin"
  ln -sf "$(command -v ccache)" "$HOME/ccache-bin/clang"
  ln -sf "$(command -v ccache)" "$HOME/ccache-bin/clang++"
  export PATH="$HOME/ccache-bin:$PATH"
  export CC="ccache $TOOLCHAIN/$TARGET-clang"
  export CXX="ccache $TOOLCHAIN/$TARGET-clang++"
else
  export CC=$TOOLCHAIN/$TARGET-clang
  export CXX=$TOOLCHAIN/$TARGET-clang++
fi
export AS=$TOOLCHAIN/$TARGET-clang
export AR=$TOOLCHAIN/llvm-ar
export LD=$TOOLCHAIN/ld
export RANLIB=$TOOLCHAIN/llvm-ranlib
export STRIP=$TOOLCHAIN/llvm-strip
export DLLTOOL=$LLVM_MINGW_TOOLCHAIN/llvm-dlltool

export PKG_CONFIG_LIBDIR=$deps/lib/pkgconfig:$deps/share/pkgconfig
export ACLOCAL_PATH=$deps/lib/aclocal:$deps/share/aclocal
export CPPFLAGS="--sysroot=$TOOLCHAIN/../sysroot -idirafter $deps/include"

# -O2 as configure's default; -g0 instead of -g (no debug info). Setting CFLAGS replaces
# configure's default "-g -O2", so the optimization level must be given here. CROSSCFLAGS is the
# same for the PE side (arm64ec/aarch64/i386 DLLs).
export C_OPTS="-g0 -O2 -Wno-declaration-after-statement -Wno-implicit-function-declaration -Wno-int-conversion"
export CFLAGS=$C_OPTS
export CXXFLAGS=$C_OPTS
export CROSSCFLAGS="-g0 -O2"
export LDFLAGS="-L$deps/lib -Wl,-rpath=$RUNTIME_PATH/lib"

export FREETYPE_CFLAGS="-I$deps/include/freetype2"
export PULSE_CFLAGS="-I$deps/include/pulse"
export PULSE_LIBS="-L$deps/lib/pulseaudio -lpulse"
export SDL2_CFLAGS="-I$deps/include/SDL2"
export SDL2_LIBS="-L$deps/lib -lSDL2"
export X_CFLAGS="-I$deps/include/X11"
export X_LIBS="-landroid-sysvshm"
export GSTREAMER_CFLAGS="-I$deps/include/gstreamer-1.0 -I$deps/include/glib-2.0 -I$deps/lib/glib-2.0/include -I$deps/glib-2.0/include -I$deps/lib/gstreamer-1.0/include"
export GSTREAMER_LIBS="-L$deps/lib -lgstgl-1.0 -lgstapp-1.0 -lgstvideo-1.0 -lgstaudio-1.0 -lglib-2.0 -lgobject-2.0 -lgio-2.0 -lgsttag-1.0 -lgstbase-1.0 -lgstreamer-1.0"
export FFMPEG_CFLAGS="-I$deps/include/libavutil -I$deps/include/libavcodec -I$deps/include/libavformat"
export FFMPEG_LIBS="-L$deps/lib -lavutil -lavcodec -lavformat"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

for arg in "$@"
do
  if [ "$arg" == "--build-sysvshm" ];
  then
    # winex11 links libandroid-sysvshm (X_LIBS, MIT-SHM); termuxfs does not ship it.
    echo "Building android_sysvshm library..."
    cd "$PROJECT_ROOT/android/android_sysvshm"
    bash ./build-aarch64.sh || exit 1
    mkdir -p "$deps/lib"
    cp build-aarch64/libandroid-sysvshm.so "$deps/lib/"
    echo "Copied libandroid-sysvshm.so to $deps/lib/"
    cd "$PROJECT_ROOT"
  fi

  if [ "$arg" == "--configure" ];
  then
    ./configure \
      --enable-archs=$WIN_ARCH \
      --host=$TARGET \
      --prefix $install_dir \
      --bindir $install_dir/bin \
      --libdir $install_dir/lib \
      --exec-prefix $install_dir \
      --with-mingw=clang \
      --with-wine-tools=./wine-tools \
      --with-pulse \
      --with-ffmpeg \
      --with-gstreamer \
      --with-pthread \
      --without-dbus \
      --with-freetype \
      --enable-wineandroid_drv=no \
      --without-cups \
      --without-v4l2 \
      --enable-nls \
      --disable-tests \
      --without-capi \
      --without-coreaudio \
      --without-gettext \
      --with-gettextpo=no \
      --without-gphoto \
      --without-inotify \
      --without-netapi \
      --without-opencl \
      --without-oss \
      --without-pcap \
      --without-sane \
      --without-udev \
      --without-unwind \
      --without-usb \
      --without-xfixes \
      --without-xcomposite \
      --without-xcursor \
      --without-xinerama \
      --with-xinput \
      --with-xinput2 \
      --without-xrandr \
      --without-xrender \
      --without-xshape \
      --with-xshm \
      --without-xxf86vm \
      --without-wayland \
      --without-pcsclite || exit 1

    # configure silently drops XInput when libxi is missing; fail instead of shipping without it
    for define in HAVE_X11_EXTENSIONS_XINPUT_H HAVE_X11_EXTENSIONS_XINPUT2_H SONAME_LIBXI; do
      if ! grep -q "^#define $define" include/config.h; then
        echo "ERROR: XInput not enabled ($define missing from include/config.h)"
        exit 1
      fi
    done
  fi

  if [ "$arg" == "--build" ]
  then
    echo "Building..."
    rm -rf $OUTPUT_DIR/bin
    rm -rf $OUTPUT_DIR/lib
    rm -rf $OUTPUT_DIR/share
    rm -rf $install_dir
    make -j$(nproc) || exit 1
  fi

  if [ "$arg" == "--install" ]
  then
    echo "Installing..."
    mkdir -p $OUTPUT_DIR/bin
    mkdir -p $OUTPUT_DIR/lib
    mkdir -p $OUTPUT_DIR/share
    mkdir -p $install_dir
    make install -j$(nproc) || exit 1
    cp -r $install_dir/bin/wine* $OUTPUT_DIR/bin
    cp -r $install_dir/bin/reg* $OUTPUT_DIR/bin
    cp -r $install_dir/bin/msi* $OUTPUT_DIR/bin
    cp -r $install_dir/bin/notepad $OUTPUT_DIR/bin
    cp -r $install_dir/lib/wine  $OUTPUT_DIR/lib
    cp -r $install_dir/share/wine  $OUTPUT_DIR/share

    # llvm-strip handles both ELF (unix .so, loaders, wineserver) and PE (DLLs/EXEs); --strip-all
    # keeps the PE export directory and ELF .dynsym, so everything still loads. Non-fatal per file.
    echo "Stripping binaries..."
    before_mb=$(du -sm $OUTPUT_DIR | cut -f1)
    find $OUTPUT_DIR/lib $OUTPUT_DIR/bin -type f \
      \( -name '*.dll' -o -name '*.exe' -o -name '*.drv' -o -name '*.sys' -o -name '*.so' \
         -o -name 'wine' -o -name 'wine-preloader' -o -name 'wineserver' \) \
      -print0 | while IFS= read -r -d '' f; do
        "$STRIP" --strip-all "$f" 2>/dev/null || "$STRIP" --strip-debug "$f" 2>/dev/null || true
      done
    echo "Package tree: ${before_mb}MB -> $(du -sm $OUTPUT_DIR | cut -f1)MB after strip"

    # the XInput2 raw-input fix must be in the binaries
    unixdir="$OUTPUT_DIR/lib/wine/aarch64-unix"
    grep -q "XIQueryVersion" "$unixdir/winex11.so" || { echo "ERROR: winex11.so built without XInput2"; exit 1; }
    "$TOOLCHAIN/llvm-nm" -D --defined-only "$unixdir/win32u.so" | grep -q " win32u_set_hardware_mouse_rawinput$" \
      || { echo "ERROR: win32u.so lacks win32u_set_hardware_mouse_rawinput"; exit 1; }
  fi

  if [ "$arg" == "--package" ]
  then
    # bin/ lib/ share/ at the top, like the proton-9.0-arm64ec.tar.zst the emulator bundles
    tar -C $OUTPUT_DIR -I 'zstd -19 -T0' -cf $HOME/$PACKAGE_NAME.tar.zst bin lib share || exit 1
    echo "$PACKAGE_NAME.tar.zst: $(stat -c %s $HOME/$PACKAGE_NAME.tar.zst) bytes, sha256 $(sha256sum $HOME/$PACKAGE_NAME.tar.zst | cut -d' ' -f1)"
  fi
done
