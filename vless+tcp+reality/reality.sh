#!/bin/bash
set -e

echo "============================================"
echo "      Xray VLESS TCP Reality 一键部署"
echo "============================================"

# 部署目录
XRAY_DIR="/etc/xray"
mkdir -p $XRAY_DIR
cd $XRAY_DIR

# ========== 下载 Xray ==========
get_xray() {
  if [[ ! -x "$VLESS_BIN" ]]; then
    echo "Downloading Xray v1.8.23..."
    curl -L -o xray.zip "https://github.com/XTLS/Xray-core/releases/download/v1.8.23/Xray-linux-64.zip" --fail --connect-timeout 15
    unzip -j xray.zip xray -d . >/dev/null 2>&1
    rm -f xray.zip
    chmod +x "$VLESS_BIN"
  fi
}

# 生成 UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

# Reality 默认端口
PORT=443

# 生成 Reality 密钥
echo "生成 Reality 私钥/公钥 ..."
KEY_OUTPUT=$(./xray x25519)
PRIVATE_KEY=$(echo "$KEY_OUTPUT" | grep Private | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEY_OUTPUT" | grep Public | awk '{print $3}')

# 设置回落 website
FALLBACK_DOMAIN="www.microsoft.com"

# Reality 配置文件
cat > config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$FALLBACK_DOMAIN:443",
          "xver": 0,
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["6a96"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# 创建 systemd 服务
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
Type=simple
ExecStart=$XRAY_DIR/xray run -config $XRAY_DIR/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray
systemctl restart xray

echo
echo "================ 部署完成 ================"
echo "Reality 公钥：$PUBLIC_KEY"
echo "Reality 私钥：$PRIVATE_KEY"
echo
echo "VLESS Reality 节点如下："
echo
echo "vless://$UUID@$(hostname -I | awk '{print $1}'):$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&pbk=$PUBLIC_KEY&fp=chrome&sid=6a96&sni=$FALLBACK_DOMAIN&type=tcp#Reality"
echo
echo "=========================================="
echo "节点已生成，可直接导入客户端使用"
