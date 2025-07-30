#!/usr/bin/env bash

# 自定义字体彩色，read 函数
warning() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; }  # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }   # 黄色
reading() { read -rp "$(info "$1")" "$2"; }
text() { grep -q '\$' <<< "${E[$*]}" && eval echo "\$(eval echo "\${${L}[$*]}")" || eval echo "\${${L}[$*]}"; }

# 清理函数
cleanup_resources() {
  rm -f /tmp/{endpoint,ip,endpoint_result,wireguard-go-*,best_mtu,best_endpoint,noudp} 2>/dev/null; exit 0
}

# 检测是否需要启用 Github CDN，如能直接连通，则不使用
check_cdn() {
  [ -n "$GH_PROXY" ] && wget --server-response --quiet --output-document=/dev/null --no-check-certificate --tries=2 --timeout=3 https://raw.githubusercontent.com/fscarmen/warp-sh/main/README.md >/dev/null 2>&1 && unset GH_PROXY
}

# 脚本当天及累计运行次数统计
statistics_of_run-times() {
  local UPDATE_OR_GET=$1
  local SCRIPT=$2
  if grep -q 'update' <<< "$UPDATE_OR_GET"; then
    { wget --no-check-certificate -qO- --timeout=3 "https://stat.cloudflare.now.cc/api/updateStats?script=${SCRIPT}" > /tmp/statistics; }&
  elif grep -q 'get' <<< "$UPDATE_OR_GET"; then
    [ -s /tmp/statistics ] && [[ $(cat /tmp/statistics) =~ \"todayCount\":([0-9]+),\"totalCount\":([0-9]+) ]] && local TODAY="${BASH_REMATCH[1]}" && local TOTAL="${BASH_REMATCH[2]}" && rm -f /tmp/statistics
    info " $(text 41) "
  fi
}

# 选择语言，先判断 /etc/wireguard/language 里的语言选择，没有的话再让用户选择，默认英语。处理中文显示的问题
select_language() {
  UTF8_LOCALE=$(locale -a 2>/dev/null | grep -iEm1 "UTF-8|utf8")
  [ -n "$UTF8_LOCALE" ] && export LC_ALL="$UTF8_LOCALE" LANG="$UTF8_LOCALE" LANGUAGE="$UTF8_LOCALE"

  if [ -s /etc/wireguard/language ]; then
    L=$(cat /etc/wireguard/language)
  else
    L=E && [[ -z "$OPTION" || "$OPTION" = [aclehdpbviw46sg] ]] && hint " $(text 0) \n" && reading " $(text 50) " LANGUAGE
    [ "$LANGUAGE" = 2 ] && L=C
  fi
}

# 必须以root运行脚本
check_root() {
  [ "$(id -u)" != 0 ] && error " $(text 2) "
}

# 判断虚拟化
check_virt() {
  if [ "$1" = 'Alpine' ]; then
    VIRT=$(virt-what | tr '\n' ' ')
  else
    [ "$(type -p systemd-detect-virt)" ] && VIRT=$(systemd-detect-virt)
    [[ -z "$VIRT" && -x "$(type -p hostnamectl)" ]] && VIRT=$(hostnamectl | awk '/Virtualization:/{print $NF}')
  fi
}

# 多方式判断操作系统，试到有值为止。只支持 Debian 10/11、Ubuntu 18.04/20.04 或 CentOS 7/8 ,如非上述操作系统，退出脚本
# 感谢猫大的技术指导优化重复的命令。https://github.com/Oreomeow
check_operating_system() {
  if [ -s /etc/os-release ]; then
    SYS="$(grep -i pretty_name /etc/os-release | cut -d \" -f2)"
  elif [ -x "$(type -p hostnamectl)" ]; then
    SYS="$(hostnamectl | grep -i system | cut -d : -f2)"
  elif [ -x "$(type -p lsb_release)" ]; then
    SYS="$(lsb_release -sd)"
  elif [ -s /etc/lsb-release ]; then
    SYS="$(grep -i description /etc/lsb-release | cut -d \" -f2)"
  elif [ -s /etc/redhat-release ]; then
    SYS="$(grep . /etc/redhat-release)"
  elif [ -s /etc/issue ]; then
    SYS="$(grep . /etc/issue | cut -d '\' -f1 | sed '/^[ ]*$/d')"
  fi

  # 自定义 Alpine 系统若干函数
  alpine_warp_restart() { wg-quick down warp >/dev/null 2>&1; wg-quick up warp >/dev/null 2>&1; }
  alpine_warp_enable() { echo -e "/usr/bin/tun.sh\nwg-quick up warp" > /etc/local.d/warp.start; chmod +x /etc/local.d/warp.start; rc-update add local; wg-quick up warp >/dev/null 2>&1; }

  REGEX=("debian" "ubuntu" "centos|red hat|kernel|alma|rocky" "alpine" "arch linux" "fedora")
  RELEASE=("Debian" "Ubuntu" "CentOS" "Alpine" "Arch" "Fedora")
  EXCLUDE=("---")
  MAJOR=("9" "16" "7" "" "" "37")
  PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update --skip-broken" "apk update -f" "pacman -Sy" "dnf -y update")
  PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "apk add -f" "pacman -S --noconfirm" "dnf -y install")
  PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "apk del -f" "pacman -Rcnsu --noconfirm" "dnf -y autoremove")
  SYSTEMCTL_START=("systemctl start wg-quick@warp" "systemctl start wg-quick@warp" "systemctl start wg-quick@warp" "wg-quick up warp" "systemctl start wg-quick@warp" "systemctl start wg-quick@warp")
  SYSTEMCTL_RESTART=("systemctl restart wg-quick@warp" "systemctl restart wg-quick@warp" "systemctl restart wg-quick@warp" "alpine_warp_restart" "systemctl restart wg-quick@warp" "systemctl restart wg-quick@warp")
  SYSTEMCTL_ENABLE=("systemctl enable --now wg-quick@warp" "systemctl enable --now wg-quick@warp" "systemctl enable --now wg-quick@warp" "alpine_warp_enable" "systemctl enable --now wg-quick@warp" "systemctl enable --now wg-quick@warp")

  for int in "${!REGEX[@]}"; do
    [[ "${SYS,,}" =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && break
  done

  # 针对各厂运的订制系统
  if [ -z "$SYSTEM" ]; then
    [ -x "$(type -p yum)" ] && int=2 && SYSTEM='CentOS' || error " $(text 5) "
  fi

  # 判断主 Linux 版本
  MAJOR_VERSION=$(sed "s/[^0-9.]//g" <<< "$SYS" | cut -d. -f1)

  # 先排除 EXCLUDE 里包括的特定系统，其他系统需要作大发行版本的比较
  for ex in "${EXCLUDE[@]}"; do [[ ! "${SYS,,}" =~ $ex ]]; done &&
  [[ "$MAJOR_VERSION" -lt "${MAJOR[int]}" ]] && error " $(text 26) "
}

# 安装系统依赖及定义 ping 指令
check_dependencies() {
  # 对于 alpine 系统，升级库并重新安装依赖
  if [ "$SYSTEM" = 'Alpine' ]; then
    CHECK_WGET=$(wget 2>&1 | head -n 1)
    grep -qi 'busybox' <<< "$CHECK_WGET" && ${PACKAGE_INSTALL[int]} wget >/dev/null 2>&1
    DEPS_CHECK=("ping" "curl" "grep" "bash" "ip" "virt-what")
    DEPS_INSTALL=("iputils-ping" "curl" "grep" "bash" "iproute2" "virt-what")
  else
    # 对于三大系统需要的依赖
    DEPS_CHECK=("ping" "wget" "curl" "systemctl" "ip")
    DEPS_INSTALL=("iputils-ping" "wget" "curl" "systemctl" "iproute2")
  fi

  for g in "${!DEPS_CHECK[@]}"; do
    [ ! -x "$(type -p ${DEPS_CHECK[g]})" ] && [[ ! "${DEPS[@]}" =~ "${DEPS_INSTALL[g]}" ]] && DEPS+=(${DEPS_INSTALL[g]})
  done

  if [ "${#DEPS[@]}" -ge 1 ]; then
    info "\n $(text 7) ${DEPS[@]} \n"
    ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
    ${PACKAGE_INSTALL[int]} ${DEPS[@]} >/dev/null 2>&1
  else
    info "\n $(text 8) \n"
  fi

  PING6='ping -6' && [ -x "$(type -p ping6)" ] && PING6='ping6'
}

# 获取 warp 账户信息
warp_api(){
  local WARP_API_URL="warp.cloudflare.now.cc"
  local RUN=$1
  local FILE_PATH=$2
  local WARP_LICENSE=$3
  local WARP_DEVICE_NAME=$4
  local WARP_TEAM_TOKEN=$5
  local WARP_CONVERT=$6
  local WARP_CONVERT_MODE=$7
  local TEAM_AUTH=$8
  local TEAM_ORGANIZATION=$9
  local TEAM_EMAIL=${10}
  local TEAM_CODE=${11}

  if [ -s "$FILE_PATH" ]; then
    # Teams 账户文件
    if grep -q 'xml version' $FILE_PATH; then
      local WARP_DEVICE_ID=$(grep 'correlation_id' $FILE_PATH | sed "s#.*>\(.*\)<.*#\1#")
      local WARP_TOKEN=$(grep 'warp_token' $FILE_PATH | sed "s#.*>\(.*\)<.*#\1#")
      local WARP_CLIENT_ID=$(grep 'client_id' $FILE_PATH | sed "s#.*client_id":"\([^&]\{4\}\)&.*#\1#")

    # 官方 api 文件
    elif grep -q 'client_id' $FILE_PATH; then
      local WARP_DEVICE_ID=$(grep -m1 '"id' "$FILE_PATH" | cut -d\" -f4)
      local WARP_TOKEN=$(grep '"token' "$FILE_PATH" | cut -d\" -f4)
      local WARP_CLIENT_ID=$(grep 'client_id' "$FILE_PATH" | cut -d\" -f4)

    # client 文件，默认存放路径为 /var/lib/cloudflare-warp/reg.json
    elif grep -q 'registration_id' $FILE_PATH; then
      local WARP_DEVICE_ID=$(cut -d\" -f4 "$FILE_PATH")
      local WARP_TOKEN=$(cut -d\" -f8 "$FILE_PATH")

    # wgcf 文件，默认存放路径为 /etc/wireguard/wgcf-account.toml
    elif grep -q 'access_token' $FILE_PATH; then
      local WARP_DEVICE_ID=$(grep 'device_id' "$FILE_PATH" | cut -d\' -f2)
      local WARP_TOKEN=$(grep 'access_token' "$FILE_PATH" | cut -d\' -f2)

    # warp-go 文件，默认存放路径为 /opt/warp-go/warp.conf
    elif grep -q 'PrivateKey' $FILE_PATH; then
      local WARP_DEVICE_ID=$(awk -F' *= *' '/^Device/{print $2}' "$FILE_PATH")
      local WARP_TOKEN=$(awk -F' *= *' '/^Token/{print $2}' "$FILE_PATH")
    fi
  fi

  case "$RUN" in
    register )
      curl -m5 -sL "https://${WARP_API_URL}/?run=register&team_token=${WARP_TEAM_TOKEN}"
      ;;
    device )
      curl -m5 -sL "https://${WARP_API_URL}/?run=device&device_id=${WARP_DEVICE_ID}&token=${WARP_TOKEN}"
      ;;
    name )
      curl -m5 -sL "https://${WARP_API_URL}/?run=name&device_id=${WARP_DEVICE_ID}&token=${WARP_TOKEN}&device_name=${WARP_DEVICE_NAME}"
      ;;
    license )
      curl -m5 -sL "https://${WARP_API_URL}/?run=license&device_id=${WARP_DEVICE_ID}&token=${WARP_TOKEN}&license=${WARP_LICENSE}"
      ;;
    cancel )
      # 只保留Teams账户，删除其他账户
      grep -oqE '"id":[ ]+"t.[A-F0-9a-f]{8}-' $FILE_PATH || curl -m5 -sL "https://${WARP_API_URL}/?run=cancel&device_id=${WARP_DEVICE_ID}&token=${WARP_TOKEN}"
      ;;
    convert )
      if [ "$WARP_CONVERT_MODE" = decode ]; then
        curl -m5 -sL "https://${WARP_API_URL}/?run=id&convert=${WARP_CONVERT}" | grep -A4 'reserved' | sed 's/.*\(\[.*\)/\1/g; s/],/]/' | tr -d '[:space:]'
      elif [ "$WARP_CONVERT_MODE" = encode ]; then
        curl -m5 -sL "https://${WARP_API_URL}/?run=id&convert=${WARP_CONVERT//[ \[\]]}" | awk -F '"' '/client_id/{print $(NF-1)}'
      elif [ "$WARP_CONVERT_MODE" = file ]; then
        if grep -sq '"reserved"' $FILE_PATH; then
          grep -A4 'reserved' $FILE_PATH | sed 's/.*\(\[.*\)/\1/g; s/],/]/' | tr -d '[:space:]'
        else
          local WARP_CONVERT=$(awk -F '"' '/"client_id"/{print $(NF-1)}' $FILE_PATH)
          curl -m5 -sL "https://${WARP_API_URL}/?run=id&convert=${WARP_CONVERT}" | grep -A4 'reserved' | sed 's/.*\(\[.*\)/\1/g; s/],/]/' | tr -d '[:space:]'
        fi
      fi
      ;;
    token-step1 )
      curl -m5 -sL "https://${WARP_API_URL}/?run=token&organization=${TEAM_ORGANIZATION}&email=${TEAM_EMAIL}"
      ;;
    token-step2 )
      local TEAM_ORGANIZATION=$(sed "s/.*organization=\([^&]\+\)&.*/\1/" <<< "$TEAM_AUTH")
      local A=$(sed "s/.*A=\([^&]\+\)&.*/\1/" <<< "$TEAM_AUTH")
      local S=$(sed "s/.*S=\([^&]\+\)&.*/\1/" <<< "$TEAM_AUTH")
      local N=$(sed "s/.*N=\([^&]\+\)&.*/\1/" <<< "$TEAM_AUTH")

      curl -m5 -sL "https://${WARP_API_URL}/?run=token&organization=${TEAM_ORGANIZATION}&A=${A}&S=${S}&N=${N}&code=${TEAM_CODE}"
      ;;
  esac
}

# 聚合 IP api 函数。由于 ip.sb 会对某些 ip 访问报 error code: 1015，所以使用备用 IP api: ifconfig.co
ip_info() {
  local CHECK_46="$1"
  if [[ "$2" =~ ^[0-9]+$ ]]; then
    local INTERFACE_SOCK5="--proxy socks5h://127.0.0.1:$2"
  elif [[ "$2" =~ ^[[:alnum:]]+$ ]]; then
    local INTERFACE_SOCK5="--interface $2"
  fi
  local IS_UNINSTALL="$3"

  [ "$L" = 'C' ] && IS_CHINESE=${IS_CHINESE:-'?lang=zh-CN'}
  [ "$CHECK_46" = '6' ] && CHOOSE_IP_API='https://api-ipv6.ip.sb/geoip' || CHOOSE_IP_API='https://ipinfo.io/ip'
  IP_TRACE=$(curl --retry 2 -ksm5 $INTERFACE_SOCK5 https://www.cloudflare.com/cdn-cgi/trace | awk -F '=' '/^warp=/{print $NF}')
  if [ -n "$IP_TRACE" ]; then
    [ "$IS_UNINSTALL" = 'is_uninstall' ] && local API_IP=$(curl -$CHECK_46 --retry 2 -ksm5 --user-agent Mozilla https://api.ip.sb/ip) || local API_IP=$(curl --retry 2 -ksm5 $INTERFACE_SOCK5 --user-agent Mozilla $CHOOSE_IP_API | sed 's/.*"ip":"\([^"]\+\)".*/\1/')
    [[ -n "$API_IP" && ! "$API_IP" =~ error[[:space:]]+code:[[:space:]]+1015 ]] && local IP_JSON=$(curl --retry 2 -ksm5 https://ip.forvps.gq/${API_IP}${IS_CHINESE}) || unset IP_JSON
    IP_JSON=${IP_JSON:-"$(curl --retry 3 -ks${CHECK_46}m5 $INTERFACE_SOCK5 --user-agent Mozilla https://ifconfig.co/json)"}

    if [ -n "$IP_JSON" ]; then
      local WAN=$(sed -En 's/.*"(ip|query)":[ ]*"([^"]+)".*/\2/p' <<< "$IP_JSON")
      local COUNTRY=$(sed -En 's/.*"country":[ ]*"([^"]+)".*/\1/p' <<< "$IP_JSON")
      local ASNORG=$(sed -En 's/.*"(isp|asn_org)":[ ]*"([^"]+)".*/\2/p' <<< "$IP_JSON")
    fi
  fi

  echo -e "trace=$IP_TRACE@\nip=$WAN@\ncountry=$COUNTRY@\nasnorg=$ASNORG\n"
}

# 根据场景传参调用自定义 IP api
ip_case() {
  local CHECK_46="$1"
  [ -n "$2" ] && local CHECK_TYPE="$2"
  [ "$3" = 'non-global' ] && local CHECK_NONGLOBAL='warp'

  if [ "$CHECK_TYPE" = "warp" ]; then
    fetch_4() {
      unset IP_RESULT4 COUNTRY4 ASNORG4 TRACE4 IS_UNINSTALL
      local IS_UNINSTALL=${IS_UNINSTALL:-"$1"}
      local IP_RESULT4=$(ip_info 4 "$CHECK_NONGLOBAL" "$IS_UNINSTALL")
      TRACE4=$(expr "$IP_RESULT4" : '.*trace=\([^@]*\).*')
      WAN4=$(expr "$IP_RESULT4" : '.*ip=\([^@]*\).*')
      COUNTRY4=$(expr "$IP_RESULT4" : '.*country=\([^@]*\).*')
      ASNORG4=$(expr "$IP_RESULT4" : '.*asnorg=\([^@]*\).*')
    }

    fetch_6() {
      unset IP_RESULT6 COUNTRY6 ASNORG6 TRACE6 IS_UNINSTALL
      local IS_UNINSTALL=${IS_UNINSTALL:-"$1"}
      local IP_RESULT6=$(ip_info 6 "$CHECK_NONGLOBAL" "$IS_UNINSTALL")
      TRACE6=$(expr "$IP_RESULT6" : '.*trace=\([^@]*\).*')
      WAN6=$(expr "$IP_RESULT6" : '.*ip=\([^@]*\).*')
      COUNTRY6=$(expr "$IP_RESULT6" : '.*country=\([^@]*\).*')
      ASNORG6=$(expr "$IP_RESULT6" : '.*asnorg=\([^@]*\).*')
    }

    case "$CHECK_46" in
      4|6 )
        fetch_$CHECK_46
        ;;
      d )
        # 如在非全局模式，根据 AllowedIPs 的 v4、v6 情况再查 ip 信息；如在全局模式下则全部查
        if [ -e /etc/wireguard/warp.conf ] && grep -q '^Table' /etc/wireguard/warp.conf; then
          grep -q "^#.*0\.\0\/0" 2>/dev/null /etc/wireguard/warp.conf || fetch_4
          grep -q "^#.*\:\:\/0" 2>/dev/null /etc/wireguard/warp.conf || fetch_6
        else
          fetch_4
          fetch_6
        fi
        ;;
      u )
        # 卸载的话，使用不同的 IP api
        fetch_4 is_uninstall
        fetch_6 is_uninstall
    esac
  elif [ "$CHECK_TYPE" = "wireproxy" ]; then
    fetch_4() {
      unset IP_RESULT4 WIREPROXY_TRACE4 WIREPROXY_WAN4 WIREPROXY_COUNTRY4 WIREPROXY_ASNORG4 ACCOUNT QUOTA AC
      local IP_RESULT4=$(ip_info 4 "$WIREPROXY_PORT")
      WIREPROXY_TRACE4=$(expr "$IP_RESULT4" : '.*trace=\([^@]*\).*')
      WIREPROXY_WAN4=$(expr "$IP_RESULT4" : '.*ip=\([^@]*\).*')
      WIREPROXY_COUNTRY4=$(expr "$IP_RESULT4" : '.*country=\([^@]*\).*')
      WIREPROXY_ASNORG4=$(expr "$IP_RESULT4" : '.*asnorg=\([^@]*\).*')
    }

    fetch_6() {
      unset IP_RESULT6 WIREPROXY_TRACE6 WIREPROXY_WAN6 WIREPROXY_COUNTRY6 WIREPROXY_ASNORG6 ACCOUNT QUOTA AC
      local IP_RESULT6=$(ip_info 6 "$WIREPROXY_PORT")
      WIREPROXY_TRACE6=$(expr "$IP_RESULT6" : '.*trace=\([^@]*\).*')
      WIREPROXY_WAN6=$(expr "$IP_RESULT6" : '.*ip=\([^@]*\).*')
      WIREPROXY_COUNTRY6=$(expr "$IP_RESULT6" : '.*country=\([^@]*\).*')
      WIREPROXY_ASNORG6=$(expr "$IP_RESULT6" : '.*asnorg=\([^@]*\).*')
    }

    unset WIREPROXY_SOCKS5 WIREPROXY_PORT
    WIREPROXY_SOCKS5=$(ss -nltp | awk '/"wireproxy"/{print $4}')
    WIREPROXY_PORT=$(cut -d: -f2 <<< "$WIREPROXY_SOCKS5")

    case "$CHECK_46" in
      4|6 )
        fetch_$CHECK_46
        WIREPROXY_ACCOUNT=' Free' && [ "$(eval echo "\$WIREPROXY_TRACE$CHECK_46")" = plus ] && [ -s /etc/wireguard/info.log ] && WIREPROXY_ACCOUNT=' Teams' && grep -sq 'Device name' /etc/wireguard/info.log && WIREPROXY_ACCOUNT='+' && check_quota warp
        ;;
      d )
        fetch_4
        fetch_6
        WIREPROXY_ACCOUNT=' Free' && [[ "$WIREPROXY_TRACE4$WIREPROXY_TRACE6" =~ 'plus' ]] && [ -s /etc/wireguard/info.log ] && WIREPROXY_ACCOUNT=' Teams' && grep -sq 'Device name' /etc/wireguard/info.log && WIREPROXY_ACCOUNT='+' && check_quota warp
    esac
  elif [ "$CHECK_TYPE" = "client" ]; then
    fetch_4(){
      unset IP_RESULT4 CLIENT_TRACE4 CLIENT_WAN4 CLIENT_COUNTRY4 CLIENT_ASNORG4 CLIENT_ACCOUNT QUOTA CLIENT_AC
      local IP_RESULT4=$(ip_info 4 "$CLIENT_PORT")
      CLIENT_TRACE4=$(expr "$IP_RESULT4" : '.*trace=\([^@]*\).*')
      CLIENT_WAN4=$(expr "$IP_RESULT4" : '.*ip=\([^@]*\).*')
      CLIENT_COUNTRY4=$(expr "$IP_RESULT4" : '.*country=\([^@]*\).*')
      CLIENT_ASNORG4=$(expr "$IP_RESULT4" : '.*asnorg=\([^@]*\).*')
    }

    fetch_6(){
      unset IP_RESULT6 CLIENT_TRACE6 CLIENT_WAN6 CLIENT_COUNTRY6 CLIENT_ASNORG6 CLIENT_ACCOUNT QUOTA CLIENT_AC
      local IP_RESULT6=$(ip_info 6 "$CLIENT_PORT")
      CLIENT_TRACE6=$(expr "$IP_RESULT6" : '.*trace=\([^@]*\).*')
      CLIENT_WAN6=$(expr "$IP_RESULT6" : '.*ip=\([^@]*\).*')
      CLIENT_COUNTRY6=$(expr "$IP_RESULT6" : '.*country=\([^@]*\).*')
      CLIENT_ASNORG6=$(expr "$IP_RESULT6" : '.*asnorg=\([^@]*\).*')
    }

    unset CLIENT_SOCKS5 CLIENT_PORT
    CLIENT_SOCKS5=$(ss -nltp | awk '/"warp-svc"/{print $4}')
    CLIENT_PORT=$(cut -d: -f2 <<< "$CLIENT_SOCKS5")

    case "$CHECK_46" in
      4|6 )
        fetch_$CHECK_46
        CLIENT_AC=' Free'
        local CLIENT_ACCOUNT=$(warp-cli --accept-tos registration show 2>/dev/null | awk  '/type/{print $3}')
        [ "$CLIENT_ACCOUNT" = Limited ] && CLIENT_AC='+' && check_quota client
        ;;
      d )
        fetch_4
        fetch_6
        CLIENT_AC=' Free'
        local CLIENT_ACCOUNT=$(warp-cli --accept-tos registration show 2>/dev/null | awk  '/type/{print $3}')
        [ "$CLIENT_ACCOUNT" = Limited ] && CLIENT_AC='+' && check_quota client
    esac
  elif [ "$CHECK_TYPE" = "is_luban" ]; then
    fetch_4(){
      unset IP_RESULT4 CFWARP_COUNTRY4 CFWARP_ASNORG4 CFWARP_TRACE4 CFWARP_WAN4 CLIENT_ACCOUNT QUOTA CLIENT_AC
      local IP_RESULT4=$(ip_info 4 CloudflareWARP)
      CFWARP_TRACE4=$(expr "$IP_RESULT4" : '.*trace=\([^@]*\).*')
      CFWARP_WAN4=$(expr "$IP_RESULT4" : '.*ip=\([^@]*\).*')
      CFWARP_COUNTRY4=$(expr "$IP_RESULT4" : '.*country=\([^@]*\).*')
      CFWARP_ASNORG4=$(expr "$IP_RESULT4" : '.*asnorg=\([^@]*\).*')
    }

    fetch_6(){
      unset IP_RESULT6 CFWARP_COUNTRY6 CFWARP_ASNORG6 CFWARP_TRACE6 CFWARP_WAN6 CLIENT_ACCOUNT QUOTA CLIENT_AC
      local IP_RESULT6=$(ip_info 6 CloudflareWARP)
      CFWARP_TRACE6=$(expr "$IP_RESULT6" : '.*trace=\([^@]*\).*')
      CFWARP_WAN6=$(expr "$IP_RESULT6" : '.*ip=\([^@]*\).*')
      CFWARP_COUNTRY6=$(expr "$IP_RESULT6" : '.*country=\([^@]*\).*')
      CFWARP_ASNORG6=$(expr "$IP_RESULT6" : '.*asnorg=\([^@]*\).*')
    }

    case "$CHECK_46" in
      4|6 )
        fetch_$CHECK_46
        ;;
      d )
        fetch_4
        fetch_6
        local CLIENT_ACCOUNT=$(warp-cli --accept-tos registration show 2>/dev/null | awk  '/type/{print $3}')
        [ "$CLIENT_ACCOUNT" = Limited ] && CLIENT_AC='+' && check_quota client
    esac
  fi
}

# 帮助说明
help() { hint " $(text 6) "; }

# IPv4 / IPv6 优先设置
stack_priority() {
  [ "$OPTION" = s ] && case "$PRIORITY_SWITCH" in
    4 )
      PRIORITY=1
      ;;
    6 )
      PRIORITY=2
      ;;
    d )
      :
      ;;
    * )
      hint "\n $(text 105) \n" && reading " $(text 50) " PRIORITY
  esac

  [ -e /etc/gai.conf ] && sed -i '/^precedence \:\:ffff\:0\:0/d;/^label 2002\:\:\/16/d' /etc/gai.conf
  case "$PRIORITY" in
    1 )
      echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
      ;;
    2 )
      echo "label 2002::/16   2" >> /etc/gai.conf
      ;;
  esac
}

# IPv4 / IPv6 优先结果
result_priority() {
  PRIO=(0 0)
  if [ -e /etc/gai.conf ]; then
    grep -qsE "^precedence[ ]+::ffff:0:0/96[ ]+100" /etc/gai.conf && PRIO[0]=1
    grep -qsE "^label[ ]+2002::/16[ ]+2" /etc/gai.conf && PRIO[1]=1
  fi
  case "${PRIO[*]}" in
    '1 0' )
      PRIO=4
      ;;
    '0 1' )
      PRIO=6
      ;;
    * )
      [[ "$(curl -ksm8 --user-agent Mozilla https://www.cloudflare.com/cdn-cgi/trace | awk -F '=' '/^ip/{print $NF}')" =~ ^([0-9]{1,3}\.){3} ]] && PRIO=4 || PRIO=6
  esac
  PRIORITY_NOW=$(text 97)

  # 如是快捷方式切换优先级别的话，显示结果
  [ "$OPTION" = s ] && hint "\n $PRIORITY_NOW \n"
}

# 更换 Netflix IP 时确认期望区域
input_region() {
  [ -n "$NF" ] && REGION=$(curl --user-agent "${UA_Browser}" -$NF $GLOBAL -fs --max-time 10 --write-out "%{redirect_url}" --output /dev/null "https://www.netflix.com/title/$REGION_TITLE" | sed 's/.*com\/\([^-/]\{1,\}\).*/\1/g')
  [ -n "$WIREPROXY_PORT" ] && REGION=$(curl --user-agent "${UA_Browser}" -sx socks5h://127.0.0.1:$WIREPROXY_PORT -fs --max-time 10 --write-out "%{redirect_url}" --output /dev/null "https://www.netflix.com/title/$REGION_TITLE" | sed 's/.*com\/\([^-/]\{1,\}\).*/\1/g')
  [ -n "$INTERFACE" ] && REGION=$(curl --user-agent "${UA_Browser}" $INTERFACE -fs --max-time 10 --write-out "%{redirect_url}" --output /dev/null "https://www.netflix.com/title/$REGION_TITLE" | sed 's/.*com\/\([^-/]\{1,\}\).*/\1/g')
  REGION=${REGION:-'US'}
  reading " $(text 56) " EXPECT
  until [[ -z "$EXPECT" || "${EXPECT,,}" = 'y' || "${EXPECT,,}" =~ ^[a-z]{2}$ ]]; do
    reading " $(text 56) " EXPECT
  done
  [[ -z "$EXPECT" || "${EXPECT,,}" = 'y' ]] && EXPECT="${REGION^^}"
}

# 使用 wgcf 注册新 WARP 账户
register_warp_account() {
    info "正在使用 wgcf 注册新账户..."
    # Make sure wgcf is available and executable
    WGCF_PATH="./wgcf/wgcf_2.2.27_linux_$ARCHITECTURE"
    if [ ! -f "$WGCF_PATH" ]; then
        # Fallback for different arch
        WGCF_PATH="./wgcf/wgcf_2.2.27_linux_amd64"
        if [ ! -f "$WGCF_PATH" ]; then
            error "wgcf 可执行文件未找到!"
            return 1
        fi
    fi
    chmod +x "$WGCF_PATH"

    # Register and generate profile
    "$WGCF_PATH" register --accept-tos >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        error "wgcf 注册失败。"
        return 1
    fi
    "$WGCF_PATH" generate >/dev/null 2>&1

    # Extract new private key and address from wgcf-profile.conf
    NEW_PRIVATE_KEY=$(grep 'PrivateKey' wgcf-profile.conf | cut -d' ' -f3)
    NEW_ADDRESS=$(grep 'Address' wgcf-profile.conf | cut -d' ' -f3 | sed -n '2p') # Get the IPv6 address

    if [ -z "$NEW_PRIVATE_KEY" ] || [ -z "$NEW_ADDRESS" ]; then
        error "从 wgcf 配置文件中提取信息失败。"
        rm -f wgcf-profile.conf wgcf-account.toml
        return 1
    fi

    # Update the main warp.conf
    sed -i "s#^\(PrivateKey[ ]*=[ ]*\).*#\1$NEW_PRIVATE_KEY#" /etc/wireguard/warp.conf
    sed -i "s#^\(Address[ ]*=[ ]*\).*/128#\1$NEW_ADDRESS#" /etc/wireguard/warp.conf

    # Clean up
    rm -f wgcf-profile.conf wgcf-account.toml

    info "新 WARP 账户注册并配置成功。"
    return 0
}

# 更换支持 Netflix WARP IP 改编自 [luoxue-bot] 的成熟作品，地址[https://github.com/luoxue-bot/warp_auto_change_ip]
change_ip() {
    # --- Service Management Functions ---
    install_service() {
        local tests_to_run_str="$1"
        local nf_version="$2"
        local warp_mode="$3"

        info "正在安装后台服务..."
        cat > /etc/warp-ip-updater.conf << EOF
# WARP IP Updater Configuration
CHECK_SERVICES="$tests_to_run_str"
IP_VERSION="$nf_version"
WARP_MODE="$warp_mode"
EOF

        cat > /etc/systemd/system/warp-ip-updater.service << EOF
[Unit]
Description=WARP IP Auto-Updater for Stream Media
After=network.target
[Service]
ExecStart=/usr/bin/warp_ip_updater.sh
Restart=always
RestartSec=10
User=root
[Install]
WantedBy=multi-user.target
EOF
        chmod +x /usr/bin/warp_ip_updater.sh
        systemctl daemon-reload
        systemctl enable --now warp-ip-updater.service
        info "服务安装并启动成功！"
        info "使用 'warp i' 菜单可管理此服务。"
    }

    uninstall_service() {
        info "正在卸载后台服务..."
        systemctl disable --now warp-ip-updater.service >/dev/null 2>&1
        rm -f /etc/systemd/system/warp-ip-updater.service /etc/warp-ip-updater.conf /usr/bin/warp_ip_updater.sh
        systemctl daemon-reload
        info "服务已卸载。"
    }

    # --- Main Logic ---
    if systemctl is-active --quiet warp-ip-updater.service; then
        hint "\n后台自动刷新服务正在运行中。"
        hint " 1. 查看服务状态"
        hint " 2. 查看服务日志 (按 Ctrl+C 退出)"
        hint " 3. 停止并卸载服务"
        hint " 0. 返回"
        reading " $(text 50) " service_choice
        case "$service_choice" in
            1) systemctl status warp-ip-updater.service ;;
            2) journalctl -u warp-ip-updater.service -f ;;
            3) uninstall_service ;;
            *) return ;;
        esac
        return
    fi

    ip_start=$(date +%s)
    
    # --- One-time execution wrapper ---
    run_one_time_check() {
        local warp_mode="$1"
        local change_func_name="$2"
        
        local tests_to_run=(); local all_tests=("Netflix" "Disney+" "ChatGPT" "YouTube" "Amazon" "Spotify")
        hint "\n 请选择要测试解锁的流媒体服务 (可多选, e.g., '1 2 5', 回车则全选):"; for i in "${!all_tests[@]}"; do hint " $((i+1)). ${all_tests[i]}"; done
        reading " 您的选择: " user_choices
        if [ -z "$user_choices" ]; then tests_to_run=("${all_tests[@]}"); else for choice in $user_choices; do if [[ "$choice" =~ ^[1-6]$ ]]; then tests_to_run+=("${all_tests[$((choice-1))]}"); fi; done; fi
        if [ ${#tests_to_run[@]} -eq 0 ]; then warning " 无效选择，将测试所有服务。"; tests_to_run=("${all_tests[@]}"); fi
        
        info "\n 将测试: ${tests_to_run[*]}"
        
        # Call the specific change function, passing the tests to run as arguments
        $change_func_name "${tests_to_run[@]}"
        
        # After a successful run, ask about installing the service
        if $all_passed; then
            info "成功找到可用 IP！"
            reading "是否需要开启后台自动刷新服务以保持解锁状态? [y/N]: " install_confirm
            if [[ "${install_confirm,,}" = "y" ]]; then
                local tests_str=$(IFS=,; echo "${tests_to_run[*]}")
                install_service "$tests_str" "$NF" "$warp_mode"
            fi
        fi
    }

    # --- Mode-specific change logic ---
    change_warp_logic() {
        local -a tests_to_run=("${@}")
        unset T4 T6; grep -q "^#.*0\.\0\/0" 2>/dev/null /etc/wireguard/warp.conf && T4=0 || T4=1; grep -q "^#.*\:\:\/0" 2>/dev/null /etc/wireguard/warp.conf && T6=0 || T6=1
        case "$T4$T6" in 01) NF='6' ;; 10) NF='4' ;; 11) hint "\n $(text 124) \n"; reading " $(text 50) " NETFLIX; NF='4'; [ "$NETFLIX" = 2 ] && NF='6' ;; esac
        i=0; j=10
        all_passed=false
        while true; do
            (( i++ )); [ "$i" -gt 10 ] && { all_passed=false; error "尝试10次后仍然失败。"; break; }
            ip_case "$NF" warp; WAN=$(eval echo \$WAN$NF); COUNTRY=$(eval echo \$COUNTRY$NF); ASNORG=$(eval echo \$ASNORG$NF)
            info "\n[Attempt ${i}] Testing IP: $WAN ($COUNTRY - $ASNORG)"
            echo "Current IP: $WAN"
            comprehensive_unlock_test "" "$NF" "${tests_to_run[*]}"
            if $all_passed; then
                break
            else
                info "解锁失败，正在更换 IP..."
                wg-quick down warp >/dev/null 2>&1
                register_warp_account
                wg-quick up warp >/dev/null 2>&1
                sleep $j
            fi
        done
    }

    change_client_logic() {
        local -a tests_to_run=("${@}")
        hint "\n $(text 124) \n"; reading " $(text 50) " NETFLIX; NF='4'; [ "$NETFLIX" = 2 ] && NF='6'
        i=0; j=10
        all_passed=false
        while true; do
            (( i++ )); [ "$i" -gt 10 ] && { all_passed=false; error "尝试10次后仍然失败。"; break; }
            local client_mode_check=$(warp-cli --accept-tos settings | awk '/Mode:/{print $(i+1)}')
            local proxy_arg=""; if [ "$client_mode_check" = 'WarpProxy' ]; then ip_case "$NF" client; WAN=$(eval echo "\$CLIENT_WAN$NF"); COUNTRY=$(eval echo "\$CLIENT_COUNTRY$NF"); ASNORG=$(eval echo "\$CLIENT_ASNORG$NF"); proxy_arg="$CLIENT_PORT"; else ip_case "$NF" is_luban; WAN=$(eval echo "\$CFWARP_WAN$NF"); COUNTRY=$(eval echo "\$CFWARP_COUNTRY$NF"); ASNORG=$(eval echo "\$CFWARP_ASNORG$NF"); fi
            info "\n[Attempt ${i}] Testing IP: $WAN ($COUNTRY - $ASNORG)"
            echo "Current IP: $WAN"
            comprehensive_unlock_test "$proxy_arg" "$NF" "${tests_to_run[*]}"
            if $all_passed; then break; else info "解锁失败，正在更换 IP..."; warp-cli --accept-tos disconnect >/dev/null 2>&1; warp-cli --accept-tos registration delete >/dev/null 2>&1; warp-cli --accept-tos registration new >/dev/null 2>&1; [ -s /etc/wireguard/license ] && warp-cli --accept-tos registration license $(cat /etc/wireguard/license) >/dev/null 2>&1; warp-cli --accept-tos connect >/dev/null 2>&1; sleep $j; fi
        done
    }

    change_wireproxy_logic() {
        local -a tests_to_run=("${@}")
        hint "\n $(text 124) \n"; reading " $(text 50) " NETFLIX; NF='4'; [ "$NETFLIX" = 2 ] && NF='6'
        i=0; j=3
        all_passed=false
        while true; do
            (( i++ )); [ "$i" -gt 10 ] && { all_passed=false; error "尝试10次后仍然失败。"; break; }
            ip_case "$NF" wireproxy; WAN=$(eval echo "\$WIREPROXY_WAN$NF"); ASNORG=$(eval echo "\$WIREPROXY_ASNORG$NF"); COUNTRY=$(eval echo "\$WIREPROXY_COUNTRY$NF")
            info "\n[Attempt ${i}] Testing IP: $WAN ($COUNTRY - $ASNORG)"
            echo "Current IP: $WAN"
            comprehensive_unlock_test "$WIREPROXY_PORT" "$NF" "${tests_to_run[*]}"
            if $all_passed; then break; else info "解锁失败，正在更换 IP..."; systemctl restart wireproxy; sleep $j; fi
        done
    }

    # Determine which mode is active and run the check
    INSTALL_CHECK=("wg-quick" "warp-cli" "wireproxy")
    for a in ${!INSTALL_CHECK[@]}; do [ -x "$(type -p ${INSTALL_CHECK[a]})" ] && INSTALL_RESULT[a]=1 || INSTALL_RESULT[a]=0; done
    
    if [ "${INSTALL_RESULT[0]}" -eq 1 ]; then
        run_one_time_check "warp" "change_warp_logic"
    elif [ "${INSTALL_RESULT[1]}" -eq 1 ]; then
        run_one_time_check "client" "change_client_logic"
    elif [ "${INSTALL_RESULT[2]}" -eq 1 ]; then
        run_one_time_check "wireproxy" "change_wireproxy_logic"
    else
        error "未检测到任何 WARP 安装。"
    fi
}

# 安装BBR
bbrInstall() {
  echo -e "\n==============================================================\n"
  info " $(text 47) "
  echo -e "\n==============================================================\n"
  hint " 1. $(text 48) "
  [ "$OPTION" != b ] && hint " 0. $(text 49) \n" || hint " 0. $(text 76) \n"
  reading " $(text 50) " BBR
  case "$BBR" in
    1 )
      wget --no-check-certificate -N "${GH_PROXY}https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
      ;;
    0 )
      [ "$OPTION" != b ] && menu || exit
      ;;
    * )
      warning " $(text 51) [0-1]"; sleep 1; bbrInstall
  esac
}

# 关闭 WARP 网络接口，并删除 WARP
uninstall() {
  unset IP4 IP6 WAN4 WAN6 COUNTRY4 COUNTRY6 ASNORG4 ASNORG6

  # 卸载 WARP
  uninstall_warp() {
    wg-quick down warp >/dev/null 2>&1
    systemctl disable --now wg-quick@warp >/dev/null 2>&1; sleep 3
    [ -x "$(type -p rpm)" ] && rpm -e wireguard-tools 2>/dev/null
    systemctl restart systemd-resolved >/dev/null 2>&1; sleep 3
    warp_api "cancel" "/etc/wireguard/warp-account.conf" >/dev/null 2>&1
    rm -rf /usr/bin/wireguard-go /usr/bin/warp /etc/dnsmasq.d/warp.conf /usr/bin/wireproxy /etc/local.d/warp.start
    [ -e /etc/gai.conf ] && sed -i '/^precedence \:\:ffff\:0\:0/d;/^label 2002\:\:\/16/d' /etc/gai.conf
    [ -e /usr/bin/tun.sh ] && rm -f /usr/bin/tun.sh
    [ -e /etc/crontab ] && sed -i '/tun.sh/d' /etc/crontab
    [ -e /etc/iproute2/rt_tables ] && sed -i "/250   warp/d" /etc/iproute2/rt_tables
    [ -e /etc/resolv.conf.origin ] && mv -f /etc/resolv.conf.origin /etc/resolv.conf
  }

  # 卸载 Linux Client
  uninstall_client() {
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    warp-cli --accept-tos registration delete >/dev/null 2>&1
    rule_del >/dev/null 2>&1
    ${PACKAGE_UNINSTALL[int]} cloudflare-warp 2>/dev/null
    systemctl disable --now warp-svc >/dev/null 2>&1
    rm -rf /usr/bin/wireguard-go /usr/bin/warp $HOME/.local/share/warp /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg /etc/apt/sources.list.d/cloudflare-client.list /etc/yum.repos.d/cloudflare-warp.repo
  }

  # 卸载 Wireproxy
  uninstall_wireproxy() {
    if [ "$SYSTEM" = Alpine ]; then
      rc-update del wireproxy default
      rc-service wireproxy stop >/dev/null 2>&1
      rm -f /etc/init.d/wireproxy
    else
      systemctl disable --now wireproxy
    fi

    warp_api "cancel" "/etc/wireguard/warp-account.conf" >/dev/null 2>&1
    rm -rf /usr/bin/wireguard-go /usr/bin/warp /etc/dnsmasq.d/warp.conf /usr/bin/wireproxy /lib/systemd/system/wireproxy.service
    [ -e /etc/gai.conf ] && sed -i '/^precedence \:\:ffff\:0\:0/d;/^label 2002\:\:\/16/d' /etc/gai.conf
    [ -e /usr/bin/tun.sh ] && rm -f /usr/bin/tun.sh && sed -i '/tun.sh/d' /etc/crontab
  }

  # 如已安装 warp_unlock 项目，先行卸载
  [ -e /usr/bin/warp_unlock.sh ] && bash <(curl -sSL https://gitlab.com/fscarmen/warp_unlock/-/raw/main/unlock.sh) -U -$L

  # 根据已安装情况执行卸载任务并显示结果
  UNINSTALL_CHECK=("wg-quick" "warp-cli" "wireproxy")
  UNINSTALL_DO=("uninstall_warp" "uninstall_client" "uninstall_wireproxy")
  UNINSTALL_DEPENDENCIES=("wireguard-tools openresolv " "" " openresolv ")
  UNINSTALL_NOT_ARCH=("wireguard-dkms " "" "wireguard-dkms resolvconf ")
  UNINSTALL_DNSMASQ=("ipset dnsmasq resolvconf ")
  UNINSTALL_RESULT=("$(text 117)" "$(text 119)" "$(text 98)")
  for i in ${!UNINSTALL_CHECK[@]}; do
    [ -x "$(type -p ${UNINSTALL_CHECK[i]})" ] && UNINSTALL_DO_LIST[i]=1 && UNINSTALL_DEPENDENCIES_LIST+=${UNINSTALL_DEPENDENCIES[i]}
    [[ $SYSTEM != "Arch" && $(dkms status 2>/dev/null) =~ wireguard ]] && UNINSTALL_DEPENDENCIES_LIST+=${UNINSTALL_NOT_ARCH[i]}
    [ -e /etc/dnsmasq.d/warp.conf ] && UNINSTALL_DEPENDENCIES_LIST+=${UNINSTALL_DNSMASQ[i]}
  done

  # 列出依赖，确认是手动还是自动卸载
  UNINSTALL_DEPENDENCIES_LIST=$(echo $UNINSTALL_DEPENDENCIES_LIST | sed "s/ /\n/g" | sort -u | paste -d " " -s)
  [ "$UNINSTALL_DEPENDENCIES_LIST" != '' ] && hint "\n $(text 79) \n" && reading " $(text 170) " CONFIRM_UNINSTALL

  # 卸载核心程序
  for i in ${!UNINSTALL_CHECK[@]}; do
    [[ "${UNINSTALL_DO_LIST[i]}" = 1 ]] && ( ${UNINSTALL_DO[i]}; info " ${UNINSTALL_RESULT[i]} " )
  done

  # 删除本脚本安装在 /etc/wireguard/ 下的所有文件，如果删除后目录为空，一并把目录删除
  rm -f /usr/bin/wg-quick.{origin,reserved}
  rm -f /tmp/{best_mtu,best_endpoint,wireguard-go-*}
  rm -f /etc/wireguard/{wgcf-account.conf,warp-temp.conf,warp-account.conf,warp_unlock.sh,warp.conf.bak,warp.conf,up,proxy.conf.bak,proxy.conf,menu.sh,license,language,info-temp.log,info.log,down,account-temp.conf,NonGlobalUp.sh,NonGlobalDown.sh}
  [[ -e /etc/wireguard && -z "$(ls -A /etc/wireguard/)" ]] && rmdir /etc/wireguard

  # 选择自动卸载依赖执行以下
  [[ "$UNINSTALL_DEPENDENCIES_LIST" != '' && "${CONFIRM_UNINSTALL,,}" = 'y' ]] && ( ${PACKAGE_UNINSTALL[int]} $UNINSTALL_DEPENDENCIES_LIST 2>/dev/null; info " $(text 171) \n" )

  # 显示卸载结果
  systemctl restart systemd-resolved >/dev/null 2>&1; sleep 3
  ip_case u warp
  info " $(text 45)\n IPv4: $WAN4 $COUNTRY4 $ASNORG4\n IPv6: $WAN6 $COUNTRY6 $ASNORG6 "
}

# 同步脚本至最新版本
ver() {
  mkdir -p /tmp; rm -f /tmp/menu.sh
  wget -O /tmp/menu.sh https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh
  if [ -s /tmp/menu.sh ]; then
    mv /tmp/menu.sh /etc/wireguard/
    chmod +x /etc/wireguard/menu.sh
    ln -sf /etc/wireguard/menu.sh /usr/bin/warp
    info " $(text 64):$(grep ^VERSION /etc/wireguard/menu.sh | sed "s/.*=//g")  $(text 18):$(grep "${L}\[1\]" /etc/wireguard/menu.sh | cut -d \" -f2) "
  else
    error " $(text 65) "
  fi
  exit
}

# 由于warp bug，有时候获取不了ip地址，加入刷网络脚本手动运行，并在定时任务加设置 VPS 重启后自动运行,i=当前尝试次数，j=要尝试的次数
net() {
  local NO_OUTPUT="$1"
  unset IP4 IP6 WAN4 WAN6 COUNTRY4 COUNTRY6 ASNORG4 ASNORG6 WARPSTATUS4 WARPSTATUS6 TYPE QUOTA
  [ ! -x "$(type -p wg-quick)" ] && error " $(text 10) "
  [ ! -e /etc/wireguard/warp.conf ] && error " $(text 190) "
  local i=1; local j=5
  hint " $(text 11)\n $(text 12) "
  [ "$SYSTEM" != Alpine ] && [[ $(systemctl is-active wg-quick@warp) != 'active' ]] && wg-quick down warp >/dev/null 2>&1
  ${SYSTEMCTL_START[int]} >/dev/null 2>&1
  wg-quick up warp >/dev/null 2>&1
  ss -nltp | grep dnsmasq >/dev/null 2>&1 && systemctl restart dnsmasq >/dev/null 2>&1

  PING6='ping -6' && [ -x "$(type -p ping6)" ] && PING6='ping6'
  LAN4=$(ip route get 192.168.193.10 2>/dev/null | awk '{for (i=0; i<NF; i++) if ($i=="src") {print $(i+1)}}')
  LAN6=$(ip route get 2606:4700:d0::a29f:c001 2>/dev/null | awk '{for (i=0; i<NF; i++) if ($i=="src") {print $(i+1)}}')
  if [[ $(ip link show | awk -F': ' '{print $2}') =~ warp ]]; then
    grep -q '#Table' /etc/wireguard/warp.conf && GLOBAL_OR_NOT="$(text 184)" || GLOBAL_OR_NOT="$(text 185)"
    if grep -q '^AllowedIPs.*:\:\/0' 2>/dev/null /etc/wireguard/warp.conf; then
      local NET_6_NONGLOBAL=1
      ip_case 6 warp non-global
    else
      [[ "$LAN6" =~ ^[a-f0-9:]{1,}$ ]] && $PING6 -c2 -w10 2606:4700:d0::a29f:c001 >/dev/null 2>&1 && local NET_6_NONGLOBAL=0 && ip_case 6 warp
    fi
    if grep -q '^AllowedIPs.*0\.\0\/0' 2>/dev/null /etc/wireguard/warp.conf; then
      local NET_4_NONGLOBAL=1
      ip_case 4 warp non-global
    else
      [[ "$LAN4" =~ ^([0-9]{1,3}\.){3} ]] && ping -c2 -W3 162.159.192.1 >/dev/null 2>&1 && local NET_4_NONGLOBAL=0 && ip_case 4 warp
    fi
  else
    [[ "$LAN6" =~ ^[a-f0-9:]{1,}$ ]] && INET6=1 && $PING6 -c2 -w10 2606:4700:d0::a29f:c001 >/dev/null 2>&1 && local NET_6_NONGLOBAL=0 && ip_case 6 warp
    [[ "$LAN4" =~ ^([0-9]{1,3}\.){3} ]] && INET4=1 && ping -c2 -W3 162.159.192.1 >/dev/null 2>&1 && local NET_4_NONGLOBAL=0 && ip_case 4 warp
  fi

  until [[ "$TRACE4$TRACE6" =~ on|plus ]]; do