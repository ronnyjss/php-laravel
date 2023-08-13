FROM debian:12-slim

ENV DEBIAN_FRONTEND noninteractive
ENV APACHE_VERSION='2.4.57'
ENV CURL_VERSION='8.2.1'
ENV OPENSSL_VERSION='3.0.10'
ENV OPENSSH_VERSION='9.4p1'
ENV PHP_VERSION='8.2.8'
ENV WKHTMLTOPDF_VERSION='0.12.6.1-3'

COPY ./start.sh /scripts/start.sh

RUN chmod +x /scripts/start.sh && \
    apt update && \
    apt install -y --no-install-recommends \
        apt-utils \
        ca-certificates \
        libaio1 && \
    buildDeps=" \
        autoconf \
        automake \
        build-essential \
        libapr1-dev \
        libaprutil1-dev \
        libonig-dev \
        libpng-dev \
        libxml2-dev \
        libpcre3-dev \
        libtool-bin \
        libzip-dev \
        pkg-config \
        wget \
    " && \
    set -x && \
    apt-get install -y --no-install-recommends $buildDeps && \

    # Wkhtmltopdf
    wget -P /tmp https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}.bookworm_amd64.deb && \
    apt install -y --no-install-recommends -f /tmp/wkhtmltox_${WKHTMLTOPDF_VERSION}.bookworm_amd64.deb && \

    # OpenSSL
    wget -P /tmp https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar xf /tmp/openssl-${OPENSSL_VERSION}.tar.gz -C /tmp  &&\
    cd /tmp/openssl-${OPENSSL_VERSION} && \
    ./config shared && \
    make -j$(nproc) && \
    make install_sw && \

    # OpenSSH
    wget -P /tmp https://openbsd.c3sl.ufpr.br/pub/OpenBSD/OpenSSH/portable/openssh-${OPENSSH_VERSION}.tar.gz && \
    tar xf /tmp/openssh-${OPENSSH_VERSION}.tar.gz -C /tmp && \
    cd /tmp/openssh-${OPENSSH_VERSION} && \
    ./configure && \
    make -j$(nproc) && \
    make install && \

    # Curl
    wget -P /tmp https://curl.se/download/curl-${CURL_VERSION}.tar.gz && \
    tar xf /tmp/curl-${CURL_VERSION}.tar.gz -C /tmp && \
    cd /tmp/curl-${CURL_VERSION} && \
    ./configure --with-openssl && \
    make -j$(nproc) && \
    make install && \

    # Apache
    mkdir -p /var/www/html && \
    wget -P /tmp http://archive.apache.org/dist/httpd/httpd-${APACHE_VERSION}.tar.gz && \
    tar xf /tmp/httpd-${APACHE_VERSION}.tar.gz -C /tmp && \
    cd /tmp/httpd-${APACHE_VERSION} && \
    ./configure \
        --enable-rewrite \
        --enable-so \
        --with-mpm=prefork && \
    make -j$(nproc) && \
    make install && \

    # PHP
    wget -P /tmp https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz && \
    tar xf /tmp/php-${PHP_VERSION}.tar.gz -C /tmp && \
    ln -s /usr/include/x86_64-linux-gnu/curl /usr/include/curl && \
    mkdir -p /usr/local/etc/php/conf.d && \
    cd /tmp/php-${PHP_VERSION} && \
    export OPENSSL_LIBS="-L/usr -lssl -lcrypto -lz" && export OPENSSL_CFLAGS="-I/usr/include" && \
    ./configure \
        --enable-bcmath \
        --enable-intl \
        --enable-mbstring \
        --without-sqlite3 \
        --without-pdo-sqlite \
        --with-openssl \
        --with-curl \
        --with-gd \
        --with-zip \
        --with-zlib \
        --with-apxs2=/usr/local/apache2/bin/apxs \
        --with-config-file-path=/usr/local/etc/php \
		--with-config-file-scan-dir=/usr/local/etc/php/conf.d \
        --enable-ftp \
        --enable-zip && \
    make -j$(nproc) && \
    make install && \

    # PHP Extensions
    wget -P /tmp http://pear.php.net/go-pear.phar && \
    php /tmp/go-pear.phar && \
    pecl channel-update pecl.php.net && \
    pecl install oci8-3.3.0 && \
    echo 'extension=oci8.so' >> /usr/local/etc/php/conf.d/oci8.ini && \
    pecl install xdebug && \
    echo ';zend_extension=xdebug.so' >> /usr/local/etc/php/conf.d/xdebug.ini && \

    # Pacotes que devem permanecer na imagem
    apt-mark hold libapr1 libaprutil1 libldap-2.5-0 libonig5 libpcre3 libpng16-16 libxml2 libzip4 && \

    # Limpeza
    apt purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $buildDeps && \
    apt clean && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/* && \

    # Corrigindo permissões
    addgroup -gid 1000 --system laravel && \
    adduser --system --disabled-password --gid 1000 -u 1000 laravel

COPY ./conf/apache/httpd.conf /usr/local/apache2/conf/httpd.conf
COPY ./conf/apache/httpd-vhosts.conf /usr/local/apache2/conf/extra/httpd-vhosts.conf
COPY ./conf/php/php.ini /usr/local/etc/php/php.ini

ENTRYPOINT ["/scripts/start.sh"]
EXPOSE 80
CMD ["/usr/local/apache2/bin/httpd", "-DFOREGROUND"]
