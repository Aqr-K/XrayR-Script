#!/bin/bash

################################################################################
#
#  迁移工具 (migrate.sh)
#
#  功能: 将已安装的 Xrayr 迁移到新位置、新名称、新进程名
#  用处: 支持离线迁移二进制文件，更新 service 配置，更新进程名等
#
#  使用示例:
#    ./xray-migrate.sh \
#      --to-bin-name new-service \
#      --to-process-name new-worker \
#      --to-install-path /opt/newapp \
#      --to-config-path /etc/newconfig
#
################################################################################

#=================================================
#              颜色和日志定义
#=================================================
Green="\033[32m"
Red="\033[31m"
Yellow='\033[33m'
Blue='\033[34m'
Font="\033[0m"

INFO_PREFIX="[${Green}INFO${Font}]"
ERROR_PREFIX="[${Red}ERROR${Font}]"
WARN_PREFIX="[${Yellow}WARN${Font}]"

function INFO() {
    echo -e "${INFO_PREFIX} ${1}" >&2
}
function ERROR() {
    echo -e "${ERROR_PREFIX} ${1}" >&2
}
function WARN() {
    echo -e "${WARN_PREFIX} ${1}" >&2
}

#=================================================
#              全局变量
#=================================================

# 源配置（从 .install_config 读取）
OLD_BIN_NAME=""
OLD_BIN_DIR=""
OLD_CONFIG_PATH=""
OLD_PROCESS_NAME=""
OLD_SERVICE_NAME=""

# 目标配置（用户指定或继承）
NEW_BIN_NAME=""
NEW_INSTALL_PATH=""
NEW_CONFIG_PATH=""
NEW_PROCESS_NAME=""
NEW_SERVICE_NAME=""

# 其他配置
CONFIG_FILE=""
SKIP_CONFIRM=1
DEBUG_MODE=false

# 旧配置参数覆盖（用于命令行指定）
OLD_BIN_NAME_OVERRIDE=""
OLD_BIN_DIR_OVERRIDE=""
OLD_CONFIG_PATH_OVERRIDE=""
OLD_PROCESS_NAME_OVERRIDE=""
OLD_SERVICE_NAME_OVERRIDE=""

#=================================================
#              函数定义
#=================================================

function show_help() {
    cat << 'EOF'
XrayR 迁移工具

用法: bash migrate.sh [选项]

迁移现有的 XrayR 安装到新位置、新名称、新进程名。

必选项:
  无 (会自动从 /etc/XrayR/.install_config 读取旧配置)

可选项:
  --config-file PATH          指定 .install_config 文件路径
                              默认: /etc/XrayR/.install_config

  --old-bin-name NAME         手动指定旧的二进制文件名
  --old-install-path PATH     手动指定旧的安装路径
  --old-config-path PATH      手动指定旧的配置路径
  --old-process-name NAME     手动指定旧的进程名
  --old-service-name NAME     手动指定旧的 Service 名称

  -b, --to-bin-name NAME      迁移到新的二进制文件名
  -p, --to-process-name NAME  迁移到新的进程名
  -s, --to-service-name NAME  迁移到新的 Service 名称 (systemd/OpenRC/rc.d 等)
  -i, --to-install-path PATH  迁移到新的安装路径
  -c, --to-config-path PATH   迁移到新的配置路径

  --confirm                   显示确认对话 (默认为全自动化无需确认)
  -d, --debug                 启用调试模式
  -h, --help                  显示此帮助信息

示例:

  # 全自动：使用默认旧配置，无参数
  bash migrate.sh

  # 立即改变进程名（其他参数保持不变）
  bash migrate.sh --to-process-name apache

  # 迁移到新的安装路径和配置路径
  bash migrate.sh \
    --to-install-path /opt/myapp \
    --to-config-path /opt/config \
    --to-bin-name myapp \
    --to-process-name myworker

  # 指定非标准旧配置，自动补全 .install_config
  bash migrate.sh \
    --old-bin-name custom-bin \
    --old-install-path /opt/custom \
    --to-bin-name new-bin

EOF
}

# 获取绝对路径
function get_absolute_path() {
    local path="$1"
    if [[ "$path" == /* ]]; then
        echo "$path"
    else
        echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    fi
}

# 读取旧配置
function load_old_config() {
    # 尝试从配置文件或默认值读取
    if [[ -f "$CONFIG_FILE" ]]; then
        INFO "读取旧配置: $CONFIG_FILE"
        source "$CONFIG_FILE"
        
        # 从配置文件中提取变量
        OLD_BIN_NAME="${XRAY_BIN_NAME:-XrayR}"
        OLD_BIN_DIR="${XRAYR_BIN_DIR:-/usr/local/XrayR}"
        OLD_CONFIG_PATH="${CONFIG_DIR:-/etc/XrayR}"
        OLD_PROCESS_NAME="${XRAY_PROCESS_NAME:-XrayR}"
        OLD_SERVICE_NAME="${XRAY_SERVICE_NAME:-xrayr}"
    else
        # 配置文件不存在时，使用默认值作为旧配置
        WARN "配置文件不存在: $CONFIG_FILE"
        INFO "使用默认安装配置..."
        
        OLD_BIN_NAME="XrayR"
        OLD_BIN_DIR="/usr/local/XrayR"
        OLD_CONFIG_PATH="/etc/XrayR"
        OLD_PROCESS_NAME="XrayR"
        OLD_SERVICE_NAME="xrayr"
    fi
    
    # 允许通过参数覆盖（命令行参数优先级最高）
    OLD_BIN_NAME="${OLD_BIN_NAME_OVERRIDE:-$OLD_BIN_NAME}"
    OLD_BIN_DIR="${OLD_BIN_DIR_OVERRIDE:-$OLD_BIN_DIR}"
    OLD_CONFIG_PATH="${OLD_CONFIG_PATH_OVERRIDE:-$OLD_CONFIG_PATH}"
    OLD_PROCESS_NAME="${OLD_PROCESS_NAME_OVERRIDE:-$OLD_PROCESS_NAME}"
    OLD_SERVICE_NAME="${OLD_SERVICE_NAME_OVERRIDE:-$OLD_SERVICE_NAME}"
    
    # 验证二进制文件存在，如果不存在则尝试查找
    if [[ ! -f "${OLD_BIN_DIR}/${OLD_BIN_NAME}" ]]; then
        # 尝试在安装路径中查找任何 XrayR 相关的可执行文件
        local found_bin
        found_bin=$(find "$OLD_BIN_DIR" -maxdepth 1 -type f -executable -name "XrayR*" -o -name "*service*" 2>/dev/null | head -1)
        
        if [[ -n "$found_bin" ]]; then
            OLD_BIN_NAME="$(basename "$found_bin")"
            WARN "自动检测到二进制文件: $OLD_BIN_NAME"
        else
            # 如果仍然找不到，显示错误和帮助信息
            ERROR "无法找到旧的二进制文件: ${OLD_BIN_DIR}/${OLD_BIN_NAME}"
            ERROR "支持的操作："
            ERROR "  1. 创建 $CONFIG_FILE 文件并指定正确的配置"
            ERROR "  2. 使用命令行参数手动指定旧配置："
            ERROR "     sudo bash migrate.sh \\"
            ERROR "       --old-bin-name <old-name> \\"
            ERROR "       --old-install-path <old-path> \\"
            ERROR "       --old-config-path <old-config-path> \\"
            ERROR "       --to-bin-name <new-name>"
            exit 1
        fi
    fi
    
    INFO "旧配置已加载:"
    INFO "  二进制名: $OLD_BIN_NAME"
    INFO "  安装路径: $OLD_BIN_DIR"
    INFO "  配置路径: $OLD_CONFIG_PATH"
    INFO "  进程名: $OLD_PROCESS_NAME"
    INFO "  Service 名: $OLD_SERVICE_NAME"
}

# 验证旧二进制文件存在
function verify_old_binary() {
    local old_bin="${OLD_BIN_DIR}/${OLD_BIN_NAME}"
    if [[ ! -f "$old_bin" ]]; then
        ERROR "旧二进制文件不存在: $old_bin"
        exit 1
    fi
    INFO "验证旧二进制文件: $old_bin ✓"
}

# 准备新配置（如果未指定则继承旧值）
function prepare_new_config() {
    # 先检查用户是否指定了新参数
    local has_new_params=0
    if [[ -n "$NEW_BIN_NAME" || -n "$NEW_INSTALL_PATH" || -n "$NEW_PROCESS_NAME" || -n "$NEW_SERVICE_NAME" ]]; then
        has_new_params=1
    fi
    
    # 设置默认值（如果未指定）
    NEW_BIN_NAME="${NEW_BIN_NAME:-$OLD_BIN_NAME}"
    NEW_INSTALL_PATH="${NEW_INSTALL_PATH:-$OLD_BIN_DIR}"
    NEW_PROCESS_NAME="${NEW_PROCESS_NAME:-$OLD_PROCESS_NAME}"
    NEW_SERVICE_NAME="${NEW_SERVICE_NAME:-$OLD_SERVICE_NAME}"
    
    # NEW_CONFIG_PATH 的智能默认值
    # 如果用户指定了新参数，配置路径默认为标准位置 /etc/XrayR（除非显式指定）
    # 否则继承旧的配置路径
    if [[ $has_new_params -eq 1 ]]; then
        NEW_CONFIG_PATH="${NEW_CONFIG_PATH:-/etc/XrayR}"
    else
        NEW_CONFIG_PATH="${NEW_CONFIG_PATH:-$OLD_CONFIG_PATH}"
    fi
    
    # 规范化路径
    NEW_INSTALL_PATH="$(get_absolute_path "$NEW_INSTALL_PATH")"
    NEW_CONFIG_PATH="$(get_absolute_path "$NEW_CONFIG_PATH")"
    
    INFO "新配置已准备:"
    INFO "  二进制名: $NEW_BIN_NAME"
    INFO "  安装路径: $NEW_INSTALL_PATH"
    INFO "  配置路径: $NEW_CONFIG_PATH"
    INFO "  进程名: $NEW_PROCESS_NAME"
    INFO "  Service 名: $NEW_SERVICE_NAME"
}

# 检测是否需要执行实际迁移（如果配置完全相同，只补全.install_config）
function check_migration_needed() {
    local need_migration=0
    
    if [[ "$OLD_BIN_NAME" != "$NEW_BIN_NAME" ]]; then
        INFO "✓ 二进制名改变：需要迁移"
        need_migration=1
    fi
    
    if [[ "$OLD_BIN_DIR" != "$NEW_INSTALL_PATH" ]]; then
        INFO "✓ 安装路径改变：需要迁移"
        need_migration=1
    fi
    
    if [[ "$OLD_CONFIG_PATH" != "$NEW_CONFIG_PATH" ]]; then
        INFO "✓ 配置路径改变：需要迁移"
        need_migration=1
    fi
    
    if [[ "$OLD_SERVICE_NAME" != "$NEW_SERVICE_NAME" ]]; then
        INFO "✓ Service 名改变：需要迁移"
        need_migration=1
    fi
    
    # 进程名改变不需要迁移（只需重启即可），但为了完整性记录
    if [[ "$OLD_PROCESS_NAME" != "$NEW_PROCESS_NAME" ]]; then
        INFO "ℹ 进程名改变：只需重启服务"
    fi
    
    echo $need_migration
}

# 检测旧 Service 文件是否为硬编码版本（全平台支持）
function check_old_service_hardcoding() {
    local is_hardcoded=0
    local service_file=""
    
    # systemd (Linux with systemd)
    if command -v systemctl &> /dev/null; then
        service_file="/etc/systemd/system/${OLD_SERVICE_NAME}.service"
        if [[ -f "$service_file" ]]; then
            if ! grep -q "source.*\.install_config" "$service_file"; then
                is_hardcoded=1
            fi
        fi
    fi
    
    # OpenRC (Alpine, Debian without systemd)
    if [[ $is_hardcoded -eq 0 ]] && [[ -f "/etc/init.d/${OLD_SERVICE_NAME}" ]]; then
        service_file="/etc/init.d/${OLD_SERVICE_NAME}"
        if ! grep -q "source.*\.install_config" "$service_file"; then
            is_hardcoded=1
        fi
    fi
    
    # macOS launchd
    if [[ $is_hardcoded -eq 0 ]] && [[ -f "/Library/LaunchDaemons/com.${OLD_SERVICE_NAME}.plist" ]]; then
        service_file="/Library/LaunchDaemons/com.${OLD_SERVICE_NAME}.plist"
        # plist 格式不同，检查是否包含动态配置相关的标记
        if ! grep -q "install_config\|XRAY_PROCESS_NAME" "$service_file"; then
            is_hardcoded=1
        fi
    fi
    
    # FreeBSD rc.d
    if [[ $is_hardcoded -eq 0 ]] && [[ -f "/usr/local/etc/rc.d/${OLD_SERVICE_NAME}" ]]; then
        service_file="/usr/local/etc/rc.d/${OLD_SERVICE_NAME}"
        if ! grep -q "source.*\.install_config" "$service_file"; then
            is_hardcoded=1
        fi
    fi
    
    # OpenBSD rc.d
    if [[ $is_hardcoded -eq 0 ]] && [[ -f "/etc/rc.d/${OLD_SERVICE_NAME}" ]]; then
        service_file="/etc/rc.d/${OLD_SERVICE_NAME}"
        if ! grep -q "source.*\.install_config" "$service_file"; then
            is_hardcoded=1
        fi
    fi
    
    # Termux service
    if [[ $is_hardcoded -eq 0 ]] && [[ -f "$HOME/.termux/service/${OLD_SERVICE_NAME}/run" ]]; then
        service_file="$HOME/.termux/service/${OLD_SERVICE_NAME}/run"
        if ! grep -q "source.*\.install_config" "$service_file"; then
            is_hardcoded=1
        fi
    fi
    
    # 如果检测到硬编码，发出警告并退出
    if [[ $is_hardcoded -eq 1 ]]; then
        WARN "检测到硬编码版本的 Service 文件: $service_file"
        WARN "此 Service 文件仍使用旧的硬编码方式，需要重新生成为动态版本"
        WARN ""
        WARN "请运行以下命令完成升级："
        WARN "  sudo bash install.sh -s ${NEW_SERVICE_NAME}"
        WARN ""
        WARN "或手动删除旧 Service 文件，下次启动时自动生成动态版本。"
        exit 1
    fi
}

# 显示迁移摘要
function show_migration_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "                  XrayR 迁移摘要"
    echo "═══════════════════════════════════════════════════════"
    
    if [[ "$OLD_BIN_NAME" != "$NEW_BIN_NAME" ]]; then
        echo "二进制名: $OLD_BIN_NAME → $NEW_BIN_NAME"
    else
        echo "二进制名: $OLD_BIN_NAME (不变)"
    fi
    
    if [[ "$OLD_BIN_DIR" != "$NEW_INSTALL_PATH" ]]; then
        echo "安装路径: $OLD_BIN_DIR → $NEW_INSTALL_PATH"
    else
        echo "安装路径: $OLD_BIN_DIR (不变)"
    fi
    
    if [[ "$OLD_CONFIG_PATH" != "$NEW_CONFIG_PATH" ]]; then
        echo "配置路径: $OLD_CONFIG_PATH → $NEW_CONFIG_PATH"
    else
        echo "配置路径: $OLD_CONFIG_PATH (不变)"
    fi
    
    if [[ "$OLD_PROCESS_NAME" != "$NEW_PROCESS_NAME" ]]; then
        echo "进程名: $OLD_PROCESS_NAME → $NEW_PROCESS_NAME"
    else
        echo "进程名: $OLD_PROCESS_NAME (不变)"
    fi
    
    if [[ "$OLD_SERVICE_NAME" != "$NEW_SERVICE_NAME" ]]; then
        echo "Service 名: $OLD_SERVICE_NAME → $NEW_SERVICE_NAME"
    else
        echo "Service 名: $OLD_SERVICE_NAME (不变)"
    fi
    
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    if [[ $SKIP_CONFIRM -eq 0 ]]; then
        read -p "请确认上述迁移参数是否正确 (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            INFO "迁移已取消。"
            exit 0
        fi
    fi
}

# 清理旧的 Service 文件（如果 service 名称改变的话）
function cleanup_old_service() {
    # 如果 service 名称没有改变，则不需要清理
    if [[ "$OLD_SERVICE_NAME" == "$NEW_SERVICE_NAME" ]]; then
        return 0
    fi
    
    INFO "清理旧的 Service 文件..."
    
    local priv_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            priv_cmd="sudo"
        fi
    fi
    
    # systemd
    if [[ -f "/etc/systemd/system/${OLD_SERVICE_NAME}.service" ]]; then
        INFO "移除旧的 systemd service: /etc/systemd/system/${OLD_SERVICE_NAME}.service"
        $priv_cmd rm -f "/etc/systemd/system/${OLD_SERVICE_NAME}.service"
        $priv_cmd systemctl daemon-reload || true
    fi
    
    # OpenRC
    if [[ -f "/etc/init.d/${OLD_SERVICE_NAME}" ]]; then
        INFO "移除旧的 OpenRC service: /etc/init.d/${OLD_SERVICE_NAME}"
        $priv_cmd rm -f "/etc/init.d/${OLD_SERVICE_NAME}"
    fi
    
    # macOS launchd
    if [[ -f "/Library/LaunchDaemons/com.${OLD_SERVICE_NAME}.plist" ]]; then
        INFO "移除旧的 launchd service: /Library/LaunchDaemons/com.${OLD_SERVICE_NAME}.plist"
        $priv_cmd launchctl unload "/Library/LaunchDaemons/com.${OLD_SERVICE_NAME}.plist" 2>/dev/null || true
        $priv_cmd rm -f "/Library/LaunchDaemons/com.${OLD_SERVICE_NAME}.plist"
    fi
    
    # FreeBSD rc.d
    if [[ -f "/usr/local/etc/rc.d/${OLD_SERVICE_NAME}" ]]; then
        INFO "移除旧的 FreeBSD rc.d service: /usr/local/etc/rc.d/${OLD_SERVICE_NAME}"
        $priv_cmd rm -f "/usr/local/etc/rc.d/${OLD_SERVICE_NAME}"
    fi
    
    # OpenBSD rc.d
    if [[ -f "/etc/rc.d/${OLD_SERVICE_NAME}" ]]; then
        INFO "移除旧的 OpenBSD rc.d service: /etc/rc.d/${OLD_SERVICE_NAME}"
        $priv_cmd rm -f "/etc/rc.d/${OLD_SERVICE_NAME}"
    fi
    
    # Termux
    if [[ -d "$HOME/.termux/service/${OLD_SERVICE_NAME}" ]]; then
        INFO "移除旧的 Termux service: $HOME/.termux/service/${OLD_SERVICE_NAME}"
        rm -rf "$HOME/.termux/service/${OLD_SERVICE_NAME}"
    fi
}

# 停止服务
function stop_service() {
    INFO "正在停止 XrayR 服务..."
    
    local priv_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            priv_cmd="sudo"
        fi
    fi
    
    # 停止旧 service
    if command -v systemctl &> /dev/null; then
        $priv_cmd systemctl stop ${OLD_SERVICE_NAME} || WARN "systemctl stop 失败，继续..."
    elif command -v rc-service &> /dev/null; then
        $priv_cmd rc-service ${OLD_SERVICE_NAME} stop || WARN "rc-service stop 失败，继续..."
    fi
}

# 迁移二进制文件
function migrate_binary() {
    local old_bin="${OLD_BIN_DIR}/${OLD_BIN_NAME}"
    local new_bin="${NEW_INSTALL_PATH}/${NEW_BIN_NAME}"
    
    # 如果路径和名称都没变，则跳过
    if [[ "$old_bin" == "$new_bin" ]]; then
        INFO "二进制文件位置未变，跳过迁移。"
        return 0
    fi
    
    INFO "迁移二进制文件..."
    
    # 创建新目录
    mkdir -p "$NEW_INSTALL_PATH" || {
        ERROR "无法创建目录: $NEW_INSTALL_PATH"
        exit 1
    }
    
    # 备份新位置的旧文件（如果存在）
    if [[ -f "$new_bin" ]]; then
        WARN "目标文件已存在，备份为 ${new_bin}.bak"
        mv "$new_bin" "${new_bin}.bak"
    fi
    
    # 复制（而非移动，保留源文件作为备份）
    cp "$old_bin" "$new_bin" || {
        ERROR "无法复制二进制文件。"
        exit 1
    }
    chmod +x "$new_bin"
    
    # 可选：删除或保留旧文件
    if [[ "$OLD_BIN_DIR" != "$NEW_INSTALL_PATH" ]]; then
        WARN "备份旧二进制文件: ${old_bin}.bak_old"
        mv "$old_bin" "${old_bin}.bak_old" || true
    fi
    
    INFO "二进制文件已迁移: $new_bin"
}

# 迁移配置文件（可选）
function migrate_config() {
    if [[ "$OLD_CONFIG_PATH" == "$NEW_CONFIG_PATH" ]]; then
        INFO "配置路径未变，跳过迁移。"
        return 0
    fi
    
    INFO "迁移配置文件..."
    
    if [[ -d "$OLD_CONFIG_PATH" ]]; then
        mkdir -p "$NEW_CONFIG_PATH"
        
        # 备份新位置的旧配置（如果存在）
        if [[ -n "$(ls -A "$NEW_CONFIG_PATH" 2>/dev/null)" ]]; then
            local backup_ts=$(date +%s)
            WARN "新配置路径已有文件，备份为 ${NEW_CONFIG_PATH}.backup_${backup_ts}"
            mv "$NEW_CONFIG_PATH" "${NEW_CONFIG_PATH}.backup_${backup_ts}"
            mkdir -p "$NEW_CONFIG_PATH"
        fi
        
        # 备份旧配置路径（用于链式迁移回溯）
        if [[ "$OLD_CONFIG_PATH" != "$NEW_CONFIG_PATH" ]]; then
            local backup_ts=$(date +%s)
            WARN "备份旧配置路径: ${OLD_CONFIG_PATH}.backup_${backup_ts}"
            cp -r "$OLD_CONFIG_PATH" "${OLD_CONFIG_PATH}.backup_${backup_ts}" || true
        fi
        
        # 复制配置文件（除了 .install_config）
        cp -r "$OLD_CONFIG_PATH"/* "$NEW_CONFIG_PATH/" 2>/dev/null || true
        INFO "配置文件已迁移到: $NEW_CONFIG_PATH"
    fi
}

# 注意: Service 文件配置已改为动态加载 .install_config
# 无需在此更新 service 文件，只需更新 .install_config 即可
# Service 启动时会自动读取最新配置

# 检测 Service 文件是否为硬编码版本
function detect_service_version() {
    local service_file="$1"
    
    if [[ ! -f "$service_file" ]]; then
        echo "missing"
        return 0
    fi
    
    # 检查文件中是否包含 "source.*\.install_config"
    if grep -q "source.*\.install_config" "$service_file"; then
        echo "dynamic"    # 新的动态版本
    else
        echo "hardcoded"  # 旧的硬编码版本
    fi
}

# 更新配置文件
function update_install_config() {
    INFO "更新 .install_config..."
    
    mkdir -p "$NEW_CONFIG_PATH"
    
    cat > "${NEW_CONFIG_PATH}/.install_config" << EOF
# XrayR 安装配置信息 (迁移工具自动更新)
XRAY_BIN_NAME="${NEW_BIN_NAME}"
XRAYR_BIN_DIR="${NEW_INSTALL_PATH}"
CONFIG_DIR="${NEW_CONFIG_PATH}"
XRAY_PROCESS_NAME="${NEW_PROCESS_NAME}"
XRAY_SERVICE_NAME="${NEW_SERVICE_NAME}"
MIGRATE_FROM="${OLD_BIN_DIR}/${OLD_BIN_NAME}"
MIGRATE_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
    
    chmod 600 "${NEW_CONFIG_PATH}/.install_config"
    INFO "配置文件已保存: ${NEW_CONFIG_PATH}/.install_config"
}

# 启动服务
function start_service() {
    INFO "启动 XrayR 服务..."
    
    local priv_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            priv_cmd="sudo"
        fi
    fi
    
    # 启动新 service（使用新的 service 名称）
    if command -v systemctl &> /dev/null; then
        $priv_cmd systemctl restart ${NEW_SERVICE_NAME}
    elif command -v rc-service &> /dev/null; then
        $priv_cmd rc-service ${NEW_SERVICE_NAME} restart
    fi
    
    sleep 2
    INFO "服务启动完成。"
}

# 解析参数
function parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config-file)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --old-bin-name)
                OLD_BIN_NAME_OVERRIDE="$2"
                shift 2
                ;;
            --old-install-path)
                OLD_BIN_DIR_OVERRIDE="$2"
                shift 2
                ;;
            --old-config-path)
                OLD_CONFIG_PATH_OVERRIDE="$2"
                shift 2
                ;;
            --old-process-name)
                OLD_PROCESS_NAME_OVERRIDE="$2"
                shift 2
                ;;
            --old-service-name)
                OLD_SERVICE_NAME_OVERRIDE="$2"
                shift 2
                ;;
            -b|--to-bin-name)
                NEW_BIN_NAME="$2"
                shift 2
                ;;
            -p|--to-process-name)
                NEW_PROCESS_NAME="$2"
                shift 2
                ;;
            -s|--to-service-name)
                NEW_SERVICE_NAME="$2"
                shift 2
                ;;
            -i|--to-install-path)
                if [[ -n "$2" && "$2" != -* ]]; then
                    NEW_INSTALL_PATH="$2"
                    shift 2
                else
                    ERROR "缺少新的安装路径参数值, 请使用 -i <path> 指定安装路径。"
                    exit 1
                fi
                ;;
            -c|--to-config-path)
                NEW_CONFIG_PATH="$2"
                shift 2
                ;;
            --confirm)
                SKIP_CONFIRM=0
                shift
                ;;
            -d|--debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                ERROR "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

#=================================================
#              主函数
#=================================================

function main() {
    # 默认配置文件路径
    CONFIG_FILE="${CONFIG_FILE:-/etc/XrayR/.install_config}"
    
    # 解析参数
    parse_arguments "$@"
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        if ! command -v sudo &> /dev/null && ! command -v doas &> /dev/null; then
            ERROR "需要 root 权限或 sudo/doas。"
            exit 1
        fi
    fi
    
    INFO "XrayR 迁移工具开始执行..."
    echo ""
    
    # 加载旧配置
    load_old_config
    
    # 验证旧二进制
    verify_old_binary
    
    # 准备新配置
    prepare_new_config
    
    # 显示摘要
    show_migration_summary
    
    # 检测旧 Service 文件版本（硬编码 vs 动态）- 全平台支持
    check_old_service_hardcoding
    
    # 检查是否需要执行实际迁移
    NEED_MIGRATION=$(check_migration_needed)
    
    if [[ $NEED_MIGRATION -eq 0 ]]; then
        # 配置完全相同，只补全 .install_config（不停止/启动服务）
        INFO ""
        INFO "检测到新旧配置相同，跳过服务重启。"
        INFO "仅更新 .install_config 文件..."
        update_install_config
        
        echo ""
        INFO "配置文件补全完成！"
        INFO "配置位置: ${NEW_CONFIG_PATH}/.install_config"
        echo ""
    else
        # 配置改变，执行完整迁移
        INFO ""
        INFO "检测到配置改变，执行完整迁移..."
        
        # 执行迁移
        stop_service
        cleanup_old_service
        migrate_binary
        migrate_config
        update_install_config
        start_service
        
        echo ""
        INFO "迁移完成！"
        INFO "新配置信息："
        INFO "  二进制位置: ${NEW_INSTALL_PATH}/${NEW_BIN_NAME}"
        INFO "  配置位置: ${NEW_CONFIG_PATH}"
        INFO "  进程名: ${NEW_PROCESS_NAME}"
        echo ""
    fi
}

main "$@"
