---
title: Expanding LVM storage
date: 2022-07-22 08:16:13 +0000
categories: [Snippets, Storage]
tags: [lvm, disk, storage, expand]
---

Small snippet that will extend LVM storage.



1. Resize disk in proxmox/vmware

2. Extend physical volume 
```bash
pvresize /dev/sdb
```

3. Extend logical volume
```bash
lvextend -l +100%FREE /dev/VGNAME/LVNAME
```

4. Grow Filesystem
```bash
xfs_growfs /dev/VGNAME/LVNAME
```
