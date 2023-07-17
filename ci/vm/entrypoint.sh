#!/bin/bash
set -Exeuo pipefail

OS=$1
PR_NUM=$2

install_packages() {
  if [[ $OS == *"ubuntu"* ]]; then
    apt-get update &&
      DEBIAN_FRONTEND=noninteractive apt-get install -yq \
        automake \
        dkms \
        git \
        libtool &&
      apt-get clean && rm -rf /var/lib/apt/lists/*
  elif [[ $OS == *"centos"* ]]; then
    yum install -y -q centos-release-scl
    yum install -y -q \
      automake \
      devtoolset-8-gcc \
      devtoolset-8-gcc-c++ \
      elfutils-libelf-devel \
      git \
      libtool \
      make &&
      yum clean all
  fi
}

xpmem_build() {
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

err_report() {
  echo "Exited with ERROR in line $1"
}
trap 'err_report $LINENO' ERR

install_packages
xpmem_build
xpmem_load
