FROM debian:buster-slim
RUN useradd user

# prefer local python
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
ENV LANG C.UTF-8

# runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  netbase \
  && rm -rf /var/lib/apt/lists/*

ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
ENV PYTHON_VERSION 3.7.7

RUN set -ex \
  && savedAptMark="$(apt-mark showmanual)" \
  && apt-get update && apt-get install -y --no-install-recommends \
    dpkg-dev \
    gcc \
    libbluetooth-dev \
    libbz2-dev \
    libc6-dev \
    libexpat1-dev \
    libffi-dev \
    libgdbm-dev \
    liblzma-dev \
    libncursesw5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    make \
    tk-dev \
    uuid-dev \
    wget \
    xz-utils \
    zlib1g-dev \
# as of Stretch, "gpg" is no longer included by default
  $(command -v gpg > /dev/null || echo 'gnupg dirmngr') \
  && wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
  && wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
  && export GNUPGHOME="$(mktemp -d)" \
  && gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
  && gpg --batch --verify python.tar.xz.asc python.tar.xz \
  && { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
  && rm -rf "$GNUPGHOME" python.tar.xz.asc \
  && mkdir -p /usr/src/python \
  && tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
  && rm python.tar.xz \
  \
  && cd /usr/src/python \
  && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
  && ./configure \
    --build="$gnuArch" \
    --enable-loadable-sqlite-extensions \
    --enable-optimizations \
    --enable-option-checking=fatal \
    --enable-shared \
    --with-system-expat \
    --with-system-ffi \
    --without-ensurepip \
  && make -j "$(nproc)" \
# setting PROFILE_TASK makes "--enable-optimizations" reasonable: https://bugs.python.org/issue36044, https://github.com/docker-library/python/issues/160#issuecomment-509426916
    PROFILE_TASK='-m test.regrtest --pgo \
    test_array \
    test_base64 \
    test_binascii \
    test_binhex \
    test_binop \
    test_bytes \
    test_c_locale_coercion \
    test_class \
    test_cmath \
    test_codecs \
    test_compile \
    test_complex \
    test_csv \
    test_decimal \
    test_dict \
    test_float \
    test_fstring \
    test_hashlib \
    test_io \
    test_iter \
    test_json \
    test_long \
    test_math \
    test_memoryview \
    test_pickle \
    test_re \
    test_set \
    test_slice \
    test_struct \
    test_threading \
    test_time \
    test_traceback \
    test_unicode \
    ' \
  && make install \
  && ldconfig \
  && apt-mark auto '.*' > /dev/null \
  && apt-mark manual $savedAptMark \
  && find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
    | awk '/=>/ { print $(NF-1) }' \
    | sort -u \
    | xargs -r dpkg-query --search \
    | cut -d: -f1 \
    | sort -u \
    | xargs -r apt-mark manual \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/* \
  \
  && find /usr/local -depth \
    \( \
      \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
      -o \
      \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
    \) -exec rm -rf '{}' + \
  && rm -rf /usr/src/python \
  && python3 --version

# symlinks that are expected to exist
RUN cd /usr/local/bin \
  && ln -s idle3 idle \
  && ln -s pydoc3 pydoc \
  && ln -s python3 python \
  && ln -s python3-config python-config

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 20.0.2
# https://github.com/pypa/get-pip
ENV PYTHON_GET_PIP_URL https://github.com/pypa/get-pip/raw/d59197a3c169cef378a22428a3fa99d33e080a5d/get-pip.py
ENV PYTHON_GET_PIP_SHA256 421ac1d44c0cf9730a088e337867d974b91bdce4ea2636099275071878cc189e

RUN set -ex; \
  savedAptMark="$(apt-mark showmanual)"; \
  apt-get update; \
  apt-get install -y --no-install-recommends wget; \
  \
  wget -O get-pip.py "$PYTHON_GET_PIP_URL"; \
  echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum --check --strict -; \
  \
  apt-mark auto '.*' > /dev/null; \
  [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
  rm -rf /var/lib/apt/lists/*; \
  \
  python get-pip.py \
   --disable-pip-version-check \
   --no-cache-dir \
   "pip==$PYTHON_PIP_VERSION" \
  ; \
  pip --version; \
  \
  find /usr/local -depth \
    \( \
      \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
      -o \
      \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
    \) -exec rm -rf '{}' +; \
  rm -f get-pip.py

# nupack3.2.2 dependencies
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  ca-certificates \
  build-essential \
  cmake \
  cmake-data \
  && rm -rf /var/lib/apt/lists/*

# nupack-serve dependencies
RUN pip install aiofiles \
  pexpect \
  starlette \
  uvicorn \
  virtualenv

# nupack-serve
COPY nupack3.2.2 /tmp/nupack3.2.2
RUN mkdir -p /tmp/nupack3.2.2/build
WORKDIR /tmp/nupack3.2.2/build
RUN cmake ../ \
  && make \
  && make install
COPY ["app.py", "serve_mfe.py", "/srv/"]
WORKDIR /srv
USER user
CMD ["bash"]
