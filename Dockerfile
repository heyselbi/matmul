
# mlcc -i Centos8,CUDA10.2,Numpy,TensorFlow,Keras
# mlcc version: 20181224a: Nov 12 2019

# Install up-to-date Centos 8

FROM centos:8

RUN set -vx \
\
&& yum -y -v install yum-utils \
&& yum-config-manager --enable \
    BaseOS \
    AppStream \
    extras \
    PowerTools \
\
&& yum -y -v install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm" \
\
&& yum -y update \
&& yum clean all


# Install Basic OS Tools

RUN set -vx \
\
&& echo -e '\
set -vx \n\
for (( TRY=1; TRY<=5; TRY++ )); do \n\
    /bin/ls -alFR /usr/lib/.build-id \n\
    /bin/rm -rf /usr/lib/.build-id \n\
    yum -y -v install $@ \n\
    result=$? \n\
    for PKG in $@ ; do \n\
        yum list installed | grep "^$PKG" \n\
        (( result += $? )) \n\
    done \n\
    if (( $result == 0 )); then \n\
        yum clean all \n\
        exit 0 \n\
    else \n\
        echo "Missing packages: ${result} of $@" \n\
    fi \n\
    sleep 10 \n\
done \n\
exit 1 \n' \
> /tmp/yum_install.sh \
\
&& echo -e '\
set -vx \n\
CACHE_DIR="/tmp/download_cache_dir" \n\
for FILE in $@ ; do \n\
    CACHED_FILE="$CACHE_DIR/`basename $FILE`" \n\
    if [ -r "$CACHED_FILE" ]; then \n\
        cp $CACHED_FILE . \n\
    else \n\
        wget $FILE \n\
        if [ -d "$CACHE_DIR" ]; then \n\
            cp `basename $FILE` $CACHED_FILE \n\
        fi \n\
    fi \n\
done \n' \
> /tmp/cached_wget.sh \
\
&& echo -e '\
cd /tmp \n\
for SCRIPT in $@ ; do \n\
    wget -q $SCRIPT -O `basename $SCRIPT` \n\
    /bin/bash `basename $SCRIPT` \n\
done \n' \
> /tmp/run_remote_bash_script.sh \
\
&& chmod +x /tmp/yum_install.sh /tmp/cached_wget.sh /tmp/run_remote_bash_script.sh \
\
&& cd /usr/local \
&& /bin/rm -rf lib64 \
&& ln -s lib lib64 \
\
&& /tmp/yum_install.sh \
    binutils \
    bzip2 \
    findutils \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    git \
    gzip \
    make \
    openssl-devel \
    patch \
    pciutils \
    unzip \
    vim-enhanced \
    wget \
    xz \
    zip



# Try to use Python3.8+
# Install Python v3.8.3, if no python3 already present


RUN set -vx \
\
&& if whereis python3 | grep -q "python3.." ; then \
\
    if yum info python38-devel > /dev/null 2>&1; then \
        /tmp/yum_install.sh python38 python38-devel python38-pip python38-setuptools python38-wheel; \
    else \
        if yum info python3-devel > /dev/null 2>&1; then \
            PYTHON3_DEVEL="python3-devel"; \
        else \
            PYTHON3_DEVEL="python3[0-9]-devel"; \
        fi; \
        /tmp/yum_install.sh python3 python3-pip ${PYTHON3_DEVEL} python3-setuptools python3-wheel; \
    fi; \
\
    ln -s /usr/bin/python3 /usr/local/bin/python3; \
    ln -s /usr/bin/pip3 /usr/local/bin/pip3; \
    for d in /usr/lib/python3*; do PYLIBDIR="$d"; echo 'PYLIBDIR: ' $PYLIBDIR; done; \
    ln -s $PYLIBDIR /usr/local/lib/`basename $PYLIBDIR`; \
    for d in /usr/include/python3*; do PYINCDIR="$d"; echo 'PYINCDIR: ' $PYINCDIR; done; \
    ln -s $PYINCDIR /usr/local/include/`basename $PYINCDIR`; \
\
else \
\
    /tmp/yum_install.sh \
        bzip2-devel \
        expat-devel \
        gdbm-devel \
        libdb4-devel \
        libffi-devel \
        ncurses-devel \
        openssl-devel \
        readline-devel \
        sqlite-devel \
        tk-devel \
        xz-devel \
        zlib-devel; \
    \
    cd /tmp; \
    /tmp/cached_wget.sh "https://www.python.org/ftp/python/3.8.3/Python-3.8.3.tar.xz"; \
    tar -xf Python*.xz; \
    /bin/rm Python*.xz; \
    cd /tmp/Python*; \
    ./configure \
        --enable-optimizations \
        --enable-shared \
        --prefix=/usr/local \
        --with-ensurepip=install \
        LDFLAGS="-Wl,-rpath /usr/local/lib"; \
    make -j`getconf _NPROCESSORS_ONLN` install; \
    \
    cd /tmp; \
    /bin/rm -r /tmp/Python*; \
\
fi \
\
&& cd /usr/local/include \
&& PYTHON_INC_DIR_NAME=`ls -d ./python*` \
&& ALT_PYTHON_INC_DIR_NAME=${PYTHON_INC_DIR_NAME%m} \
&& if [ "$ALT_PYTHON_INC_DIR_NAME" != "$PYTHON_INC_DIR_NAME" ]; then \
    ln -s "$PYTHON_INC_DIR_NAME" "$ALT_PYTHON_INC_DIR_NAME"; \
fi \
\
&& /usr/local/bin/pip3 -v install --upgrade \
    pip \
    setuptools \
\
&& if python --version > /dev/null 2>&1; then \
    whereis python; \
    python --version; \
else \
    cd /usr/bin; \
    ln -s python3 python; \
    cd /usr/local/bin; \
    ln -s python3 python; \
fi \
\
&& whereis python3 \
&& python3 --version \
&& pip3 --version \
&& /bin/ls -RFCa /usr/local/include/python*



# Install CMake v3.17.2

RUN set -vx \
\
&& cd /tmp \
&& /tmp/cached_wget.sh "https://cmake.org/files/v3.17/cmake-3.17.2.tar.gz" \
&& tar -xf cmake*.gz \
&& /bin/rm cmake*.gz \
&& cd /tmp/cmake* \
&& ./bootstrap \
&& make -j`getconf _NPROCESSORS_ONLN` install \
&& cd /tmp \
&& /bin/rm -rf /tmp/cmake* \
&& cmake --version




RUN date; df -h

# Install CUDA 10.2 

RUN set -vx \
\
&& echo -e '\
exec > /etc/yum.repos.d/cuda.repo \n\
echo [cuda] \n\
echo name=cuda \n\
if [ "`/bin/arch`" = "aarch64" ]; then \n\
echo baseurl="file:///var/cuda-repo" \n\
elif [ -f /etc/fedora-release ]; then \n\
echo baseurl="http://developer.download.nvidia.com/compute/cuda/repos/fedora29/`/bin/arch`" \n\
else \n\
OS_MAJ_VER=`(. /etc/os-release; echo ${VERSION_ID:0:1})` \n\
echo baseurl="http://developer.download.nvidia.com/compute/cuda/repos/rhel${OS_MAJ_VER}/`/bin/arch`" \n\
fi \n\
echo enabled=1 \n\
echo gpgcheck=0 \n' \
>> /tmp/Make_CUDA_Repo.sh \
&& sh /tmp/Make_CUDA_Repo.sh \
\
&& /tmp/yum_install.sh cuda-10-2

ENV \
CUDA_VERSION="10.2" \
CUDA_HOME="/usr/local/cuda" \
CUDA_PATH="/usr/local/cuda" \
PATH="/usr/local/cuda/bin:/usr/local/bin:/usr/bin:${PATH:+:${PATH}}" \
LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"


# Install old GCC v8.3 if necessary

RUN set -vx \
\
&& GCC_VERSION_OUTPUT=`gcc --version` \
&& if [ "${GCC_VERSION_OUTPUT:10:1}" -gt 8 ]; then \
\
    mkdir -p /tmp/gcc_tmp_build_dir; \
    cd /tmp/gcc_tmp_build_dir; \
\
    /tmp/cached_wget.sh -q "https://ftp.gnu.org/gnu/gcc/gcc-8.3.0/gcc-8.3.0.tar.xz"; \
    /tmp/cached_wget.sh -q "https://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.1.0.tar.bz2"; \
    /tmp/cached_wget.sh -q "https://gcc.gnu.org/pub/gcc/infrastructure/mpfr-3.1.4.tar.bz2"; \
    /tmp/cached_wget.sh -q "https://gcc.gnu.org/pub/gcc/infrastructure/mpc-1.0.3.tar.gz"; \
    /tmp/cached_wget.sh -q "https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2"; \
\
    tar -xf gcc-8.3.0.tar.xz; \
    tar -xf gmp-6.1.0.tar.bz2; \
    tar -xf mpfr-3.1.4.tar.bz2; \
    tar -xf mpc-1.0.3.tar.gz; \
    tar -xf isl-0.18.tar.bz2; \
\
    ln -s /tmp/gcc_tmp_build_dir/gmp-6.1.0 gcc-8.3.0/gmp; \
    ln -s /tmp/gcc_tmp_build_dir/mpfr-3.1.4 gcc-8.3.0/mpfr; \
    ln -s /tmp/gcc_tmp_build_dir/mpc-1.0.3 gcc-8.3.0/mpc; \
    ln -s /tmp/gcc_tmp_build_dir/isl-0.18 gcc-8.3.0/isl; \
\
    gcc-8.3.0/configure --disable-multilib --enable-languages=c,c++,fortran --prefix=/usr/local; \
    make -j`getconf _NPROCESSORS_ONLN`; \
    make install-strip; \
\
    cd /tmp; \
    /bin/rm -rf /tmp/gcc_tmp_build_dir; \
\
    ln -s /usr/local/bin/gcc /usr/local/cuda/bin/gcc; \
    ln -s /usr/local/bin/g++ /usr/local/cuda/bin/g++; \
    export CC="/usr/local/bin/gcc"; \
    export CXX="/usr/local/bin/g++"; \
\
    echo -e '\
    \n\
    export CC="/usr/local/bin/gcc" \n\
    export CXX="/usr/local/bin/g++" \n\
    \n' \
    >> ~/.bashrc; \
\
fi



# Install NVIDIA NCCL
# See: https://developer.nvidia.com/nccl

RUN set -vx \
\
&& cd /tmp \
&& git clone --depth 1 "https://github.com/NVIDIA/nccl.git" \
&& cd /tmp/nccl \
\
&& if grep install Makefile ; then \
    echo "Makefile already has install target"; \
else \
    echo "install: src.install" >> Makefile; \
fi \
\
&& make -j`getconf _NPROCESSORS_ONLN` src.build \
&& make -j`getconf _NPROCESSORS_ONLN` install \
\
&& cd /tmp \
&& /bin/rm -rf /tmp/nccl* \
\
&& ldconfig 



# Install NVIDIA cuDNN
# See: https://developer.nvidia.com/cudnn

RUN set -vx \
\
&& cd /tmp \
\
&& echo -e '\
set -vx \n\
if [ -d "/usr/local/cuda-10.2" ]; then \n\
    CUDNN_VER="v7.6.5/cudnn-10.2-linux-x64-v7.6.5.32.tgz" \n\
elif [ -d "/usr/local/cuda-10.1" ]; then \n\
    CUDNN_VER="v7.5.0/cudnn-10.1-linux-x64-v7.5.0.56.tgz" \n\
    CUDNN_VER="v7.6.5/cudnn-10.1-linux-x64-v7.6.5.32.tgz" \n\
elif [ -d "/usr/local/cuda-10.0" ]; then \n\
    CUDNN_VER="v7.5.0/cudnn-10.0-linux-x64-v7.5.0.56.tgz" \n\
    CUDNN_VER="v7.6.5/cudnn-10.0-linux-x64-v7.6.5.32.tgz" \n\
elif [ -d "/usr/local/cuda-9.2" ]; then \n\
    CUDNN_VER="v7.5.0/cudnn-9.2-linux-x64-v7.5.0.56.tgz" \n\
    CUDNN_VER="v7.6.5/cudnn-9.2-linux-x64-v7.6.5.32.tgz" \n\
elif [ -d "/usr/local/cuda-9.1" ]; then \n\
    CUDNN_VER="v7.1.3/cudnn-9.1-linux-x64-v7.1.tgz" \n\
elif [ -d "/usr/local/cuda-9.0" ]; then \n\
    CUDNN_VER="v7.5.0/cudnn-9.0-linux-x64-v7.5.0.56.tgz" \n\
    CUDNN_VER="v7.6.5/cudnn-9.0-linux-x64-v7.6.5.32.tgz" \n\
elif [ -d "/usr/local/cuda-8.0" ]; then \n\
    CUDNN_VER="v7.1.3/cudnn-8.0-linux-x64-v7.1.tgz" \n\
else \n\
    CUDNN_VER="idk_cudnn_version" \n\
fi \n\
echo "http://developer.download.nvidia.com/compute/redist/cudnn/$CUDNN_VER" \n' \
> /tmp/select_cudnn.sh \
\
&& if [ "`/bin/arch`" = "x86_64" ]; then \
\
/tmp/cached_wget.sh `sh /tmp/select_cudnn.sh` \
\
&& tar -xvf cudnn*.tgz \
&& cd /tmp/cuda \
\
&& mv include/cudnn.h /usr/local/cuda/include \
&& mv lib64/lib* /usr/local/cuda/lib64 \
\
&& cd /tmp \
&& /bin/rm -rf /tmp/cud* \
\
&& ldconfig; \
\
fi




RUN date; df -h

# Install Numpy

RUN set -vx \
\
&& /usr/local/bin/pip3 -v install \
    numpy \
\
&& /usr/local/bin/python3 -c 'import numpy'


RUN date; df -h

# Install TensorFlow-2

RUN set -vx \
\
&& if [ -d /usr/local/cuda ]; then \
    pip3 install tensorflow-gpu; \
else \
    pip3 install tensorflow; \
fi \
\
&& /usr/local/bin/python3 -c 'import tensorflow as tf; print(tf.__version__)'

EXPOSE 6006


RUN date; df -h

# Install Keras

RUN set -vx \
\
&& mkdir -p ~/.keras \
&& echo -e '\
{ \n\
    "image_data_format": "channels_last", \n\
    "epsilon": 1e-07, \n\
    "floatx": "float32", \n\
    "backend": "KERAS_BACKEND" \n\
} \n' \
> ~/.keras/keras.json \
\
&& if [ -f ~/.theanorc ]; then \
    sed -i 's/KERAS_BACKEND/theano/g' ~/.keras/keras.json; \
elif [ -f /tmp/select_cntk.sh ]; then \
    sed -i 's/KERAS_BACKEND/cntk/g' ~/.keras/keras.json; \
else \
    sed -i 's/KERAS_BACKEND/tensorflow/g' ~/.keras/keras.json; \
fi \
\
&& /usr/local/bin/pip3 -v install keras


RUN date; df -h

