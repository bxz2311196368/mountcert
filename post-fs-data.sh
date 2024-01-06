#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk changes its mount point in the future
MODDIR=${0%/*}

# 创建目录（如果不存在）
mkdir -p /data/cache/cacert

# 设置默认的SELinux上下文
default_selinux_context=u:object_r:system_file:s0

# 获取当前 /system/etc/security/cacerts 目录的SELinux上下文
selinux_context=$(find /system/etc/security/cacerts -maxdepth 0 -exec stat -c %C {} \;)

# 挂载 10M 的 tmpfs 到 /data/cache/cacert
mount -t tmpfs -o size=10M tmpfs /data/cache/cacert

# 复制 /system/etc/security/cacerts/ 下的所有文件到临时目录 /data/cache/cacert
cp -f /system/etc/security/cacerts/* /data/cache/cacert

# 挂载 10M 的 tmpfs 到 /system/etc/security/cacerts
mount -t tmpfs -o size=10M tmpfs /system/etc/security/cacerts

# 将之前复制的文件移回挂载的目录 /system/etc/security/cacerts/
mv -f /data/cache/cacert/* /system/etc/security/cacerts/

# 复制用户添加的证书到 /system/etc/security/cacerts/
cp -f /data/misc/user/0/cacerts-added/* /system/etc/security/cacerts/

# 安卓14+
# 如果存在apex下的证书目录，复制到/system/etc/security/cacerts/
if [ -d /apex/com.android.conscrypt/cacerts ]; then
    cp -f /apex/com.android.conscrypt/cacerts/* /system/etc/security/cacerts/
fi

# 更改权限和所有者
chown root:root /system/etc/security/cacerts/*
chmod 644 /system/etc/security/cacerts/*

# 如果SELinux处于Enforcing模式，调整文件上下文
if [ "$(getenforce)" = "Enforcing" ]; then
    if [ -n "$selinux_context" ] && [ "$selinux_context" != "?" ]; then
        chcon -R "$selinux_context" /system/etc/security/cacerts
    else
        chcon -R "$default_selinux_context" /system/etc/security/cacerts
    fi
fi

# 安卓14+
# 如果存在apex下的证书目录，使用bind挂载
if [ -d /apex/com.android.conscrypt/cacerts ]; then
    mount -o bind /system/etc/security/cacerts /apex/com.android.conscrypt/cacerts
fi

# 卸载使用完毕的临时目录 /data/cache/cacert 的 tmpfs
umount /data/cache/cacert

# This script will be executed in post-fs-data mode
# More info in the main Magisk thread
