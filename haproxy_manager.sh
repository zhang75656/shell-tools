#!/bin/bash

_help(){
	cat <<EOF
Usage: $0 [-ssh <HASrv1> [HASrv2]...] 	   指定要登录的HAProxy的IP,前提必须做好无密码登录!
	  [-s |--socket <HAProxySocketFile> ...]   指定HAProxy的socket文件绝对路径名,若有多个时,需要用引号引起来.
	  [-sf |--sockets-file <HAProxySocketListFile>]  指定一个包含多个socket列表的文件名.
	  [-b |--backend <BackendName>]		 	   指定要操作的后端服务器组名
	  [-l |--list [[Backend/]<srv1> [Backend/]<srvN> ...]]   显示指定server的状态,若有多个时,需要用引号引起来.[测试版]
	  [-d |--down [Backend/]<srv1> [[Backend/]<srv2> ...]]	 下线指定server,若有多个时,需要用引号引起来.
	  [-u |--up [Backend/]<srv1> [[Backend/]<srv2> ...]]	 上线指定server,若有多个时,需要用引号引起来.
  	  [--getweight [Backend/]<srv1> [[Backend/]<srv2> ...]]  获取权重值,若有多个时,需要用引号引起来.
	  [--setweight [Backend/]<srv1> [[Backend/]<srv2> ...]]  设置权重值,若有多个时,需要用引号引起来.
EOF
}

_echoinfo() {
	echo "[INFO] $1"
}
_echoerr() {
	echo -e "\e[31m[ERROR] $1\e[0m"
	exit 1
}
_echowarn() {
	echo -e "\e[33m[WARNNING] $1\e[0m"
}

for opt in $@ ; do
case $opt in
	-ssh)
		sshsrv="$2"
		if [ -z "$2" ] || [[ "$2" =~ - ]];then
			_echoerr "必须提供HAProxy的服务器IP."
		fi
		shift 2
		;;
	-s|--socket)
		socket=$2
		if [ -z "$2" ] || [[ "$2" =~ - ]];then
			_echoerr "--socket选项是必须提供值的."
		fi
		shift 2
		;;
	-sf|--sockets-file)
		socket_list_file=$2
		if [ -z "$2" ] || [[ "$2" =~ - ]];then
		 	_echoerr "--sockets-file选项是必须提供值的."
		fi
		shift 2
		;;
	-b|--backend)
		backend_srv_grp=$2
		if [ -z "$2" ] || [[ "$2" =~ - ]];then
			_echoerr "--backend选项是必须提供值的."
		fi
		shift 2
		;;
	-l|--list)
		option="list"
		backend_srv="$2"
		if [ -z "$2" ] || [[ "$2" =~ - ]];then
			[ -z "$backend_srv_grp" ] && _echoerr "请使用--backend选项指定默认后端服务器组名."
		fi
		shift 2
		;;
	-d|--down)
		if [ -n "$option" ];then
			_echowarn "一次只能执行一组操作; 下线服务器操作被忽略."
			continue
		fi
		option="down"
		backend_srv="$2"
		if [ -z "$2" ] || [[ "$2" =~ - ]];then
			_echoerr "--down选项必须提供要下线的 [backend/]server"
		fi
		shift 2
		;;
	-u|--up)
		if [ -n "$option" ];then
			_echowarn "一次只能执行一组操作; 上线服务器操作被忽略."
			continue
		fi
		option="up"
		backend_srv="$2"
		if [ -z "$2" ] || [[ "$2" =~ - ]];then
			_echoerr "--up选项必须提供要上线的 [backend/]server"
		fi
		shift 2
		;;
	--getweight)
		if [ -n "$option" ];then
			_echowarn "一次只能执行一组操作; 获取服务器权重操作被忽略."
			continue
		fi
		option="getweight"
		backend_srv="$2"
		if [ -z "$2" ] || [[ "$2" =~ - ]];then
			_echoerr "--getweight选项必须提供要查看的 [backend/]server"
		fi
		shift 2
		;;
	--setweight)
		if [ -n "$option" ];then
			_echowarn "一次只能执行一组操作; 设置服务器权重操作被忽略."
			continue
		fi
		option="setweight"
		backend_srv="$2"
		if [ -z "$2" ] || [[ "$2" =~ - ]];then
		 	_echoerr "--setweight选项必须提供要设置的 [backend/]server"
		fi
		set_weight_num=$3
		if [ -z "$3" ] || [[ "$3" =~ - ]];then
		 	_echoerr "--setweight选项必须提供要设置的 [backend/]server 的权重值."
		fi
		shift 2
		;;
	-h|--help)
		_help
		;;
esac
#read -p "请求输入选项:" opt
done

pkgchk=`ssh $sshsrv "rpm -q socat"`
[[ "$pkgchk" =~ \.?\. ]] || _echoerr "请在服务器端安装必须的软件包:yum install socat"
if [ -z "$socket_list_file" ];then
	[ -z "$socket" ] && _echoerr "必须提供HAProxy的socket文件位置."
fi
if [ -z "$backend_srv" ];then
	if [ -z "$backend_srv_grp" ];then
		[ "$option" = "list" ] || _echoerr "必须提供至少一个用于操作的服务器组名和服务器名"
		backend_srv_grp="0"
	fi
	backend_srv="0"
fi

prefix="_xx_$RANDOM"
for bs in "$backend_srv"; do
	bsgroup=${bs/\/*/}
	srv=${bs/*\//}
	#若格式非 backend/server,而仅是一个server,则使用默认backend_srv_grp
	[ -z "$bsgroup" -o "$bsgroup" = "0" ] || bsgroup=$backend_srv_grp
	echo "$srv" >> "${prefix}_$bsgroup"
done


_run() {
	if [ -z "$socket_list_file" ];then
		sockets="$socket"
	else
		sockets="`cat $socket_list_file`"
	fi
	for bsg in `ls ${prefix}_*`; do
	    if [ "$option" != "list" ];then
			[ "$bsg" = ${prefix}_0 ] && continue
			[ "$bsg" = "$prefix" ] && continue || backend_srv_grp=${bsg/${prefix}_/}

			if [ "${2:-0}" -eq 1 ];then
				server=`sed -n '1p' $bsg`
				sed -i '1p' $bsg
				server="/$server"
			fi
		fi

        for ssrv in $sshsrvs; do
            for socket in $sockets ; do
                ssh $ssrv "echo '$1 $backend_srv_grp$server $set_weight_num' |socat stdio $socket"
            done
        done
	done
}

case $option in
	list)
		_run "show servers state"
		_echowarn "目前此功能还有缺陷,正在完善中..."
	;;
	down)
		_run "disable server" "1"
	;;
	up)
		_run "enable server" "1"
	;;
	getweight)
		_run "get weight" "1"
	;;
	setweight)
		_run "set weight" "1"
	;;
esac
rm -f ${prefix}_*
