FROM php:8.3-apache

ARG CHAMILO_VERSION=3.0.1

# Installer for additional PHP extensions
COPY --from=mlocati/php-extension-installer:latest \
    /usr/bin/install-php-extensions \
    /usr/local/bin/install-php-extensions

# System libraries and PHP extensions required by Chamilo
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       unzip \
       libfreetype6-dev \
       libjpeg62-turbo-dev \
       libpng-dev \
       libicu-dev \
       libxml2-dev \
       libzip-dev \
       libldap2-dev \
       libonig-dev \
       libxslt1-dev \
       libcurl4-openssl-dev \
       libxapian-dev \
       xapian-tools \
       swig \
       pkg-config \
       libtool \
    && docker-php-ext-configure gd \
       --with-freetype \
       --with-jpeg \
    && docker-php-ext-configure ldap \
    && docker-php-ext-install -j"$(nproc)" \
       bcmath \
       curl \
       exif \
       gd \
       intl \
       ldap \
       mbstring \
       mysqli \
       pdo_mysql \
       soap \
       xsl \
       zip \
       opcache \
    && a2enmod rewrite headers expires \
    && rm -rf /var/lib/apt/lists/*

# Install APCu
RUN install-php-extensions apcu

RUN set -eux; \
    cd /tmp; \
    curl -fL \
      "https://deb.debian.org/debian/pool/main/x/xapian-bindings/xapian-bindings_1.4.29.orig.tar.xz" \
      -o xapian-bindings.tar.xz; \
    tar -xf xapian-bindings.tar.xz; \
    cd xapian-bindings-1.4.29; \
    PHP_CONFIG=/usr/local/bin/php-config \
      ./configure \
        --with-php \
        --without-csharp \
        --without-java \
        --without-lua \
        --without-perl \
        --without-python \
        --without-python3 \
        --without-ruby \
        --without-tcl; \
    make -j"$(nproc)"; \
    make install; \
    echo 'extension=xapian' \
      > /usr/local/etc/php/conf.d/zz-xapian.ini; \
    php --ri xapian; \
    cd /; \
    rm -rf /tmp/xapian-bindings-1.4.29 \
           /tmp/xapian-bindings.tar.xz

# PHP runtime settings
RUN printf '%s\n' \
       'date.timezone=Asia/Ho_Chi_Minh' \
       'memory_limit=512M' \
       'upload_max_filesize=100M' \
       'post_max_size=100M' \
       'max_execution_time=300' \
       'max_input_time=300' \
       'max_input_vars=5000' \
       'session.cookie_httponly=1' \
       > /usr/local/etc/php/conf.d/zz-chamilo.ini

WORKDIR /var/www/chamilo

# Download and install Chamilo
RUN curl -fL \
      "https://github.com/chamilo/chamilo-lms/releases/download/v${CHAMILO_VERSION}/chamilo-${CHAMILO_VERSION}.zip" \
      -o /tmp/chamilo.zip \
    && mkdir -p /tmp/chamilo-unpack \
    && unzip -q /tmp/chamilo.zip -d /tmp/chamilo-unpack \
    && if [ -f /tmp/chamilo-unpack/index.php ]; then \
         cp -a /tmp/chamilo-unpack/. /var/www/chamilo/; \
       else \
         cp -a /tmp/chamilo-unpack/*/. /var/www/chamilo/; \
       fi \
    && rm -rf /tmp/chamilo.zip /tmp/chamilo-unpack \
    && test -f /var/www/chamilo/public/main/install/apache.dist.conf \
    && touch /var/www/chamilo/.env \
    && mkdir -p /var/www/chamilo/var \
    && chown -R www-data:www-data /var/www/chamilo

COPY apache-vhost.conf /etc/apache2/sites-available/000-default.conf

EXPOSE 80