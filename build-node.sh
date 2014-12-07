#!/bin/bash

set -e
set -x

### IF we dont have archive url prefix
if [ -z "$_PARAMS_NODEJS_SOURCE_ARCHIVE_URL" ]; then
    _PARAMS_NODEJS_SOURCE_ARCHIVE_URL=$(wget -qO- http://nodejs.org/dist/latest/ | egrep -o 'node-v[0-9\.]+.tar.gz' | tail -1);
    _PARAMS_NODEJS_SOURCE_ARCHIVE_URL="http://nodejs.org/dist/latest/"$_PARAMS_NODEJS_SOURCE_ARCHIVE_URL
fi

if [ -z "$_PRAMS_RPI_TOOLS_SOURCE_ARCHIVE_URL" ]; then
    _PRAMS_RPI_TOOLS_SOURCE_ARCHIVE_URL="https://github.com/raspberrypi/tools/archive/master.tar.gz"
fi;

NODEJS_SOURCE_ARCHIVE_FILENAME=$(basename $_PARAMS_NODEJS_SOURCE_ARCHIVE_URL)
NODEJS_SOURCE_DIRECTORY=${NODEJS_SOURCE_ARCHIVE_FILENAME%.tar.gz}
#Download NodeJS
echo "-> Searching for NodeJS "$NODEJS_SOURCE_ARCHIVE_FILENAME;
if [ ! -e "$PWD/$NODEJS_SOURCE_ARCHIVE_FILENAME" ]; then
    echo "--> Downloading from "$_PARAMS_NODEJS_SOURCE_ARCHIVE_URL;
    wget --no-check-certificate -O $NODEJS_SOURCE_ARCHIVE_FILENAME $_PARAMS_NODEJS_SOURCE_ARCHIVE_URL
    echo "--> Download finished!"
fi;

echo "--> Extracting"
rm -rf $NODEJS_SOURCE_DIRECTORY
tar --overwrite -xf $NODEJS_SOURCE_ARCHIVE_FILENAME

echo "--> Linking"
ln -snf "$PWD/$NODEJS_SOURCE_DIRECTORY" "$PWD/node"
echo "-> Done!"


echo "-> Searching Raspberry Pi Toolset";
if [ ! -d "$PWD/rpi" ]; then

    if [ ! -e "$PWD/rpi-tools.tar.gz" ] || [ -s "$PWD/rpi-tools.tar.gz" ]; then
        echo "--> Downloading from "$_PRAMS_RPI_TOOLS_SOURCE_ARCHIVE_URL
        wget --no-check-certificate -O "rpi-tools.tar.gz" $_PRAMS_RPI_TOOLS_SOURCE_ARCHIVE_URL
        echo "--> Download finished"
    else
        echo "--> Found rpi-tools.tar.gz."
    fi

    echo "--> Extracting"
    tar xf "rpi-tools.tar.gz"
    echo "--> Linking tools-master to rpi"
    ln -snf "$PWD/tools-master" "$PWD/rpi"
else
    echo "-> found"
fi;
echo "-> Done!"

pushd "$PWD/node"

echo "--> Clean"
make clean

echo "--> Configure"
./configure --prefix=/ --without-snapshot --dest-cpu=arm --dest-os=linux

echo "--> Build"
VERSION=${NODEJS_SOURCE_DIRECTORY##node-}
export BINARYNAME=node-${VERSION}-linux-arm-pi
mkdir ${BINARYNAME}
make install DESTDIR=${BINARYNAME} V=1 PORTABLE=1

echo "--> Pack"
cp README.md ${BINARYNAME}
cp LICENSE ${BINARYNAME}
cp ChangeLog ${BINARYNAME}
tar -czf ${BINARYNAME}.tar.gz ${BINARYNAME}

echo "--> Cleanup"
popd
mv $PWD"/node/${BINARYNAME}.tar.gz" "./"
echo "-> Done!"