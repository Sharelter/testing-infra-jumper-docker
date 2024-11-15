#!/bin/bash

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please run it as root user."
    exit 1
fi

# 检查是否安装 curl 和 jq 工具
if ! command -v curl &> /dev/null; then
    echo "curl is required but not installed. Please install it using: apt-get install curl"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Please install it using: apt-get install jq"
    exit 1
fi

# 定义 JSON 文件的 URL
URL="https://raw.githubusercontent.com/KevinMX/testing-infra/main/user_map.json"
JSON_FILE="/tmp/user_map.json"

# 下载 JSON 文件
echo "Downloading user map JSON..."
curl -s "$URL" -o "$JSON_FILE"
if [ $? -ne 0 ]; then
    echo "Failed to download JSON file. Please check the URL or your network connection."
    exit 1
fi

# 遍历 userMap 中的所有用户
for USERNAME in $(jq -r '.userMap | keys[]' "$JSON_FILE"); do
    GITHUB_USERNAME=$(jq -r ".userMap[\"$USERNAME\"][0]" "$JSON_FILE")

    echo "Processing user: $USERNAME (GitHub: $GITHUB_USERNAME)"

    # 获取 GitHub 用户的 SSH 公钥列表
    KEYS_URL="https://github.com/${GITHUB_USERNAME}.keys"
    SSH_KEYS=$(curl -s "$KEYS_URL")

    if [ -z "$SSH_KEYS" ]; then
        echo "No SSH keys found for GitHub user $GITHUB_USERNAME. Skipping..."
        continue
    fi

    # 检查用户是否存在
    if id "$USERNAME" &>/dev/null; then
        echo "User $USERNAME already exists. Checking for SSH keys..."
    else
        # 创建用户
        useradd -G sudo -m -s /bin/bash "$USERNAME"
        echo "User $USERNAME created."
    fi

    # 创建 .ssh 目录和 authorized_keys 文件（如果不存在）
    SSH_DIR="/home/$USERNAME/.ssh"
    AUTH_KEYS_FILE="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    touch "$AUTH_KEYS_FILE"
    chmod 700 "$SSH_DIR"
    chmod 600 "$AUTH_KEYS_FILE"
    chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

    # 避免重复添加：检查每个公钥是否已经存在
    while IFS= read -r KEY; do
        if ! grep -qF "$KEY" "$AUTH_KEYS_FILE"; then
            echo "Adding new SSH key for $USERNAME."
            echo "$KEY" >> "$AUTH_KEYS_FILE"
        else
            echo "SSH key for $GITHUB_USERNAME already exists. Skipping..."
        fi
    done <<< "$SSH_KEYS"

    # 确保文件权限正确
    chmod 600 "$AUTH_KEYS_FILE"
    chown "$USERNAME:$USERNAME" "$AUTH_KEYS_FILE"
done

echo "All users processed."
