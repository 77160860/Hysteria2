#!/bin/bash

# 检查是否以 root 用户身份运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户身份运行此脚本"
  exit 1
fi

# 判断系统及定义系统安装依赖方式
DISTRO=$(cat /etc/os-release | grep '^ID=' | awk -F '=' '{print $2}' | tr -d '"')
case $DISTRO in
  "debian"|"ubuntu")
    PACKAGE_UPDATE="apt-get update"
    PACKAGE_INSTALL="apt-get install -y"
    PACKAGE_REMOVE="apt-get remove -y"
    PACKAGE_UNINSTALL="apt-get autoremove -y"
    ;;
  "centos"|"fedora"|"rhel")
    PACKAGE_UPDATE="yum -y update"
    PACKAGE_INSTALL="yum -y install"
    PACKAGE_REMOVE="yum -y remove"
    PACKAGE_UNINSTALL="yum -y autoremove"
    ;;
  *)
    echo "不支持的 Linux 发行版"
    exit 1
    ;;
esac

# 安装必要的软件包
${PACKAGE_INSTALL} unzip wget curl

# 一键安装Hysteria2
bash <(curl -fsSL https://get.hy2.sh/)

# 生成自签证书
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=bing.com" -days 36500 && sudo chown hysteria /etc/hysteria/server.key && sudo chown hysteria /etc/hysteria/server.crt

# 设定固定端口号
PORT=2096

# 生成随机密码
RANDOM_PSK=PGG2EYOvsFt2lAQTD7lqHeRxz2KxvllEDKcUrtizP

# 生成配置文件
cat << EOF > /etc/hysteria/config.yaml
listen: :${PORT}

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: "${RANDOM_PSK}" 
  
masquerade:
  type: proxy
  proxy:
    url: https://bing.com 
    rewriteHost: true
EOF

# 启动Hysteria2
systemctl start hysteria-server.service
systemctl restart hysteria-server.service

# 设置开机自启
systemctl enable hysteria-server.service

# 获取本机IP地址
HOST_IP=$(curl -s http://checkip.amazonaws.com)

# 获取IP所在国家
IP_COUNTRY=$(curl -s http://ipinfo.io/${HOST_IP}/country)

# 安装 iptables-persistent
${PACKAGE_INSTALL} iptables-persistent

# 端口跳跃设置：将20000-25000范围的UDP流量重定向到固定端口2096
iptables -t nat -A PREROUTING -p udp --dport 20000:25000 -j DNAT --to-destination :${PORT}
ip6tables -t nat -A PREROUTING -p udp --dport 20000:25000 -j DNAT --to-destination :${PORT}

# 保存 iptables 规则
netfilter-persistent save

# 生成客户端配置信息
cat << EOF > /etc/hysteria/config.txt
- name: ${IP_COUNTRY}
  type: hysteria2
  server: ${HOST_IP}
  port: ${PORT}
  password: ${RANDOM_PSK}
  alpn:
    - h3
  sni: www.bing.com
  skip-cert-verify: true
  fast-open: true

hy2://${RANDOM_PSK}@${HOST_IP}:${PORT}?insecure=1&sni=www.bing.com#${IP_COUNTRY}

${IP_COUNTRY} = hysteria2, ${HOST_IP}, ${PORT}, password = ${RANDOM_PSK}, skip-cert-verify=true, sni=www.bing.com, port-hopping=20000-25000, port-hopping-interval=30
EOF

# 输出客户端配置信息
echo "Hysteria2 安装成功"
cat << EOF
- name: ${IP_COUNTRY}
  type: hysteria2
  server: ${HOST_IP}
  port: ${PORT}
  password: ${RANDOM_PSK}
  alpn:
    - h3
  sni: www.bing.com
  skip-cert-verify: true
  fast-open: true
EOF
echo
echo "hy2://${RANDOM_PSK}@${HOST_IP}:${PORT}?insecure=1&sni=www.bing.com#${IP_COUNTRY}"
echo
echo "${IP_COUNTRY} = hysteria2, ${HOST_IP}, ${PORT}, password = ${RANDOM_PSK}, skip-cert-verify=true, sni=www.bing.com, port-hopping=20000-25000, port-hopping-interval=30"
