#!/bin/bash
####################################################################################################
#Author: Karthike                                                                                  #
#Email: karthikeezhilarasan@gmail.com                                                              #
#Version: 1                                                                                        #
####################################################################################################


NETWORK_CONF_FILE_PATH="/etc/network/interfaces"
IP_MACHINE=("172.180.1.141" "172.180.1.142" "172.180.1.143" "172.180.1.144")
NETMASK="255.255.255.0"
GATEWAY="172.180.1.2"

apt-get -qq install tgt lvm2 xfsprogs ntfs-3g mdadm open-iscsi

if [ -f /dev/sdb ] ; then
    sfdisk /dev/sdb < sfdisk-100mb.dump
fi

if [ -f /dev/sdc ] ; then
    sfdisk /dev/sdc < sfdisk-100mb.dump
fi

if [ -f /dev/sdd ] ; then
    sfdisk /dev/sdd < sfdisk-100mb.dump
fi

if [ -f /dev/sde ] ; then
    sfdisk /dev/sde < sfdisk-100mb.dump
fi

if [ "$HOSTNAME" = "machine1" ] || [ "$HOSTNAME" = "machine2" ] || [ "$HOSTNAME" = "machine3" ] ; \
then

    TARGET_CONF_PATH="/etc/tgt/conf.d/${HOSTNAME}-iscsi.conf"

    mdadm --create /dev/md0 --level=10 --raid-devices=4 /dev/sd[b-e] --run
    pvcreate /dev/md0
    vgcreate "${HOSTNAME}-iscsi" /dev/md0
    lvcreate -l 100%FREE --name "${HOSTNAME}lun" "${HOSTNAME}iscsi"
    cat target.conf > "${TARGET_CONF_PATH}"
    sed -i "s#HOSTNAME#$HOSTNAME#g" "${TARGET_CONF_PATH}"
    service tgt restart
fi

if [ "$HOSTNAME" = "machine4" ] ; \
then
    VGNAME="karthike"
    XFS_SIZE=200
    EXT4_SIZE=100
    NTFS_SIZE=50

    mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sd[b-c] --run

    for MACHINE in {0..2}
    do
        INDEX=$(($MACHINE+1))
        IP="${IP_MACHINE[$MACHINE]}"
        NAME="machine${INDEX}"
        ISCSI_CONF_PATH="/etc/iscsi/nodes/iqn.2020-01.com.karthike:${NAME}-lun/${IP},3260,1/"

        iscsiadm -m discovery -t st -p "$IP"

        sed -i "s#node.session.auth.authmethod = None#node.session.auth.authmethod = CHAP#" "${ISCSI_CONF_PATH}default"
        sed -i "s#manual#automatic#g" "${ISCSI_CONF_PATH}default"
        sed -i "s/# END RECORD/node.session.auth.username = machine4/" "${ISCSI_CONF_PATH}default"
        echo -e "node.session.auth.password = password\nnode.session.auth.username_in = ${NAME}\nnode.session.auth.password_in = secretpass\n# END RECORD" >> "${ISCSI_CONF_PATH}default"
        service open-iscsi restart
    done

    mdadm --create /dev/md1 --level=5 --raid-devices=3 /dev/sd[d-f] --run

    vgcreate "${VGNAME}" /dev/md0 /dev/md1

    lvcreate -n LV-XFS -L "${XFS_SIZE}" "${VGNAME}"
    mkfs -t xfs LV-XFS

    lvcreate -n LV-EXT4 -L "${EXT4_SIZE}" "${VGNAME}"
    mkfs -t ext4 LV-EXT4

    lvcreate -n LV-NTFS -L "${NTFS_SIZE}" "${VGNAME}"
    mkfs -t ntfs LV-NTFS

    mkdir -p /mnt/xfs-partition /mnt/ext4-partition /mnt/ntfs-partition
    mount LV-XFS /mnt/xfs-partition
    mount LV-EXT4 /mnt/ext4-partition
    mount LV-NTFS /mnt/ntfs-partition

    mdadm --detail --scan --verbose >> /etc/mdadm/mdadm.conf
    update-initramfs -u
fi
