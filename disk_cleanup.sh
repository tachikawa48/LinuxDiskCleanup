#!/bin/bash
set -euo pipefail

# 检查是否以root权限运行
if [[ $EUID -ne 0 ]]; then
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 获取清理前磁盘空间
before=$(df -h / | awk 'NR==2 {print $4}')

# 清理APT缓存
echo "正在清理APT缓存..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean -y

# 清理旧内核（保留当前版本）
echo "正在清理旧内核..."
current_kernel=$(uname -r | sed 's/-*[a-z]//g' | sed 's/-386//g')
kernel_pkgs=$(dpkg --list | grep linux-image | awk '{print $2}')
for pkg in $kernel_pkgs; do
    if [[ $pkg == *"$current_kernel"* ]]; then
        echo "保留当前内核: $pkg"
    else
        apt-get purge -y $pkg
    fi
done

# 清理系统日志
echo "正在清理系统日志..."
journalctl --vacuum-time=7d
find /var/log -type f -name "*.gz" -delete
find /var/log -type f -name "*.old" -delete
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;

# 清理临时文件
echo "正在清理临时文件..."
rm -rf /tmp/*
rm -rf /var/tmp/*

# 清理残留配置文件
echo "正在清理残留配置..."
dpkg -l | grep '^rc' | awk '{print $2}' | xargs apt-get purge -y

# 可选：清理用户缓存（按需取消注释）
# echo "正在清理用户缓存..."
# find /home -type d -name '.cache' -exec rm -rf {} \;

# 可选：清理Docker资源（按需取消注释）
echo "正在清理Docker资源..."
docker system prune -af

# 显示清理结果
echo -e "\n清理完成！"
echo "========================"
echo "清理前可用空间: $before"
after=$(df -h / | awk 'NR==2 {print $4}')
echo "清理后可用空间: $after"
echo "========================"
