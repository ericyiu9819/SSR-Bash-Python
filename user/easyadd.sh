#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin


#Check OS
if [ -n "$(grep 'Aliyun Linux release' /etc/issue)" -o -e /etc/redhat-release ];then
OS=CentOS
[ -n "$(grep ' 7\.' /etc/redhat-release)" ] && CentOS_RHEL_version=7
[ -n "$(grep ' 6\.' /etc/redhat-release)" -o -n "$(grep 'Aliyun Linux release6 15' /etc/issue)" ] && CentOS_RHEL_version=6
[ -n "$(grep ' 5\.' /etc/redhat-release)" -o -n "$(grep 'Aliyun Linux release5' /etc/issue)" ] && CentOS_RHEL_version=5
elif [ -n "$(grep 'Amazon Linux AMI release' /etc/issue)" -o -e /etc/system-release ];then
OS=CentOS
CentOS_RHEL_version=6
elif [ -n "$(grep bian /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == 'Debian' ];then
OS=Debian
[ ! -e "$(which lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
Debian_version=$(lsb_release -sr | awk -F. '{print $1}')
elif [ -n "$(grep Deepin /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == 'Deepin' ];then
OS=Debian
[ ! -e "$(which lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
Debian_version=$(lsb_release -sr | awk -F. '{print $1}')
elif [ -n "$(grep Ubuntu /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == 'Ubuntu' -o -n "$(grep 'Linux Mint' /etc/issue)" ];then
OS=Ubuntu
[ ! -e "$(which lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
Ubuntu_version=$(lsb_release -sr | awk -F. '{print $1}')
[ -n "$(grep 'Linux Mint 18' /etc/issue)" ] && Ubuntu_version=16
else
echo "Does not support this OS, Please contact the author! "
kill -9 $$
fi


#Check Root
[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script"; exit 1; }

rand(){  
    min=$1  
    max=$(($2-$min+1))  
    num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')  
    echo $(($num%$max+$min))  
}

source /usr/local/SSR-Bash-Python/easyadd.conf

echo "你选择了添加用户"
echo ""
read -p "输入用户名： " uname
if [[ $uname == "" ]];then
	bash /usr/local/SSR-Bash-Python/user.sh || exit 0
fi
while :;do
	uport=$(rand 1000 65535)
	port=`netstat -anlt | awk '{print $4}' | sed -e '1,2d' | awk -F : '{print $NF}' | sort -n | uniq | grep "$uport"`
	if [[ -z ${port} ]];then
		break
	fi
done
read -p "输入密码： " upass
while :; do echo
	read -p "输入流量限制(只需输入数字，单位：GB)： " ut
	if [[ "$ut" =~ ^(-?|\+?)[0-9]+(\.?[0-9]+)?$ ]];then
	   break
	else
	   echo 'Input Error!'
	fi
done
if [[ ${iflimittime} == y ]]; then
	bash /usr/local/SSR-Bash-Python/timelimit.sh a ${uport} ${limit}
	datelimit=$(cat /usr/local/SSR-Bash-Python/timelimit.db | grep "${uport}:" | awk -F":" '{ print $2 }' | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9}\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1年\2月\3日 \4:/')
fi
if [[ -z ${datelimit} ]]; then
	datelimit="永久"
fi
#Set Firewalls
if [[ ${OS} =~ ^Ubuntu$|^Debian$ ]];then
	iptables-restore < /etc/iptables.up.rules
	clear
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport $uport -j ACCEPT
	iptables -I INPUT -m state --state NEW -m udp -p udp --dport $uport -j ACCEPT
	iptables-save > /etc/iptables.up.rules
fi

if [[ ${OS} == CentOS ]];then
	if [[ $CentOS_RHEL_version == 7 ]];then
		iptables-restore < /etc/iptables.up.rules
		iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport $uport -j ACCEPT
    	iptables -I INPUT -m state --state NEW -m udp -p udp --dport $uport -j ACCEPT
		iptables-save > /etc/iptables.up.rules
	else
		iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport $uport -j ACCEPT
    	iptables -I INPUT -m state --state NEW -m udp -p udp --dport $uport -j ACCEPT
		/etc/init.d/iptables save
		/etc/init.d/iptables restart
	fi
fi

#Run ShadowsocksR
echo "用户添加成功！用户信息如下："
cd /usr/local/shadowsocksr
if [[ $iflimitspeed == y ]]; then
	python mujson_mgr.py -a -u $uname -p $uport -k $upass -m $um1 -O $ux1 -o $uo1 -t $ut -S $us
else
	python mujson_mgr.py -a -u $uname -p $uport -k $upass -m $um1 -O $ux1 -o $uo1 -t $ut
fi

SSRPID=$(ps -ef | grep 'server.py m' | grep -v grep | awk '{print $2}')
if [[ $SSRPID == "" ]]; then
	if [[ ${OS} =~ ^Ubuntu$|^Debian$ ]];then
		iptables-restore < /etc/iptables.up.rules
	fi
    bash /usr/local/shadowsocksr/logrun.sh
	echo "ShadowsocksR服务器已启动"
fi

myipname=`cat /usr/local/shadowsocksr/myip.txt`
echo "你可以复制以下信息给你的用户: "
echo "===================="
echo "用户名: $uname"
echo "服务器地址: $myipname"
echo "远程端口号: $uport"
echo "本地端口号: 1080"
echo "密码: $upass"
echo "加密方法: $um1"
echo "协议: $ux1"
echo "混淆方式: $uo1"
echo "流量: $ut GB"
echo "允许连接数: 不限"
echo "帐号有效期: $datelimit"
echo "===================="
