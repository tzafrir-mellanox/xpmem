#!/bin/bash
set -Exeuo pipefail

OS=$1
KERNEL=$2
PR_NUM=$3

xpmem_build() {
  uname -r
  gcc --version
  git clone -q https://github.com/openucx/xpmem.git
  cd xpmem
  git fetch origin pull/"$PR_NUM"/merge
  git checkout FETCH_HEAD
  ./autogen.sh
  if [[ $OS == *"ubuntu"* ]]; then
    ./configure --enable-gtest --with-kerneldir=/usr/src/linux-headers-"$(uname -r)"
    make -s
    make check
  elif [[ $OS == *"centos"* ]]; then
    # Build with GCC-8
    scl enable devtoolset-8 -- bash -c "
      ./configure --enable-gtest --with-kerneldir=/usr/src/kernels/'$(uname -r)'
      make -s
      make check
    "
  fi
}

xpmem_load() {
  sudo insmod kernel/xpmem.ko
  cat /sys/module/xpmem/srcversion
  modinfo kernel/xpmem.ko  
  if modinfo kernel/xpmem.ko | grep -qf /sys/module/xpmem/srcversion; then
    echo "XPMEM loaded successfully"
  else
    echo "Error: Failed to load xpmem kernel module" >&2
    exit 1
  fi
}

install_gcc() {
  # Find the GCC ver used to compile the running kernel
  GCC_VER=$(awk -F ' ' '{print $7}' /proc/version | cut -d'-' -f1)
  echo "INFO: Installing GCC ver $GCC_VER"
  wget -q https://ftp.gnu.org/gnu/gcc/gcc-"$GCC_VER"/gcc-"$GCC_VER".tar.xz
  wget -q https://ftp.gnu.org/gnu/gcc/gcc-"$GCC_VER"/gcc-"$GCC_VER".tar.xz.sig
  wget -q https://ftp.gnu.org/gnu/gnu-keyring.gpg
  gpgv --keyring ./gnu-keyring.gpg gcc-"$GCC_VER".tar.xz.sig gcc-"$GCC_VER".tar.xz
  tar xf gcc-"$GCC_VER".tar.xz
  (cd gcc-"$GCC_VER" && ./contrib/download_prerequisites)
  mkdir gcc-build
  cd gcc-build
  ../gcc-"${GCC_VER}"/configure --enable-languages=c,c++ --disable-multilib
  make -j"$(nproc)"
  sudo make install
  cd -
  gcc --version  
  # Create a symlink, as kernel build expects for gcc-X binary
  GCC_MAJOR_VER="${GCC_VER%%.*}"
  ln -s "$(which gcc)" "$(which gcc)"-"$GCC_MAJOR_VER"
}

err_report() {
  echo "Exited with ERROR in line $1"
}
trap 'err_report $LINENO' ERR

if [[ $KERNEL == "mainline" ]]; then
  install_gcc
fi
xpmem_build
xpmem_load
