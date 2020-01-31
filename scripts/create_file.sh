#!/bin/bash

XFS=/mnt/xfs-partition/
EXT4=/mnt/ext4-partition/
NTFS=/mnt/ntfs-partition/

for FILE in {0..9}
do
    dd if=/dev/urandom of="${EXT4}file-${FILE}.txt" bs=2097152 count=1
    dd if=/dev/urandom of="${XFS}file-${FILE}.txt" bs=2097152 count=1
    dd if=/dev/urandom of="${NTFS}file-${FILE}.txt" bs=2097152 count=1
done

ls -lah "${XFS}" "${EXT4}" "${NTFS}"
