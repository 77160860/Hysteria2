cat > hysteria_manager.sh <<'EOF'
#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'

LOG_FILE="/var/log/hysteria_manager.log"
SERVICE_NAME="hysteria-server.service"  
CONFIG_FILE="/etc/hysteria/config.json" # Hysteria 2 默认是 .json 配置文件
SHORTCUT_PATH="/usr/local/bin/hy"

# 检查是否以 root 用户运行
check_root() {
if [[ $EUID -ne 0 ]]; then
echo -e "${RED}此脚本必须以 root 用户运行${RESET}"
exit 1
fi
}

# 检查 Hysteria 是否安装
check_hysteria_installed() {
if command -v hysteria &> /dev/null; then
return 0
else
return 1
fi
}

# 检查 Hysteria 是否正在运行
check_hysteria_running() {
systemctl is-active --quiet "$SERVICE_NAME"
return $?
}

# 安装 Hysteria
install_hysteria() {
echo -e "${CYAN}正在安装 Hysteria...${RESET}"

# 下载安装脚本
curl -sS -o Hysteria2.sh https://raw.githubusercontent.com/77160860/Hysteria2/refs/heads/main/Hysteria2.sh
if [ $? -ne 0 ]; then
echo -e "${RED}下载安装脚本失败${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 下载安装脚本失败" >> "$LOG_FILE"
return 1
fi

chmod +x Hysteria2.sh
# 执行 Hysteria2 的安装脚本
./Hysteria2.sh

if [ $? -eq 0 ]; then
echo -e "${GREEN}Hysteria 安装成功${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Hysteria 安装成功" >> "$LOG_FILE"

# --- 已修正：创建快捷命令 ---
echo -e "${CYAN}正在创建快捷命令 'hy'...${RESET}"
# 使用确定的文件名 'hysteria_manager.sh' 代替不稳定的 '\$0'
if cp "hysteria_manager.sh" "$SHORTCUT_PATH"; then
chmod +x "$SHORTCUT_PATH"
echo -e "${GREEN}快捷命令 'hy' 创建成功！${RESET}"
echo -e "${YELLOW}现在您可以随时在终端输入 'hy' 来运行此管理面板。${RESET}"
else
echo -e "${RED}创建快捷命令失败。请检查 /usr/local/bin 目录是否存在或有写入权限。${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 创建快捷命令失败" >> "$LOG_FILE"
fi
# --- 修正结束 ---

else
echo -e "${RED}Hysteria 安装失败${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Hysteria 安装失败" >> "$LOG_FILE"
return 1
fi
}

# 卸载 Hysteria
uninstall_hysteria() {
echo -e "${CYAN}正在卸载 Hysteria...${RESET}"

# 执行卸载脚本
bash <(curl -fsSL https://get.hy2.sh/) --remove
if [ $? -ne 0 ]; then
echo -e "${RED}卸载脚本执行失败${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 卸载脚本执行失败" >> "$LOG_FILE"
fi

# 清除 iptables 规则
iptables -t nat -F && iptables -t nat -X
ip6tables -t nat -F && ip6tables -t nat -X

echo -e "${GREEN}Hysteria 卸载操作完成。${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Hysteria 卸载操作完成" >> "$LOG_FILE"

# --- 移除快捷命令 ---
if [ -f "$SHORTCUT_PATH" ]; then
echo -e "${CYAN}正在移除快捷命令 'hy'...${RESET}"
if rm -f "$SHORTCUT_PATH"; then
echo -e "${GREEN}快捷命令 'hy' 已成功移除。${RESET}"
else
echo -e "${RED}移除快捷命令 'hy' 失败。请手动删除: ${SHORTCUT_PATH}${RESET}"
fi
fi
# --- 代码结束 ---
}

# 启动 Hysteria
start_hysteria() {
echo -e "${CYAN}正在启动 Hysteria${RESET}"
systemctl start "$SERVICE_NAME"
if [ $? -eq 0 ]; then
echo -e "${GREEN}Hysteria 启动成功${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Hysteria 启动成功" >> "$LOG_FILE"
else
echo -e "${RED}Hysteria 启动失败${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Hysteria 启动失败" >> "$LOG_FILE"
fi
}

# 停止 Hysteria
stop_hysteria() {
echo -e "${CYAN}正在停止 Hysteria${RESET}"
systemctl stop "$SERVICE_NAME"
if [ $? -eq 0 ]; then
echo -e "${GREEN}Hysteria 停止成功${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Hysteria 停止成功" >> "$LOG_FILE"
else
echo -e "${RED}Hysteria 停止失败${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Hysteria 停止失败" >> "$LOG_FILE"
fi
}

# 查看 Hysteria 配置文件
view_hysteria_config() {
if [ -f "$CONFIG_FILE" ]; then
echo -e "${CYAN}Hysteria 配置文件内容:${RESET}"
cat "$CONFIG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 查看配置文件" >> "$LOG_FILE"
else
echo -e "${RED}未找到配置文件: $CONFIG_FILE${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 未找到配置文件: $CONFIG_FILE" >> "$LOG_FILE"
fi
}

# 显示菜单
show_menu() {
clear
check_hysteria_installed
hysteria_installed=$?

if [ $hysteria_installed -eq 0 ]; then
check_hysteria_running
hysteria_running=$?
if [ $hysteria_running -eq 0 ]; then
hysteria_status="${GREEN}已启动${RESET}"
else
hysteria_status="${RED}未启动${RESET}"
fi
installation_status="${GREEN}已安装${RESET}"
else
installation_status="${RED}未安装${RESET}"
hysteria_status="${RED}未启动${RESET}"
fi

echo -e "${GREEN}=== Hysteria 管理工具 ===${RESET}"
echo -e "安装状态: ${installation_status}"
if [ $hysteria_installed -eq 0 ]; then
echo -e "运行状态: ${hysteria_status}"
fi
echo ""
echo "1. 安装 Hysteria2 服务"
echo "2. 卸载 Hysteria2 服务"
echo "3. 启动 Hysteria2 服务"
echo "4. 停止 Hysteria2 服务"
echo "5. 查看 Hysteria2 配置"
echo "0. 退出"
echo -e "${GREEN}=========================${RESET}"
read -p "请输入选项编号: " choice
echo ""
}

# 捕获 Ctrl+C 信号
trap 'echo -e "\n${RED}已取消操作${RESET}"; exit' INT

# 主循环
main() {
check_root

while true; do
show_menu
case "$choice" in
1)
install_hysteria
;;
2)
check_hysteria_installed
if [ $? -eq 0 ]; then
uninstall_hysteria
else
echo -e "${RED}Hysteria 尚未安装${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 尝试卸载但 Hysteria 尚未安装" >> "$LOG_FILE"
fi
;;
3)
check_hysteria_installed
if [ $? -eq 0 ]; then
start_hysteria
else
echo -e "${RED}Hysteria 尚未安装${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 尝试启动但 Hysteria 尚未安装" >> "$LOG_FILE"
fi
;;
4)
check_hysteria_installed
if [ $? -eq 0 ]; then
stop_hysteria
else
echo -e "${RED}Hysteria 尚未安装${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 尝试停止但 Hysteria 尚未安装" >> "$LOG_FILE"
fi
;;
5)
view_hysteria_config
;;
0)
echo -e "${GREEN}已退出 Hysteria 管理工具${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 用户退出管理工具" >> "$LOG_FILE"
exit 0
;;
*)
echo -e "${RED}无效的选项${RESET}"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 用户输入无效选项" >> "$LOG_FILE"
;;
esac
read -p "按任意键返回菜单..."
done
}

# --- 脚本入口 ---
main "$@"
EOF

chmod +x hysteria_manager.sh && sudo ./hysteria_manager.sh
