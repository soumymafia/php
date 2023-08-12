#!/bin/bash

ipv4="-o Acquire::ForceIPv4=true"

if [ "$1" = "4" ] ; then
    withip=$ipv4
    echo "Going IPv4 ($withip)"
fi

echo "Autoremove+Purge."
apt-get $withip -y -f autoremove --purge >/dev/null 2>&1

if [ "$?" != "0" ] ; then
    echo "Auto Removal Failed!"
fi

echo "Old dependency fix."
apt-get $withip -f -y install >/dev/null 2>&1

if [ "$?" != "0" ] ; then
    echo "That failed. So we'll try to make up to it during this process."
fi

echo "Now, going old kernel cleanup!"
kern=$(dpkg --list 'linux-image*'|awk '{ if ($1=="ii") print $2}'|grep -v `uname -r`)
hadErrors=0

for k in $kern
do
    echo apt-get -y purge $k
    apt-get $withip -y purge $k >/dev/null 2>&1

    if [ "$?" != "0" ] ; then
        echo "Failed apt-purge... Using plan B (--force-all -P)..."
        dpkg --force-all -P $k >/dev/null 2>&1
        echo "Rerunning stuff (apt-get -f -y install) for dependencies..."
        apt-get $withip -f -y install >/dev/null 2>&1
        if [ "$?" != "0" ] ; then
            echo "Still failing..."
            hadErrors=1
        fi
    fi
done

if [ "$hadErrors" = "1" ] ; then
    echo "I had errors. I should rerun this process, to see if there are more kernels that were left out after cleanup..."
    /usr/local/tornevall/cleankernel
fi

apt-get $withip autoremove
apt-get $withip update
apt-get $withip upgrade
apt-get $withip dist-upgrade

grb=$(which update-grub)
if [ "" != "$grb" ] ; then
    update-grub
else
    echo "Can't upgrade grub since update-grub is missing..."
fi
