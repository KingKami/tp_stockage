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

if [ "$HOSTNAME" = "machine1" ] || [ "$HOSTNAME" = "machine2" ] || [ "$HOSTNAME" = "machine3" ] ; \
then

    TARGET_CONF_PATH="/etc/tgt/conf.d/${HOSTNAME}-iscsi.conf"

    if [ -f /dev/sdb ] ; then
        sfdisk /dev/sdb < sfdisk-50mb.dump
    fi

    if [ -f /dev/sdc ] ; then
        sfdisk /dev/sdc < sfdisk-50mb.dump
    fi

    if [ -f /dev/sdd ] ; then
        sfdisk /dev/sdd < sfdisk-50mb.dump
    fi

    if [ -f /dev/sde ] ; then
        sfdisk /dev/sde < sfdisk-50mb.dump
    fi

    if [ "$HOSTNAME" = "machine1" ] ; then
        if grep -q ens33 "$NETWORK_CONF_FILE_PATH"; then
            sed -i "s#dhcp#static\n\
            \taddress ${IP_MACHINE[0]}\n\
            \tnetmask ${NETMASK}\n\
            \tgateway ${GATEWAY}#" \
            "$NETWORK_CONF_FILE_PATH"
        else
            echo -e "\nauto ens33\niface ens33 inet static\n\
            \taddress ${IP_MACHINE[0]}\n\
            \tnetmask ${NETMASK}\n\
            \tgateway ${GATEWAY}" >> "${NETWORK_CONF_FILE_PATH}"
        fi
    fi

    if [ "$HOSTNAME" = "machine2" ] ; then
        if grep -q ens33 "$NETWORK_CONF_FILE_PATH"; then
            sed -i "s#dhcp#static\n\
            \taddress ${IP_MACHINE[1]}\n\
            \tnetmask ${NETMASK}\n\
            \tgateway ${GATEWAY}#" \
            "$NETWORK_CONF_FILE_PATH"
        else
            echo -e "auto ens33\niface ens33 inet static\n\
            \taddress ${IP_MACHINE[1]}\n\
            \tnetmask ${NETMASK}\n\
            \tgateway ${GATEWAY}" >> "${NETWORK_CONF_FILE_PATH}"
        fi
    fi

    if [ "$HOSTNAME" = "machine3" ] ; then
        if grep -q ens33 "$NETWORK_CONF_FILE_PATH"; then
            sed -i "s#dhcp#static\n\
            \taddress ${IP_MACHINE[2]}\n\
            \tnetmask ${NETMASK}\n\
            \tgateway ${GATEWAY}#" \
            "$NETWORK_CONF_FILE_PATH"
        else
            echo -e "auto ens33\niface ens33 inet static\n\
            \taddress ${IP_MACHINE[2]}\n\
            \tnetmask ${NETMASK}\n\
            \tgateway ${GATEWAY}" >> "${NETWORK_CONF_FILE_PATH}"
        fi
    fi

    service networking restart
    mdadm --create /dev/md0 --level=10 --raid-devices=4 /dev/sd[b-e] --run
    pvcreate /dev/md0
    vgcreate "${HOSTNAME}-iscsi" /dev/md0
    lvcreate -l 100%FREE --name "${HOSTNAME}-lun" "${HOSTNAME}-iscsi"
    cat target.conf > "${TARGET_CONF_PATH}"
    sed -i "s#HOSTNAME#$HOSTNAME#g" "${TARGET_CONF_PATH}"
    service tgt restart
fi

if [ "$HOSTNAME" = "machine4" ] ; \
then
    VGNAME="karthike"
    XFS_SIZE=$(echo "200*100/350" |bc)
    EXT4_SIZE=$(echo "100*100/150" |bc)

    if [ -f /dev/sdb ] ; then
        sfdisk /dev/sdb < sfdisk-100mb.dump
    fi

    if [ -f /dev/sdc ] ; then
        sfdisk /dev/sdc < sfdisk-100mb.dump
    fi

    if grep -q ens33 "$NETWORK_CONF_FILE_PATH"; then
        sed -i "s#dhcp#static\n\
        \taddress ${IP_MACHINE[3]}\n\
        \tnetmask ${NETMASK}\n\
        \tgateway ${GATEWAY}#" \
        "$NETWORK_CONF_FILE_PATH"
    else
        echo -e "auto ens33\niface ens33 inet static\n\
        \taddress ${IP_MACHINE[3]}\n\
        \tnetmask ${NETMASK}\n\
        \tgateway ${GATEWAY}" >> "${NETWORK_CONF_FILE_PATH}"
    fi

    service networking restart

    mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sd[b-c] --run

    for MACHINE in {0..2}
    do
        INDEX=$(($MACHINE+1))
        IP="${IP_MACHINE[$MACHINE]}"
        NAME="machine${INDEX}"
        ISCSI_CONF_PATH="/etc/iscsi/nodes/iqn.2020-01.com.karthike:${NAME}-lun/${IP},3260,1/"

        iscsiadm -m discovery -t st -p "$IP"
        # mkdir -p "$ISCSI_CONF_PATH"
        cat default.conf > "${ISCSI_CONF_PATH}default"
        sed -i "s#TARGETNAME#$NAME#" "${ISCSI_CONF_PATH}default"
        sed -i "s#TARGET-IP#${IP}#" "${ISCSI_CONF_PATH}default"
    done
    service open-iscsi restart

    mdadm --create /dev/md1 --level=5 --raid-devices=3 /dev/sd[d-f] --run

    vgcreate "${VGNAME}" /dev/md0 /dev/md1

    lvcreate -n LV-XFS -L ${XFS_SIZE}‬%FREE "${VGNAME}"
    mkfs -t xfs LV-XFS

    lvcreate -n LV-EXT4 -L ${EXT4_SIZE}‬%FREE "${VGNAME}"
    mkfs -t ext4 LV-EXT4

    lvcreate -n LV-NTFS -L 100%FREE "${VGNAME}"
    mkfs -t ntfs LV-NTFS

    mkdir -p /mnt/xfs-partition /mnt/ext4-partition /mnt/ntfs-partition
    mount LV-XFS /mnt/xfs-partition
    mount LV-EXT4 /mnt/ext4-partition
    mount LV-NTFS /mnt/ntfs-partition

    mdadm --detail --scan --verbose >> /etc/mdadm/mdadm.conf
    update-initramfs -u
fi
