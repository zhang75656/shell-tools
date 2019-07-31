#!/bin/bash

openssl_conf=/etc/pki/tls/openssl.cnf
cert_info='/C=CN/ST=Beijing/L=Beijing/O=Testops/CN='
workdir="$PWD/worker_dir"
ca_key=$workdir/cakey.pem
ca_crt=$workdir/cacert.pem
conf=$workdir/openssl.cnf
certdb=$workdir/index.txt
newcerts=$workdir/newcerts
v3extFile=$workdir/v3.txt

userkey=$workdir/user_private_key.key
usercsr=$workdir/user_cert.csr
usercrt=$workdir/user_cert_file.crt

CACertFile=ca_cert.pem

initenv() {
	cp $openssl_conf $conf
	sed -i "s,^dir.*/etc.*,dir=$workdir," $conf
	if grep -q "^dir=$workdir$" $conf ;then
		echo 01 > $workdir/serial
		touch $certdb
		mkdir $newcerts
	else
		echo "Modify openssl.cnf Failed!"
		exit 1
	fi
}

echo_info() {
	echo -e "\e[32m[INFO] $1 [successful.]\e[0m"
}
echo_err() {
	echo -e "\e[31m[ERROR] $1 [Abort!]\e[0m"
}
echo_warn() {
	echo -e "\e[33m[WARNNING] $1 \e[0m"
}

gencert() {
    Cdomain=$1
    v3Flag=$2
	if [ -z "$Cdomain" ];then
		echo_err "必须输入合法域名."
		exit 1
	else
		if [ -n "`grep "$Cdomain" $certdb`" ];then
			echo_err "域名: $Cdomain 已经签发,不允许重复签发!"
			echo_err "可使用 $0 -showcert=$Cdomain 查看详情."
			exit 1
		fi
	fi
    [ -z "$v3Flag" ] || v3Params="-extfile $v3extFile"
	(umask 077; openssl genrsa -out $userkey 1024)
	openssl req -new -key $userkey -out $usercsr -subj $cert_info$Cdomain
	openssl ca -in $usercsr -out $usercrt -keyfile $ca_key -cert $ca_crt \
				-days 365 $v3Params -config $conf -batch
	k=${Cdomain}.key.`date +%y%m%d%H%M%S`
	c=${Cdomain}.crt.`date +%y%m%d%H%M%S`
	cp $userkey $k
	cp $usercrt $c
	rm -f $userkey $usercrt $usercsr
	echo_info "为服务器创建的证书为: $c 该证书的私钥为: $k 使用时可去掉后面的时间后缀."
}

[ -d "$workdir" ] || mkdir $workdir
case $1 in
 	-ca*)
		if [ -f "$openssl_conf" ];then
			initenv
		else
			openssl_conf=`find / -name 'openssl.cnf' |head -1`
			[ -n "$openssl_conf" ] && initenv || { echo "Not found openssl.cnf" ; exit 1; }
		fi
		Domain=${1/-ca=/}
		Domain=${Domain/-ca/}
		
		(umask 077; openssl genrsa -out $ca_key 2048 )
		openssl req -new -x509 -key $ca_key -out $ca_crt -subj $cert_info${Domain:-test.com}
		cp $ca_crt $CACertFile
		echo_info "生成自签名CA证书完成: $CACertFile"
		;;
	-cert=*)
        #生成V1证书,此证书适用于网站
		gencert ${1/-cert=/}
		;;
    -v3cert=*)
        #生成V3证书,此证书适用于具体单个应用.
        #http://blog.chinaunix.net/uid-451-id-5075683.html
        #email:abc@aa.com,DNS:test.com,DNS:www.test.com,IP:192.168.7.1
        SubjAltNames=${1/-v3cert=/}
        SANs=(`echo $SubjAltNames |tr ',' ' '`)
        for san in ${SANs[*]}; do
            [ "${san%:*}" == "IP" ] && continue
            [ "${san%:*}" == "DNS" ] && continue
            [ "${san%:*}" == "email" ] && continue
            echo_err "请确认书写格式,必须是:"
            echo_err "\t-v3cert=IP:x.x.x.x 或 -v3cert=DNS:www.x.com,DNS:x.com,email:x@x.com"
            exit 1
        done
        {
          echo "authorityKeyIdentifier=keyid,issuer"
          echo "basicConstraints=CA:FALSE"
          echo "keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment"
          echo "subjectAltName=$SubjAltNames"
          #echo "subjectAltName=dirName:dir_sect"
          #echo "[dir_sect]"
          #echo "C=UK\nO=MyOrganization\nOU=MyUnit\nCN=MyName"
        } > $v3extFile
        gencert ${SANs[0]#*:} 1
        ;;
	-showcert=*)
		CrtFile=${1/-showcert=/}
        if [ -z "$CrtFile" ];then 
            echo_info "CA证书的信息如下:"
            c="$CACertFile"
        else
            echo_info "$CrtFile 证书信息如下:"
            c="$CrtFile"
        fi
	    openssl x509 -in $c -noout -text
		;;
	-clearall)
		rm -f $CACertFile
		rm -rf $workdir
		echo_info "清理CA证书:$CACertFile  清理工作目录:$workdir"
		echo_warn "请手动清理服务器的证书,服务器证书文件名格式: domainName.key.时间 domainName.crt.时间"
		;;
	-h|--help|*)
		echo "Usage $0 [-ca[=DomainName] | -cert=UserDomainName | -v3cert=SubjAltName | -showcert[=pathToCrtFile] | -clearall]"
        echo ""
		echo "   -ca       :创建一个自签名CA证书.默认是test.com,可指定一个自定义的域名,如:-ca=abc.com"
		echo "   -cert     :指定要颁发的证书名,如:-cert=server1.ccc.com 或 泛域名证书:-cert=ccc.com"
		echo "   -v3cert   :生成V3版证书,若需要为具体单个应用颁发证书时,可使用,如:-v3cert=DNS:server1.ccc.com,IP:1.2.3.4,email:tom@abc.com"
        echo "              格式:  DNS:二级域名|三级域名 IP:具体应用的IP  email:为具体邮箱制作证书 ;这三种格式可混合使用,也可单个使用一次或多次.用逗号分隔."
		echo "   -showcert :查看一个证书的信息,默认查看初始化时生成的CA证书,若查看具体证书可:-showcert=/path/to/server1.crt"
		echo "   -clearall :清除此脚本生成的CA证书和证书工作目录."
        echo ""
		;;
esac
