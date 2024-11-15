# 使用 debian bookworm 作为基础镜像
FROM debian:latest

# 更新包列表并安装所需的软件包
RUN apt-get update && apt-get install -y \
    htop \
    vim \
    curl \
    jq \
    wget \
    openssh-server \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# 复制并执行 create_user.sh 脚本
COPY scripts/create_user.sh /root/create_user.sh
RUN chmod +x /root/create_user.sh && /root/create_user.sh

WORKDIR /root

CMD /bin/bash