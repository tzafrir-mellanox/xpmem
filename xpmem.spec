%{!?KMP: %global KMP 0}

%{!?KVERSION: %global KVERSION %(uname -r)}
%global krelver %(echo -n %{KVERSION} | sed -e 's/-/_/g')
%{!?K_SRC: %global K_SRC /lib/modules/%{KVERSION}/build}
# A separate variable _release is required because of the odd way the
# script append_number_to_package_release.sh works:
%global _release 1

Summary: Cross-partition memory
Name: xpmem
Version: 2.6.3
Release: %{_release}%{?_dist}
License: GPLv2 and LGPLv2.1
Group: System Environment/Libraries
Packager: Tzafrir Cohen <nvidia@cohens.org.il>
BuildRequires: automake autoconf
URL: https://github.com/openucx/xpmem
Source: %{name}-%{version}.tar.gz

# name gets a different value in subpackages
%global _name %{name}
%global _kmp_rel %{release}%{?_kmp_build_num}%{?_dist}
# Required for e.g. SLES12:
%if %{undefined make_build}
%global make_build %{__make} %{?_smp_mflags}
%endif

%description
XPMEM is a Linux kernel module that enables a process to map the
memory of another process into its virtual address space. Source code
can be obtained by cloning the Git repository, original Mercurial
repository or by downloading a tarball from the link above.

This package includes helper tools for the kernel module.

%package -n libxpmem
Summary: XPMEM: Userspace library
%description -n libxpmem
XPMEM is a Linux kernel module that enables a process to map the
memory of another process into its virtual address space. Source code
can be obtained by cloning the Git repository, original Mercurial
repository or by downloading a tarball from the link above.


%package -n libxpmem-devel
Summary: XPMEM: userspace library development headers
%description -n libxpmem-devel
XPMEM is a Linux kernel module that enables a process to map the
memory of another process into its virtual address space. Source code
can be obtained by cloning the Git repository, original Mercurial
repository or by downloading a tarball from the link above.

This package includes development headers.

# build KMP rpms?
%if "%{KMP}" == "1"
%global kernel_release() $(make -C %{1} M=$PWD kernelrelease | grep -v make)
BuildRequires: %kernel_module_package_buildreqs
%(cat > %{_builddir}/preamble << EOF
Requires: %{_name}
EOF)
%{kernel_module_package -r %{_kmp_rel} -p %{_builddir}/preamble}
%else # not KMP
%global kernel_source() %{K_SRC}
%global kernel_release() %{KVERSION}
%global flavors_to_build default

%package modules
Requires: %{_name}
# %{nil}: to avoid having the script that build OFED-internal
# munge the release version here as well:
Release%{nil}: %{release}.kver.%{krelver}
Summary: XPMEM: kernel modules
Group: System Environment/Libraries
%description modules
XPMEM is a Linux kernel module that enables a process to map the
memory of another process into its virtual address space. Source code
can be obtained by cloning the Git repository, original Mercurial
repository or by downloading a tarball from the link above.

This package includes the kernel module (non KMP version).
%endif #end if "%{KMP}" == "1"

%if "%{_vendor}" == "suse"
%global install_mod_dir updates
%endif

%if 0%{?rhel} > 0
%global install_mod_dir extra/%{_name}
%endif
%global moduledir /lib/modules/%{KVERSION}/%{install_mod_dir}

%prep
%setup -q

%build
env=
if [ "$CROSS_COMPILE" != '' ]; then
  env="$env CC=${CROSS_COMPILE}gcc"
fi
./autogen.sh
%{configure} \
  --with-module-prefix= \
  --with-kerneldir=%{K_SRC} \
  $env \
  #
%{make_build}

%install
%{make_install} moduledir=%{moduledir}
rm -rf $RPM_BUILD_ROOT/etc/init.d/xpmem
mkdir -p $RPM_BUILD_ROOT%{_prefix}/lib/modules-load.d
echo "xpmem" >$RPM_BUILD_ROOT%{_prefix}/lib/modules-load.d/xpmem.conf

%clean
rm -rf $RPM_BUILD_ROOT

%post   -n libxpmem -p /sbin/ldconfig
%postun -n libxpmem -p /sbin/ldconfig

%files
/lib/udev/rules.d/*-xpmem.rules
%{_prefix}/lib/modules-load.d/xpmem.conf
%doc README AUTHORS COPYING COPYING.LESSER

%files -n libxpmem
%{_libdir}/libxpmem.so.*

%files -n libxpmem-devel
%{_prefix}/include/xpmem.h
%{_libdir}/libxpmem.a
%{_libdir}/libxpmem.la
%{_libdir}/libxpmem.so
%{_libdir}/pkgconfig/cray-xpmem.pc

%if "%{KMP}" != "1"
%files modules
%{moduledir}/xpmem.ko
%endif

%changelog
