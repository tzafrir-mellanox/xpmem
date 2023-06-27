ARG OS_VERSION
FROM centos:${OS_VERSION}

ARG OS_VERSION
RUN if [[ "$OS_VERSION" == 8 ]]; then \
        sed -i -e "s|mirrorlist=|#mirrorlist=|g" /etc/yum.repos.d/CentOS-* && \
        sed -i -e "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-* ; \
    fi

RUN yum install -y \
        automake \
        elfutils-libelf-devel \
        kernel-headers \
        kernel-devel \
        libtool \
        make \
    && yum clean all
