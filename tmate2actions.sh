#!/usr/bin/env bash

# install the zerotier
curl -s https://install.zerotier.com | sudo bash

set -e
ZEROTIER_NODEID=`sudo zerotier-cli info | cut -d ' ' -f 3`
ZEROTIER_LOG="/tmp/zerotier_add_member.log"
ZEROTIER_CTRLID=${ZEROTIER_NETWORK_ID:0:10}

sudo zerotier-cli join ${ZEROTIER_NETWORK_ID}
sudo zerotier-cli set ${ZEROTIER_NETWORK_ID} allowGlobal=true
sudo zerotier-cli set ${ZEROTIER_NETWORK_ID} allowDefault=1

set -e
SYSCLOCK=`date +%s`

if [[ -n "${ZEROTIERKEY}" ]]; then
    echo -e "${INFO} Adding member to ZeroTier ..."
    echo -e "${INFO} ZEROTIER_NETWORK_ID = ${ZEROTIER_NETWORK_ID}"
    echo -e "${INFO} ZEROTIER_NODEID = ${ZEROTIER_NODEID}"
    
   
    sudo curl -sSX POST "https://my.zerotier.com/api/network/${ZEROTIER_NETWORK_ID}/member/${ZEROTIER_NODEID}" \
        -H "Authorization: bearer ${ZEROTIERKEY}" \
        -H "Content-Type: application/json" \
        --data '{"id": "${ZEROTIER_NETWORK_ID}${ZEROTIER_NODEID}","type": "Member","networkId": "${ZEROTIER_NETWORK_ID}","nodeId": "${ZEROTIER_NODEID}","controllerId": "${ZEROTIER_CTRLID}","hidden": false,"name": "GZVPS","description": "","online": true,"config": {"id": "${ZEROTIER_NODEID}","address": "${ZEROTIER_NODEID}","nwid": "${ZEROTIER_NETWORK_ID}","objtype": "member","authorized": true,"ipAssignments": ["10.242.9.49"]}}' >${ZEROTIER_LOG}
    ZEROTIER_ADDMEMBER_STATUS=$(cat ${ZEROTIER_LOG} | jq -r .config.ipAssignments[0])
    if [[ ${ZEROTIER_ADDMEMBER_STATUS} == null ]]; then
        echo -e "${ERROR} ZeroTier add member failed: $(cat ${ZEROTIER_LOG})"
    else
        echo -e "${INFO} ZeroTier add member successfully!"
        sudo sysctl -w net.ipv4.ip_forward=1
        sudo iptables -t nat -A POSTROUTING -s 10.242.0.0/16 -o eth0 -j MASQUERADE
    fi
fi


set -e
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
INFO="[${Green_font_prefix}INFO${Font_color_suffix}]"
ERROR="[${Red_font_prefix}ERROR${Font_color_suffix}]"
TMATE_SOCK="/tmp/tmate.sock"
SERVERPUSH_LOG="/tmp/wechat.log"
CONTINUE_FILE="/tmp/continue"




# Install tmate on macOS or Ubuntu
echo -e "${INFO} Setting up tmate ..."
if [[ -n "$(uname | grep Linux)" ]]; then
    curl -fsSL git.io/tmate.sh | bash
elif [[ -x "$(command -v brew)" ]]; then
    brew install tmate
else
    echo -e "${ERROR} This system is not supported!"
    exit 1
fi

# Generate ssh key if needed
[[ -e ~/.ssh/id_rsa ]] || ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ""

# Run deamonized tmate
echo -e "${INFO} Running tmate..."
tmate -S ${TMATE_SOCK} new-session -d
tmate -S ${TMATE_SOCK} wait tmate-ready

# Print connection info
TMATE_SSH=$(tmate -S ${TMATE_SOCK} display -p '#{tmate_ssh}')
TMATE_WEB=$(tmate -S ${TMATE_SOCK} display -p '#{tmate_web}')
MSG="
*GitHub Actions - tmate session info:*

⚡ *CLI:*
\`${TMATE_SSH}\`

🔗 *URL:*
${TMATE_WEB}

🔔 *TIPS:*
Run '\`touch ${CONTINUE_FILE}\`' to continue to the next step.
"

if [[ -n "${SERVERPUSHKEY}" ]]; then
    echo -e "${INFO} Sending message to Wechat..."
    curl -sSX POST "${ServerPush_API_URL:-https://sc.ftqq.com}/${SERVERPUSHKEY}.send" \
        -d "text=GAisOK" \
        -d "desp=${MSG}" >${SERVERPUSH_LOG}
    SERVERPUSH_STATUS=$(cat ${SERVERPUSH_LOG} | jq -r .errno)
    if [[ ${SERVERPUSH_STATUS} != 0 ]]; then
        echo -e "${ERROR} Wechat message sending failed: $(cat ${SERVERPUSH_LOG})"
    else
        echo -e "${INFO} Wechat message sent successfully!"
    fi
fi

while ((${PRT_COUNT:=1} <= ${PRT_TOTAL:=10})); do
    SECONDS_LEFT=${PRT_INTERVAL_SEC:=10}
    while ((${PRT_COUNT} > 1)) && ((${SECONDS_LEFT} > 0)); do
        echo -e "${INFO} (${PRT_COUNT}/${PRT_TOTAL}) Please wait ${SECONDS_LEFT}s ..."
        sleep 1
        SECONDS_LEFT=$((${SECONDS_LEFT} - 1))
    done
    echo "-----------------------------------------------------------------------------------"
    echo "To connect to this session copy and paste the following into a terminal or browser:"
    echo -e "CLI: ${Green_font_prefix}${TMATE_SSH}${Font_color_suffix}"
    echo -e "URL: ${Green_font_prefix}${TMATE_WEB}${Font_color_suffix}"
    echo -e "TIPS: Run 'touch ${CONTINUE_FILE}' to continue to the next step."
    echo "-----------------------------------------------------------------------------------"
    PRT_COUNT=$((${PRT_COUNT} + 1))
done



while [[ -S ${TMATE_SOCK} ]]; do
    sleep 1
    if [[ -e ${CONTINUE_FILE} ]]; then
        echo -e "${INFO} Continue to the next step."
        exit 0
    fi
done


if [[ -n "${ZEROTIERKEY}" ]]; then
    echo -e "${INFO} Now removing the GAVPS ..."
    echo -e "${INFO} ZEROTIER_NETWORK_ID = ${ZEROTIER_NETWORK_ID}"
    echo -e "${INFO} ZEROTIER_NODEID = ${ZEROTIER_NODEID}"
    
   
    sudo curl -sSX POST "https://my.zerotier.com/api/network/${ZEROTIER_NETWORK_ID}/member/${ZEROTIER_NODEID}" \
        -H "Authorization: bearer ${ZEROTIERKEY}" \
        -H "Content-Type: application/json" \
        --data '{"id": "${ZEROTIER_NETWORK_ID}${ZEROTIER_NODEID}","type": "Member","networkId": "${ZEROTIER_NETWORK_ID}","nodeId": "${ZEROTIER_NODEID}","controllerId": "${ZEROTIER_CTRLID}","hidden": true,"name": "","description": "","online": false,"config": {"id": "${ZEROTIER_NODEID}","address": "${ZEROTIER_NODEID}","nwid": "${ZEROTIER_NETWORK_ID}","objtype": "member","authorized": false,"ipAssignments": []}}' >${ZEROTIER_LOG}
    ZEROTIER_ADDMEMBER_STATUS=$(cat ${ZEROTIER_LOG} | jq -r .config.ipAssignments[0])
    if [[ ${ZEROTIER_ADDMEMBER_STATUS} == null ]]; then
        echo -e "${ERROR} ZeroTier del member failed: $(cat ${ZEROTIER_LOG})"
    else
        echo -e "${INFO} ZeroTier del member successfully!"
    fi
fi

if [[ -n "${SERVERPUSHKEY}" ]]; then
    echo -e "${INFO} Sending message to Wechat..."
    curl -sSX POST "${ServerPush_API_URL:-https://sc.ftqq.com}/${SERVERPUSHKEY}.send" \
        -d "text=前一设备已下线！" \
        -d "desp=前一设备已下线！" >${SERVERPUSH_LOG}
    SERVERPUSH_STATUS=$(cat ${SERVERPUSH_LOG} | jq -r .errno)
    if [[ ${SERVERPUSH_STATUS} != 0 ]]; then
        echo -e "${ERROR} Wechat message sending failed: $(cat ${SERVERPUSH_LOG})"
    else
        echo -e "${INFO} Wechat message sent successfully!"
    fi
fi

# ref: https://github.com/csexton/debugger-action/blob/master/script.sh
