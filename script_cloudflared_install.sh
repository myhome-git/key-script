#!/bin/sh
# 从环境变量中获取 Cloudflare 令牌
CFD_TOKEN=${CLOUDFLARE_TOKEN}

# 定义 Cloudflared 版本
VERSION="2023.3.1"

# 定义 Cloudflared 下载链接
DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/download/${VERSION}/cloudflared-linux-amd64"

# 定义 Cloudflared 安装路径
INSTALL_PATH="/usr/bin/cloudflared"

# 定义 Cloudflared 启动脚本路径
INIT_SCRIPT="/etc/init.d/cloudflared"

# 确保脚本在发生错误时立即退出
set -e

# 下载 Cloudflared
download_cloudflared() {
  echo "Downloading Cloudflared..."
  curl -O -L ${DOWNLOAD_URL}
  if [ $? -ne 0 ]; then
    echo "Error downloading Cloudflared."
    exit 1
  fi
}

# 安装 Cloudflared
install_cloudflared() {
  echo "Installing Cloudflared..."
  chmod +x cloudflared-linux-amd64
  mv cloudflared-linux-amd64 ${INSTALL_PATH}
  if [ $? -ne 0 ]; then
    echo "Error installing Cloudflared."
    exit 1
  fi
}

# 创建启动脚本
create_init_script() {
  echo "Creating init script..."
  cat <<EOF > ${INIT_SCRIPT}
#!/bin/sh /etc/rc.common
USE_PROCD=1
START=95
STOP=01

boot() {
  ubus -t 30 wait_for network.interface network.loopback 2>/dev/null
  rc_procd start_service
}

start_service() {
  procd_open_instance
  procd_set_param command ${INSTALL_PATH} --no-autoupdate tunnel run --token "\${CFD_TOKEN}"
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_set_param respawn 3600 5 5
  procd_close_instance
}

stop_service() {
  pidof cloudflared && kill -SIGINT \`pidof cloudflared\`
}
EOF

  chmod +x ${INIT_SCRIPT}

  if [ $? -ne 0 ]; then
    echo "Error creating init script."
    exit 1
  fi
}

# 启动 Cloudflared
start_cloudflared() {
  echo "Starting Cloudflared..."
  /etc/init.d/cloudflared enable
  /etc/init.d/cloudflared start
  if [ $? -ne 0 ]; then
    echo "Error starting Cloudflared."
    exit 1
  fi
}

# 检查 Cloudflared 状态
check_cloudflared_status() {
  echo "Checking Cloudflared status..."
  ps | grep cloudflared
}

# ------------------------------------------------------------------
# 主流程
# ------------------------------------------------------------------

# 1. 更新软件包列表
echo "Updating package list..."
opkg update

# 2. 下载 Cloudflared
download_cloudflared

# 3. 安装 Cloudflared
install_cloudflared

# 4. 创建启动脚本
create_init_script

# 5. 启动 Cloudflared
start_cloudflared

# 6. 检查 Cloudflared 状态
check_cloudflared_status

echo "Cloudflared installation and configuration completed."
