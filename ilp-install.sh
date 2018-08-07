#!/bin/bash
# File              : ilp-install.sh
# Author            : N3TC4T <netcat.av@gmail.com>
# Date              : 16.06.2018
# Last Modified Date: 13.07.2018
# Last Modified By  : N3TC4T <netcat.av@gmail.com>
# Copyright (c) 2018 N3TC4T <netcat.av@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


# ┤┤└└┴┴┐┐││┘┘┌┌├├┬┬┼┼┴┴── ││ ▽▼△▲▵▴▾▿


set -e

########## Variable ##########
SUDO=""
BASH_C="bash -c"
SLEEP_SEC=10
LOG_OUTPUT="/tmp/${0##*/}$(date +%Y-%m-%d.%H-%M)"
CURRENT_USER="$(id -un 2>/dev/null || true)"
INSTALLATION_DIR="/srv/app/ilp-connector"
CONNECTOR_REPO="https://github.com/interledgerjs/ilp-connector.git"
########## Nodejs ##########
NODEJS_RPM_URL="https://rpm.nodesource.com/setup_10.x"
NODEJS_DEB_URL="https://deb.nodesource.com/setup_10.x"
########## Certbot ##########
CERTBOT_AUTO_URL="https://dl.eff.org/certbot-auto"
########## Constant ##########
SUPPORT_DISTRO=(debian ubuntu fedora centos)
#Color Constant
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
WHITE=`tput setaf 7`
LIGHT=`tput bold `
RESET=`tput sgr0`
#Error Message#Error Message
ERR_ROOT_PRIVILEGE_REQUIRED=(10 "This install script need root privilege, please retry use 'sudo' or root user!")
ERR_NOT_SUPPORT_DISTRO=(21 "Sorry, The installer only support centos/ubuntu/debian/fedora now.")
ERR_NOT_PUBLIC_IP=(11 "You need an public IP to run load balancer for ILP Connector!")
ERR_UNKNOWN_MSG_TYPE=98
ERR_UNKNOWN=99
# Helpers ==============================================

function display_header()
{
cat <<"EOF"


 ___ _     ____     ____                            _
|_ _| |   |  _ \   / ___|___  _ __  _ __   ___  ___| |_ ___  _ __
 | || |   | |_) | | |   / _ \| '_ \| '_ \ / _ \/ __| __/ _ \| '__|
 | || |___|  __/  | |__| (_) | | | | | | |  __/ (__| || (_) | |
|___|_____|_|      \____\___/|_| |_|_| |_|\___|\___|\__\___/|_|

Running your own ILP connector , Add redundancy and liquidity to the ILP network

++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

EOF
}

function _box () {
    str="$@"
    len=$((${#str}+4))
    for i in $(seq ${len}); do echo -n '.'; done;
    echo; echo ". "${str}" .";
    for i in $(seq ${len}); do echo -n '.'; done;
    echo
}

function spin_wait() {
  local -r SPIN_DELAY="0.1"
  local spinstr="⠏⠛⠹⠼⠶⠧"
  printf "  "
  while kill -0 $1 2>/dev/random; do
    local tmp=${spinstr#?}

    if [ -z "$2" ]; then
        printf " \b\b\b${tmp:0:1} "
    else
        printf "${cl} ${tmp:0:1} ${2}"
    fi

    local spinstr=${tmp}${spinstr%"$tmp"}
    sleep ${SPIN_DELAY}
  done
  printf "\033[3D\033[K ${LIGHT}${GREEN}Done${RESET}"
  # printf "\r\033[K"
}

function _exec() {
  local -i PID=
  local COMMAND=$1
  shift      ## Clip the first value of the $@, the rest are the options.
  local COMMAND_OPTIONS="$@"
  local COMMAND_OUTPUT=""
  echo -e "\n==================================" >> "${LOG_OUTPUT}"
  echo "${COMMAND} $COMMAND_OPTIONS" >> "${LOG_OUTPUT}"
  echo -e "==================================\n" >> "${LOG_OUTPUT}"
  exec 3>$(tty)
  eval "time ${SUDO} bash -c '${COMMAND} ${COMMAND_OPTIONS}'" >>"${LOG_OUTPUT}" 2>&1  &
  PID=$! # Set global PGID to process id of the command we just ran.
  spin_wait "${PID}"
  exec 3>&-
}

function program_is_installed {
  # set to 1 initially
  local return_=1
  # set to 0 if not found
  type $1 >/dev/null 2>&1 || { local return_=0; }
  # return value
  echo "$return_"
}

function service_is_running {
  # set to 1 initially
  local return_=0
  # set to 0 if not found
  if (( $(ps -ef | grep -v grep | grep $1 | wc -l) > 0 )) ;then
      local return_=1
  fi
  # return value
  echo "$return_"
}

function echo_if {
  if [ $1 == 1 ]; then
      echo -e "${LIGHT}${GREEN}✔ ${RESET}"
  else
      echo -e "${RED}✘${RESET}"
  fi
}

new_line() { printf "\n"; }

show_message() {
  case "$1" in
      debug)  echo -e "\n[${BLUE}DEBUG${RESET}] : $2";;
      info)   echo -e -n "\n${WHITE}$2${RESET}" ;;
      warn)   echo -e    "\n[${YELLOW}WARN${RESET}] : $2" ;;
      done|success) echo -e "${LIGHT}${GREEN}$2${RESET}" ;;
      error|failed) echo -e "[${RED}ERROR${RESET}] : $2" ;;
  esac
}

command_exist() {
  type "$@" > /dev/null 2>&1
}


get_curl() {
  CURL_C=""; USE_WGET="false"
  if (command_exist curl);then
      CURL_C='curl -SL -o '
  elif (command_exist wget);then
      USE_WGET="true"
      CURL_C='wget -O '
  fi

  echo "${USE_WGET}|${CURL_C}"
}

check_os_platform() {
  ARCH="$(uname -m)"
}
check_deps_initsystem() {
  if [[ "${LSB_DISTRO}" == "ubuntu" ]] && [[ "${LSB_CODE}" == "utopic" ]];then
      INIT_SYSTEM="sysvinit"
  elif (command_exist systemctl);then
      INIT_SYSTEM="systemd"
  else
      INIT_SYSTEM="sysvinit"
  fi
}

check_os_distro() {
  LSB_DISTRO=""; LSB_VER=""; LSB_CODE=""
  if (command_exist lsb_release);then
      LSB_DISTRO="$(lsb_release -si)"
      LSB_VER="$(lsb_release -sr)"
      LSB_CODE="$(lsb_release -sc)"
  fi
  if [[ -z "${LSB_DISTRO}" ]];then
      if [[ -r /etc/lsb-release ]];then
          LSB_DISTRO="$(. /etc/lsb-release && echo "${DISTRIB_ID}")"
          LSB_VER="$(. /etc/lsb-release && echo "${DISTRIB_RELEASE}")"
          LSB_CODE="$(. /etc/lsb-release && echo "${DISTRIB_CODENAME}")"
      elif [[ -r /etc/os-release ]];then
          LSB_DISTRO="$(. /etc/os-release && echo "$ID")"
          LSB_VER="$(. /etc/os-release && echo "$VERSION_ID")"
      elif [[ -r /etc/fedora-release ]];then
          LSB_DISTRO="fedora"
      elif [[ -r /etc/debian_version ]];then
          LSB_DISTRO="Debian"
          LSB_VER="$(cat /etc/debian_version)"
      elif [[ -r /etc/centos-release ]];then
          LSB_DISTRO="CentOS"
          LSB_VER="$(cat /etc/centos-release | cut -d' ' -f3)"
      fi
  fi
  LSB_DISTRO=$(echo "${LSB_DISTRO}" | tr '[:upper:]' '[:lower:]')
  if [[ "${LSB_DISTRO}" == "debian" ]];then
      case ${LSB_VER} in
          8) LSB_CODE="jessie";;
          7) LSB_CODE="wheezy";;
      esac
  fi

  case "${LSB_DISTRO}" in
      centos|fedora)
        CMAJOR=$( echo ${LSB_VER} | cut -d"." -f1 )
      ;;
  esac

  if [[ -z ${LSB_DISTRO} ]];then
      show_message warn "Can not detect OS type";
  fi

  if [[ ! " ${SUPPORT_DISTRO[@]} " =~ " ${LSB_DISTRO} " ]]; then
    show_message error "${ERR_NOT_SUPPORT_DISTRO[1]} , but current is ${LSB_DISTRO}(${LSB_VER})\n"
    exit ${ERR_NOT_SUPPORT_DISTRO[0]}
  fi
}

check_user() {
  if [[ "${CURRENT_USER}" != "root" ]];then
      if (command_exist sudo);then
        SUDO='sudo'
      else
        show_message error "${ERR_ROOT_PRIVILEGE_REQUIRED[1]}" && exit ${ERR_ROOT_PRIVILEGE_REQUIRED[0]}
      fi
      show_message info "${WHITE}Hint: This installer need root privilege\n"
      ${SUDO} echo -e "\n"
  fi
}

set_y() {
    exec < /dev/tty
    oldstty=$(stty -g)
    stty raw -echo min 0
    echo -en "\033[6n" > /dev/tty
    IFS=';' read -r -d R -a pos
    stty $oldstty
    Y=$((${pos[0]:2} - 1))
}

list_contains() {
    LIST="$1"
    SEEKING="$2"

    RESULT=0

    while read -r ENTRY; do
	    if [ "$ENTRY" == "$SEEKING" ]; then
		    RESULT=1
	    fi
    done <<< "${LIST:1}"

    echo $RESULT
}


_choose_refresh() {
    tput cup ${TOP} 0
    NUM=1
    #while read -r ENTRY; do
    OLDIFS="$IFS"
    IFS=$'\n' # make newlines the token breaks
    for ENTRY in ${CHOICES}; do
	    if [ $NUM -eq ${CHOICE_NUMBER} ]; then
			    tput smso; echo -e "${NUM}) ${ENTRY}"; tput rmso;
	    else
			    tput el; echo -e "${LIGHT}${NUM}] ${ENTRY}${RESET}";
	    fi
	    ((NUM++))
    done;
    IFS="$OLDIFS"
}


choose_one() {
      NUMBER_OF_CHOICES=`echo "$CHOICES" | wc -l`
      CHOICE_NUMBER=1

      OLDIFS="$IFS"
      IFS=$'\n' # make newlines the token breaks
      # print choices for the first time
      for ENTRY in "$CHOICES"; do
	      echo "$ENTRY"
      done
      IFS="$OLDIFS"

      set_y
      TOP=$((Y - NUMBER_OF_CHOICES))

      _choose_refresh

      ESC=$(echo -en "\033")                     # define ESC
      while :;do                                 # infinite loop
	      read -s -n3 KEY 2>/dev/null >&2        # read quietly three characters of input
	      if [ "$KEY" == "$ESC[A" ]; then
		      if [ $CHOICE_NUMBER -gt 1 ]; then ((CHOICE_NUMBER--)); fi;
		      _choose_refresh
	      fi

	      if [ "$KEY" == "$ESC[B" ]; then
		      if [ $CHOICE_NUMBER -lt $NUMBER_OF_CHOICES ]; then ((CHOICE_NUMBER++)); fi;
		      _choose_refresh
	      fi
	      if [ "$KEY" == "$ESCM" ]; then break; fi
      done

      CHOICE=`echo "$CHOICES" | sed -n "${CHOICE_NUMBER}p"`
}

_update_chosen() {

	CHOSEN=""
	CHOSEN_LINES=""
	for i in $(seq 0 $NUMBER_OF_CHOICES); do
		for ENTRY in $CHOSEN_NUMBERS; do
			#echo $ENTRY
			if [ "$ENTRY" == "$i" ]; then
				CHOICE_LINE=`echo "$CHOICES" | sed -n "$ENTRY"P`
				#CHOSEN_NUMBERS=$(printf "$CHOSEN_NUMBERS\n$CHOICE_NUMBER")
				CHOSEN_LINES=$(printf "$CHOSEN_LINES\n$CHOICE_LINE")
				CHOSEN="$CHOSEN $CHOICE_LINE"
				#echo "here"
			fi
		done
	done
}

choose_multiple() {

	CHOICES="$CHOICES"$'\n'">"
	NUMBER_OF_CHOICES=`echo "$CHOICES" | wc -l`

	CHOICE_NUMBER=1
	CHOSEN_NUMBERS=""

	# print choices for the first time
	OLDIFS="$IFS"
	IFS=$'\n' # make newlines the token breaks
	INDEX=1
	for ENTRY in $CHOICES; do
		echo -e "${LIGHT}${INDEX}) ${ENTRY}${RESET}"
		((INDEX++))
	done;
	IFS="$OLDIFS"

	set_y
	TOP=$((Y - NUMBER_OF_CHOICES))

	_choose_refresh

	ESC=$(echo -en "\033")                     # define ESC
	while :;do                                 # infinite loop
		read -s -n3 KEY 2>/dev/null >&2        # read quietly three characters of input
		if [ "$KEY" == "$ESC[A" ]; then
			if [ $CHOICE_NUMBER -gt 1 ]; then ((CHOICE_NUMBER--)); fi;
			_choose_refresh
		fi

		if [ "$KEY" == "$ESC[B" ]; then
			if [ $CHOICE_NUMBER -lt $NUMBER_OF_CHOICES ]; then ((CHOICE_NUMBER++)); fi;
			_choose_refresh
		fi

		if [ "$KEY" == "$ESCM" ]; then
			if [ $CHOICE_NUMBER -eq $NUMBER_OF_CHOICES ]; then
				CHOSEN_LINES="${CHOSEN_LINES:1}"
				CHOSEN="${CHOSEN:1}"

				break;
			fi;

			if [ $(list_contains "$CHOSEN_NUMBERS" "$CHOICE_NUMBER") -eq 1 ]; then
				# remove an item line
				NEW_CHOSEN_NUMBERS=""

				while read -r ENTRY; do
					if [ "$ENTRY" != "$CHOICE_NUMBER" ]; then
						NEW_CHOSEN_NUMBERS=$(printf "$NEW_CHOSEN_NUMBERS\n$ENTRY")
					fi
				done <<< "${CHOSEN_NUMBERS:1}"

				CHOSEN_NUMBERS="$NEW_CHOSEN_NUMBERS"
			else
				# add a new item line
				CHOSEN_NUMBERS=$(printf "$CHOSEN_NUMBERS\n$CHOICE_NUMBER")

			fi

			_update_chosen

			CHOICES=`echo "$CHOICES" | sed "s/>.*/>$CHOSEN/"`
			_choose_refresh
		fi
	done

	CHOICE=`echo "$CHOICES" | sed -n "${CHOICE_NUMBER}p"`

}

# ============================================== Helpers



################### LOAD BALANCER ###########################

load_balancer()
{

  IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
  # If $IP is a private IP address, the server must be behind NAT
  if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
     show_message error "${ERR_NOT_PUBLIC_IP[1]}"
     exit "${ERR_NOT_PUBLIC_IP[0]}"
  fi


  show_message info "┌ Installing and Configuring Load Balancer... "
  # Hostname
  echo -e "\n│"
  echo "├ What is your ILP hostname ? "
  while true; do
    read -p "├ Hostname: " -e -i ilp.example.com HOSTNAME
    if [[ -z "$HOSTNAME" ]]; then
      show_message error "No Hostname entered , exiting ..."
    else
      break
    fi
  done

  # Email for certbot
  echo -e "│"
  echo -e "├ What is your Email address ?"
  while true; do
    read -p "├ Email: " -e EMAIL

    if [[ -z "$EMAIL" ]] || ! [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
        show_message error "Invalid Email entered, try again..."
    else
      break
    fi
  done

  # Subdomain DNS ==============================================
  echo -e "│"
  echo -e "└ Please create A records as below on your DNS :"

  new_line
  cat <<EOF
------------------------------------------------------------
$HOSTNAME.    300     IN      A       $IP
------------------------------------------------------------
EOF

  read -n1 -r -p "Press any key to continue..."

  while true; do
    if ping -c1 -W1 $HOSTNAME &> /dev/null; then
      break
    else
      show_message warn "It's look like the $HOSTNAME cannot be resolved yet , waiting 30s ... "
    fi
    sleep 30 #check again in SLEEP seconds
  done

  show_message debug "Setting hostname using 'hostnamectl'"
  # Set hostname
  ${SUDO} hostnamectl set-hostname $HOSTNAME

  # ============================================== Subdomain DNS

  # CertBOt ==============================================

  # installing certbot
  show_message info "[+] Installing CertBot... "
  if [[ "${LSB_DISTRO}" == "centos"  ]] || [[ "${LSB_DISTRO}" == "fedora"  ]] ;then
    _exec "yum -y install certbot"
  elif [[ "${LSB_DISTRO}" == "ubuntu" ]];then
    _exec "apt-get install -y certbot"
  elif [[ "${LSB_DISTRO}" == "debian" ]];then
    ${SUDO} ${CURL_C} /usr/bin/certbot ${CERTBOT_AUTO_URL} >>"${LOG_OUTPUT}" 2>&1 && ${SUDO} chmod a+x /usr/bin/certbot
    _exec "/usr/bin/certbot"
  fi

   show_message info "[+] Generating certificate for ${HOSTNAME}... "
  _exec certbot certonly --standalone --agree-tos -d "${HOSTNAME}"  --agree-tos --email "${EMAIL}"

  # ============================================== CertBOt

  # Nginx ==============================================

  show_message info "[+] Installing Nginx... "

  if [[ "${LSB_DISTRO}" == "centos"  ]] || [[ "${LSB_DISTRO}" == "fedora"  ]] ;then
    # Install Package
    # Selinux allow nginx
    # Enable access for port 443 in firewalld
    _exec "yum -y install nginx ; setsebool -P httpd_can_network_connect 1 ; firewall-cmd --zone=public --add-port=443/tcp --permanent"

  elif [[ "${LSB_DISTRO}" == "ubuntu" ]] || [[ "${LSB_DISTRO}" == "debian" ]] ;then
    # Install Package
    # Adjust the Firewall
    _exec "apt-get install -y nginx ; ufw allow 'Nginx HTTP'"

  fi

  # show_message done "[!] Success Installed Nginx"

  if [[ ! -e /etc/nginx/default.d ]]; then
	  ${SUDO} mkdir /etc/nginx/default.d
  fi

  ${SUDO} echo 'return 301 https://$host$request_uri;' | ${SUDO} tee /etc/nginx/default.d/ssl-redirect.conf >> "${LOG_OUTPUT}" 2>&1

  if [[ ! -e /etc/nginx/conf.d ]]; then
	  ${SUDO} mkdir /etc/nginx/conf.d
  fi

  ${SUDO} ${BASH_C} 'echo "
server {
    listen 443 ssl;

    ssl_certificate /etc/letsencrypt/live/$HOSTNAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$HOSTNAME/privkey.pem;

    server_name  $HOSTNAME;

    location / {
      proxy_pass http://127.0.0.1:7443;
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection '\''Upgrade'\'';

    }
}" > /etc/nginx/conf.d/ilp.conf'

  show_message info "[*] Starting Nginx... "

  if [[ "${INIT_SYSTEM}" == "systemd" ]];then
    _exec "systemctl daemon-reload; systemctl enable nginx ; systemctl restart nginx"
  else
    _exec "service nginx enable ; service nginx restart"
  fi

  new_line

}




################### INSTALL ###########################

install()
{

  local USE_WGET=$( echo $(get_curl) | awk -F"|" '{print $1}' )
  local CURL_C=$( echo $(get_curl) | awk -F"|" '{print $2}' )

  # checks for script
  check_user
  check_os_platform
  check_os_distro
  check_deps_initsystem


  show_message info "[-] I need to ask you a few questions before starting the configuring."
  show_message info "[-] You can leave the default options and just press enter if you are ok with them."
  new_line
  show_message info "┌ Configuring ILP ... "
  echo -e "\n│"
  echo "├ Choose a path to installing ILP : "
  while true; do
	  read -p "├ Path: " -e -i ${INSTALLATION_DIR} INSTALLATION_DIR
	  if [[ -z "$INSTALLATION_DIR" ]] ; then
		  show_message error "Installation path cannot be empty... "
	  else
		  break
	  fi
  done
  # ILP Address
  echo -e "│"
  echo "├ Choose a name for your ILP Connector (ex: g.n3tc4t ) :"
  while true; do
	  read -p "├ ILP Address: " -e ILP_ADDRESS
	  if [[ -z "$ILP_ADDRESS" ]] ; then
		  show_message error "ILP Address cannot be empty... "
	  else
		  break
	  fi
  done
  # Choose plugins to install ====================================
  echo -e "│"
  echo "└ Please select plugins to install : "
  new_line
  #Plugin options
  CHOICES='ilp-plugin-mini-accounts
ilp-plugin-xrp-paychan
ilp-plugin-xrp-asym-server'

  choose_multiple
  PLUGINS=${CHOSEN_LINES}


  # check if installation dir is Empty or not
  if [ -d "$INSTALLATION_DIR" ]; then
	  if [[ -n "$(ls -A ${INSTALLATION_DIR})" ]]; then
		  show_message warn "Installation directory is not empty , we need to delete it before continue ."
		  new_line
		  read -p "delete now? [y/N]: " -e DELETE

		  if [[ "$DELETE" = 'y' || "$DELETE" = 'Y' ]]; then
			  ${SUDO} ${BASH_C} "rm -rf ${INSTALLATION_DIR}"
		  else
			  exit
		  fi
	  fi
  fi

  # create installation dir
  ${SUDO} ${BASH_C} "mkdir -p ${INSTALLATION_DIR}"


  new_line
  # if user wants to continue installation
  while true; do
    read -p "[?] Do you wish to continue installation ? " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
  done


  # Repositories and required packages ====================================

  show_message info "[+] Installing required packages... "

  if [[ "${LSB_DISTRO}" == "centos" ]] && [[ "${CMAJOR}" == "7" ]];then
      _exec "rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm ; yum install -y gcc-c++ make epel-release git"
  elif [[ "${LSB_DISTRO}" == "centos" ]] && [[ "${CMAJOR}" == "6" ]];then
      _exec "rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm ; yum install -y gcc-c++ make epel-release git"
  elif [[ "${LSB_DISTRO}" == "ubuntu" ]];then
      _exec "apt-get install -y software-properties-common ; add-apt-repository ppa:certbot/certbot ; apt-get install -y build-essential git python-dev""
  elif [[ "${LSB_DISTRO}" == "debian" ]];then
      _exec "apt-get update ; apt-get install -y build-essential git python-dev""
  fi

  # Nodejs ==============================================

  show_message info "[+] Installing Nodejs... "

  if [[ "${LSB_DISTRO}" == "centos"  ]] || [[ "${LSB_DISTRO}" == "fedora"  ]] ;then
      ${SUDO} ${CURL_C} /tmp/nodejs_10.sh ${NODEJS_RPM_URL} >>"${LOG_OUTPUT}" 2>&1 && ${SUDO} chmod a+x /tmp/nodejs_10.sh
      _exec "bash /tmp/nodejs_10.sh && yum install -y nodejs"
  elif [[ "${LSB_DISTRO}" == "ubuntu" ]] || [[ "${LSB_DISTRO}" == "debian" ]] ;then
      ${SUDO} ${CURL_C} /tmp/nodejs_10.sh ${NODEJS_DEB_URL} >>"${LOG_OUTPUT}" 2>&1 && ${SUDO} chmod a+x /tmp/nodejs_10.sh
      _exec "bash /tmp/nodejs_10.sh && apt-get install -y nodejs"
  fi

  # ============================================== Nodejs

  # ILP Connect ==============================================

  # change directory
  ${SUDO} cd ${INSTALLATION_DIR}

  show_message info "[+] Installing ILP Connector... "
  _exec "git clone ${CONNECTOR_REPO} . ; npm install ; npm run build"


  # create connector data store directory
  ${SUDO} ${BASH_C} "mkdir -p ${INSTALLATION_DIR}/connector-data"


  if [[ -n "$PLUGINS" ]]; then
      show_message info "[+] Installing Plugins... "
	  _exec "npm install ${PLUGINS//$'\n'/ }"
  else
	  show_message info "[!] No Plugins to install."
  fi


  show_message info "[+] Installing PM2... "
  _exec npm install pm2@latest -g --unsafe-perm

  show_message info "[+] Installing Moneyd-GUI... "
  _exec npm install moneyd-gui@latest -g --unsafe-perm



  # ============================================== ILP Connector


  # CONFIGURE PLUGINS ==============================================

  new_line
  show_message info "┌ [ ${LIGHT}${WHITE}Configuring Plugins${RESET} ] "
  echo -e "\n│"

  if [[ " ${PLUGINS[@]} " =~ "ilp-plugin-xrp-paychan" ]]; then
      echo "├ [ ${LIGHT}${BLUE}ilp-plugin-xrp-paychan${RESET} ]"
      echo -e "│"

      # Wallet Address
      echo "├ Please enter your XRP wallet address ? "
      while true; do
        read -p "├ Address: " -e ADDRESS
        if [[ -z "$ADDRESS" ]] ; then
            show_message error "Address cannot be Empty ... "
        else
            break
        fi
      done
      echo -e "│"
      # Wallet secret
      echo "├ Please enter your XRP wallet secret"
      while true; do
        read -p "├ Secret: " -e SECRET
        if [[ -z "$SECRET" ]] || ! [[ "$SECRET" =~ ^s[a-zA-Z0-9]{28,}+$ ]] ; then
            show_message error "Invalid Secret entered, try again... "
        else
            break
        fi
      done
      echo -e "│"
      # Peer BTP URL
      echo "├ What is the BTP peer URL you wanna connect with?"
      while true; do
        read -p "├ BTP URL: " -e PEER_BTP_URL
        if [[ -z "$PEER_BTP_URL" ]] ; then
            show_message error "BTP URL cannot be Empty ... "
        else
            break
        fi
      done
      echo -e "│"
      # Peer BTP XRP address
      echo "├ What is the your BTP Peer ripple address"
      while true; do
        read -p "├ BTP Ripple Address: " -e PEER_RIPPLE_ADDRESS
        if [[ -z "$PEER_RIPPLE_ADDRESS" ]] ; then
            show_message error "BTP peer ripple address cannot be Empty ... "
        else
            break
        fi
      done
  fi

  if [[ " ${PLUGINS[@]} " =~ "ilp-plugin-xrp-asym-server" ]] && [[ -z ${ADDRESS} ]]; then

      # set asym server true to ask nginx config
      ILP_ASYM_SERVER=true

      echo "├ [ ${LIGHT}${BLUE}ilp-plugin-xrp-asym-server${RESET} ]"
      echo -e "│"
      # Wallet Address
      echo "├ Please enter your XRP wallet address ? "
      while true; do
        read -p "├ Address: " -e ADDRESS
        if [[ -z "$ADDRESS" ]] ; then
            show_message error "Address cannot be Empty ... "
        else
            break
        fi
      done
      echo -e "│"
      # Wallet secret
      echo "├ Please enter your XRP wallet secret"
      while true; do
        read -p "├ Secret: " -e SECRET
        if [[ -z "$SECRET" ]] || ! [[ "$SECRET" =~ ^s[a-zA-Z0-9]{28,}+$ ]] ; then
            show_message error "Invalid Secret entered, try again... "
        else
            break
        fi
      done
      echo -e "│"
  fi

  # create temp config file in memory

  CONFIG_TEMP=$(echo "$(mktemp)")

  ${SUDO} echo -e "'use strict'; \n\nconst path = require('path');" >> ${CONFIG_TEMP}

  if [[ -n "$ADDRESS" ]]; then
      ${SUDO} echo -e "\nconst address = '${ADDRESS}';\nconst secret = '${SECRET}';" >> ${CONFIG_TEMP}
  fi

  if [[ " ${PLUGINS[@]} " =~ "ilp-plugin-xrp-paychan" ]]; then
      ${SUDO} echo -e "
const peerPlugin = {
  relation: 'peer',
  plugin: 'ilp-plugin-xrp-paychan',
  assetCode: 'XRP',
  assetScale: 9,
  balance: {
      maximum: '10000000',
      settleThreshold: '-5000000',
      settleTo: '0'
  },
  options: {
      assetScale: 9,
      server: '${PEER_BTP_URL}',
      rippledServer: 'wss://s2.ripple.com',
      peerAddress: '${PEER_RIPPLE_ADDRESS}',
      address,
      secret
  }
};" >> ${CONFIG_TEMP}

      CONNECTOR_ACCOUNTS="peer: peerPlugin,"

  fi


  if [[ " ${PLUGINS[@]} " =~ "ilp-plugin-xrp-asym-server" ]]; then
      echo -e "
const ilspServer = {
  relation: 'child',
  plugin: 'ilp-plugin-xrp-asym-server',
  assetCode: 'XRP',
  assetScale: 6,
  options: {
      port: 7443,
      xrpServer: 'wss://s2.ripple.com',
      address,
      secret
  }
}" >> ${CONFIG_TEMP}

      CONNECTOR_ACCOUNTS+="ilsp: ilspServer,"
  fi

  if [[ " ${PLUGINS[@]} " =~ "ilp-plugin-mini-accounts" ]]; then
      echo -e "
const miniAccounts = {
  relation: 'child',
  plugin: 'ilp-plugin-mini-accounts',
  assetCode: 'XRP',
  assetScale: 9,
  options: {
      port: 7768
  }
};" >> ${CONFIG_TEMP}

      CONNECTOR_ACCOUNTS+="local: miniAccounts,"
  fi


  echo -n "
const connectorApp = {
  name: 'connector',
  env: {
      DEBUG: 'ilp*,connector*',
      CONNECTOR_ILP_ADDRESS: '${ILP_ADDRESS}',
      CONNECTOR_ENV: 'production',
      CONNECTOR_BACKEND: 'one-to-one',
      CONNECTOR_ADMIN_API: true,
      CONNECTOR_ADMIN_API_PORT: 7769,
      CONNECTOR_SPREAD: '0',
      CONNECTOR_STORE_PATH: '${INSTALLATION_DIR}/connector-data',
      CONNECTOR_ACCOUNTS: JSON.stringify({${CONNECTOR_ACCOUNTS}})
  },
  script: path.resolve(__dirname, 'src/index.js')
};

module.exports = { apps: [ connectorApp ] };" >> ${CONFIG_TEMP}

  new_line
  # edit the config file before continue
  read -p "[?] Edit config file before continue ? [y/N]: " -e EDIT_CONFIG
  if [[ "$EDIT_CONFIG" = 'y' || "$EDIT_CONFIG" = 'Y' ]]; then
      if [ -z "$EDITOR" ]; then
          EDITOR=$(which nano vi|head -n1)
          export EDITOR
      fi
      ${EDITOR} ${CONFIG_TEMP}
  fi

  ${SUDO} mv ${CONFIG_TEMP} "${INSTALLATION_DIR}/launch.config.js"

  # ============================================== CONFIGURE PLUGINS

  # START CONNECTOR ==============================================

  new_line
  read -p "[?] Start connector & moneyd-gui ? [y/N]: " -e START_PM2
  if [[ "$START_PM2" = 'y' || "$START_PM2" = 'Y' ]]; then
      show_message info "[*] Starting the connector ... "
      _exec pm2 start launch.config.js
      show_message info "[*] Starting the moneyd-gui ... "
      _exec pm2 start moneyd-gui
  else
      show_message warn "Connector is not start , you can start manually by running 'pm2 start ${INSTALLATION_DIR}/launch.config.js' command "
      show_message warn "Moneyd GUI is not start , you can start manually by running 'pm2 start moneyd-gui' command "
  fi
  new_line

  # ============================================== START CONNECTOR

  # LOAD BALANCER ==============================================

  if $ILP_ASYM_SERVER  ; then
        while true; do
            new_line
            echo -n "[-] Looks like you want to run and ILP connector [ asym server ] "
            new_line
            read -p "[?] Do you wish to install load balancer as well ? " yn
            case $yn in
              [Yy]* ) load_balancer; break;;
              [Nn]* ) break;;
              * ) echo "Please answer yes or no.";;
            esac
        done
  fi

  # ============================================== LOAD BALANCER

  # ============================================== FINISHING
  new_line
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  new_line
  show_message done "[!] Congratulations , it's look like ILP Connector installed successfully!"
  new_line
  show_message done "[-] You can monitor your connector with Moneyd-GUI : "
  show_message done "[-] running 'ssh -N -L 7770:localhost:7770 root@YOUR_IP_ADDRESS' on your local system and view http://localhost:7770 on the browser"
  new_line
  new_line
  show_message done "[-] For installation log visit $LOG_OUTPUT"
  new_line
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =

}



################### MAIN ###########################

clear
display_header
install

