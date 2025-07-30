#!/usr/bin/env bash

# Function to check and download dependencies
check_and_download_scripts() {
    local base_url="https://raw.githubusercontent.com/ccxkai233/warp-more-unlocks/main"
    local scripts_dir="scripts"
    local files_to_check=(
        "$scripts_dir/variables.sh"
        "$scripts_dir/unlock_test.sh"
        "$scripts_dir/functions.sh"
    )

    if [ ! -d "$scripts_dir" ]; then
        mkdir -p "$scripts_dir"
    fi

    for file in "${files_to_check[@]}"; do
        if [ ! -f "$file" ]; then
            echo "Downloading $file..."
            wget -O "$file" "$base_url/$file"
            if [ $? -ne 0 ]; then
                echo "Error downloading $file. Aborting."
                exit 1
            fi
        fi
    done
}

# Run the check and download function
check_and_download_scripts

# Source variables and functions
source scripts/variables.sh
source scripts/unlock_test.sh
source scripts/functions.sh

# 传参选项 OPTION: 1=为 IPv4 或者 IPv6 补全另一栈WARP; 2=安装双栈 WARP; u=卸载 WARP; b=升级内核、开启BBR及DD; o=WARP开关; 其他或空值=菜单界面
[ "$1" != '[option]' ] && OPTION="${1,,}"

# 参数选项 URL 或 License 或转换 WARP 单双栈
if [ "$2" != '[lisence]' ]; then
  case "$OPTION" in
    s )
      [[ "${2,,}" = [46d] ]] && PRIORITY_SWITCH="${2,,}"
      ;;
    i )
      [[ "${2,,}" =~ ^[a-z]{2}$ ]] && EXPECT="${2,,}"
  esac
fi

# 自定义 WARP+ 设备名
NAME=$3

# 主程序运行 1/3

check_cdn
statistics_of_run-times update menu.sh
select_language
check_operating_system

# 设置部分后缀 1/3
case "$OPTION" in
  h )
    help; exit 0
    ;;
  z )
    wait_for interface; rule_add; exit 0
    ;;
  x )
    rule_del; exit 0
    ;;
  i )
    change_ip; exit 0
    ;;
  s )
    stack_priority; result_priority; exit 0
esac

# 主程序运行 2/3
check_root

# 设置部分后缀 2/3
case "$OPTION" in
  b )
    bbrInstall; exit 0
    ;;
  u )
    uninstall; exit 0
    ;;
  v )
    ver; exit 0
    ;;
  n )
    net; exit 0
    ;;
  o )
    onoff; exit 0
    ;;
  r )
    client_onoff; exit 0
    ;;
  y )
    wireproxy_onoff; exit 0
esac

# 主程序运行 3/3
check_dependencies
check_virt $SYSTEM
check_system_info

# 提前准备最佳 MTU 和优选 Endpoint
if [[ ${CLIENT} = 0 && ${WIREPROXY} = 0 && ! -s /etc/wireguard/warp.conf ]]; then
  # 后台优选最佳 MTU
  { best_mtu; }&

  # 后台优选优选 WARP Endpoint
  { best_endpoint; }&
fi
menu_setting

# 设置部分后缀 3/3
case "$OPTION" in
  a )
    if [[ "$2" =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; then
      CHOOSE_TYPE=2 && LICENSE=$2
    elif [[ "$2" =~ ^http ]]; then
      CHOOSE_TYPE=3 && CHOOSE_TEAMS=1 && TEAM_URL=$2
    elif [[ "$2" =~ ^ey && "${#2}" -gt 120 ]]; then
      CHOOSE_TYPE=3 && CHOOSE_TEAMS=2 && TEAM_TOKEN=$2
    fi
    update
    ;;
  # 在已运行 Linux Client 前提下，不能安装 WARP IPv4 或者双栈网络接口。如已经运行 WARP ，参数 4,6,d 从原来的安装改为切换
  [46d] )
    if [ -e /etc/wireguard/warp.conf ]; then
      SWITCHCHOOSE="${OPTION^^}"
      stack_switch
    else
      case "$OPTION" in
        4 )
          [[ "$CLIENT" = [35] ]] && error " $(text 110) "
          CONF=${CONF1[n]}
          ;;
        6 )
          CONF=${CONF2[n]}
          ;;
        d )
          [[ "$CLIENT" = [35] ]] && error " $(text 110) "
          CONF=${CONF3[n]}
      esac
      install
    fi
    ;;
  c )
    client_install
    ;;
  l )
    IS_LUBAN=is_luban && client_install
    ;;
  a )
    update
    ;;
  e )
    stream_solution
    ;;
  w )
    wireproxy_solution
    ;;
  k )
    kernel_reserved_switch
    ;;
  g )
    [ ! -e /etc/wireguard/warp.conf ] && ( GLOBAL_OR_NOT_CHOOSE=2 && CONF=${CONF3[n]} && install; true ) || working_mode_switch
    ;;
  * )
    menu
esac