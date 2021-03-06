#!/bin/bash
echo "Building nginx ..."
# names of latest versions of each package
VERSION_PCRE=pcre-8.36
VERSION_OPENSSL=openssl-1.0.1j
VERSION_NGINX=nginx-1.7.8

# URLs to the source directories
SOURCE_OPENSSL=https://www.openssl.org/source/
SOURCE_PCRE=ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/
SOURCE_NGINX=http://nginx.org/download/

# clean out any files from previous runs of this script
rm -rf build
mkdir build

# ensure that we have the required software to compile our own nginx
sudo apt-get -y install curl wget build-essential

# grab the source files
wget -P ./build $SOURCE_PCRE$VERSION_PCRE.tar.gz
wget -P ./build $SOURCE_OPENSSL$VERSION_OPENSSL.tar.gz --no-check-certificate
wget -P ./build $SOURCE_NGINX$VERSION_NGINX.tar.gz

# expand the source files
cd build
tar xzf $VERSION_NGINX.tar.gz
tar xzf $VERSION_OPENSSL.tar.gz
tar xzf $VERSION_PCRE.tar.gz
cd ../

# set where OpenSSL and nginx will be built
BPATH=$(pwd)/build
STATICLIBSSL="/usr/local/staticlibssl"

# optional: make pcre, and install
#cd $BPATH/$VERSION_PCRE
#sudo apt-get -y install zip
#./configure --enable-pcre16 --enable-pcre32 --enable-jit --enable-utf --enable-unicode-properties && make
# should install to /usr/local
#sudo make install
#make distcheck
cp -rp $BPATH/$VERSION_PCRE /usr/local

# build static openssl
cd $BPATH/$VERSION_OPENSSL
rm -rf "$STATICLIBSSL"
mkdir "$STATICLIBSSL"
make clean
./config --prefix=$STATICLIBSSL no-shared \
&& make depend \
&& make \
&& make install_sw

# build nginx, with various modules included/excluded
cd $BPATH/$VERSION_NGINX
mkdir -p $BPATH/nginx
./configure --with-cc-opt="-I $STATICLIBSSL/include -I/usr/include" \
--with-ld-opt="-L $STATICLIBSSL/lib -Wl,-rpath -lssl -lcrypto -ldl -lz" \
--sbin-path=/usr/sbin/nginx \
--conf-path=/etc/nginx/nginx.conf \
--pid-path=/var/run/nginx.pid \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--with-pcre=/usr/local/$VERSION_PCRE \
--with-http_ssl_module \
--with-http_spdy_module \
--with-file-aio \
--with-ipv6 \
--with-http_gzip_static_module \
--with-http_stub_status_module \
--without-mail_pop3_module \
--without-mail_smtp_module \
--without-mail_imap_module \
&& make && make install

echo "All done building nginx.";
