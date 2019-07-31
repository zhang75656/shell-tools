#!/bin/bash

_log_basedir=_log
[ -d "$_log_basedir" ] || mkdir $_log_basedir
_log=$_log_basedir/_err.`basename ${0}`.log
_login_mysql_exec_errlog=_run_mysql_log.err

basedir=/usr/local/mysql
baseBin=$basedir/bin
_mysql_main_mycnf=/mysql/3306/etc/my.cnf

mycnf=/root/.my3306.cnf
_mysql_root_user=root
_mysql_root_pass=XezK31vD
_mysql_socket=/mysql/3306/mysql.sock
_mysql_host=localhost

_mysql="$baseBin/mysql --defaults-file=$mycnf"
_xing_txt=BaiJiaXing.txt
_name_txt=QianZiWen.txt
_xing=xing.txt
_name=name.txt


create_dict_txt(){
	local cret_dict_xing_txt cret_dict_char cret_dict_line 
	#百家姓字典文件生成
	cret_dict_xing_txt=${1:-$_xing_txt}
	#echo "$xing_txt"
	[ -s "$cret_dict_xing_txt" ] || { echo -e "请提供生成姓氏和名字的汉字文本!\n\t格式: $0 xing.txt name.txt";exit 1; }
	sed -n 's/[[:punct:]]//g;p' $cret_dict_xing_txt |while read cret_dict_line; do
		i=1
		while :;do
			cret_dict_char=`echo "$cret_dict_line" |cut -c $i`
			[ -n "$cret_dict_char" ] && echo "$cret_dict_char" >> $_xing || break
			let i++
		done
	done

	local cret_dict_name_txt cret_dict_n_len cret_dict_name_len cret_dict_name_char
	#生成名字字典文件
	shift
	cret_dict_name_txt=${1:-$_name_txt}
	#echo "$name_txt"
	[ -s "$cret_dict_name_txt" ] || { echo "请提供生成名字的汉字文本!";exit 1; }
	sed -n 's/[[:punct:]]//g;p' $cret_dict_name_txt |while read cret_dict_line; do
		i=1
		while :;do
			let cret_dict_n_len=$RANDOM%2+$i
			cret_dict_name_len="${i}-$cret_dict_n_len"
			#名字的随机生成1个字或2个字
			cret_dict_name_char=`echo "$cret_dict_line" |cut -c $cret_dict_name_len`
			#echo "$name_char"
			[ -n "$cret_dict_name_char" ] && echo "$cret_dict_name_char" >> $_name || break
			let i++
		done
	done
	return 0
}

#create_dict_txt $*

create_test_db_table(){
	local cret_db_tmp_sql=`mktemp _cret_db_XXXXXXX.sql`
	local cret_db_errlog=._cret_db.err.log

cat > $cret_db_tmp_sql << EOF
CREATE DATABASE IF NOT EXISTS $1 CHARACTER SET utf8mb4;

USE robotdb;
CREATE TABLE IF NOT EXISTS students (
  StuID int(10) unsigned NOT NULL AUTO_INCREMENT,
  Name varchar(50) NOT NULL,
  Age tinyint(3) unsigned NOT NULL,
  Gender enum("F","M") NOT NULL,
  ClassID tinyint(3) unsigned DEFAULT 0,
  TeacherID int(10) unsigned DEFAULT 0,
  PRIMARY KEY (StuID),
  INDEX idx_students_name (Name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS scores (
  ID int(10) unsigned NOT NULL AUTO_INCREMENT,
  StuID int(10) unsigned NOT NULL,
  CourseID smallint(5) unsigned NOT NULL,
  Score tinyint(3) unsigned DEFAULT 0,
  PRIMARY KEY (ID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

EOF
	if [ ! -f "$mycnf" ];then
cat > $mycnf <<EOF
[client]
user = $_mysql_root_user
password = $_mysql_root_pass
socket = $_mysql_scoket
host = $_mysql_host
[mysqld]
autocommit=1
EOF
	fi
	if [ -f "$_mysql_main_mycnf" ]; then
		#此脚本会启动多个子进程来执行SQL的增删查改,需要自动提交的支持.
		#否则脚本执行可能出现较多1205错误. 
		#ERROR 1205 (HY000) at line 1: Lock wait timeout exceeded; try restarting transaction
		sed -i '/\[mysqld\]/a\autocommit=1' $_mysql_main_mycnf
		
		#因为并非线程多,所有提高MySQL连接数是必须的.
		#否则会报:ERROR 1040 (HY000): Too many connections
		sed -i '/\[mysqld\]/a\max_connections=1000' $_mysql_main_mycnf

		#此错误目前还没有找的解决办法.
		# ERROR 2013 (HY000): Lost connection to MySQL server 
		# at 'sending authentication information', system error: 32
		# 关闭对客户端的IP反解仅是辅助解决此问题的一个点.
		# 另外还可以避免出现MySQL连接丢失的问题.
		# Lost connection to MySQL serverat ‘reading initial communication packet', system error: 0
		sed -i '/\[mysqld\]/a\skip-name-resolve=on' $_mysql_main_mycnf
		# 另外网上有很多对此问题的说法,不过是针对MacOSX的,说要关闭innodb_file_per_table.
		# 并且,MySQL版本是5.5左右的,可能需要这样做. 
		# 我没验证,我测试环境是开启此功能的,而且我的版本是MariaDB-10.2.23.
	fi

	#_mysql=/usr/bin/echo
	#$_mysql < $tmp_sql &> $_log
	$_mysql < ${cret_db_tmp_sql} 2>$cret_db_errlog
	if [ "$?" -ne 0 ];then
   		echo "`date +%F-%T` [ERROR] [create_test_db_table] Login MySQL Database Create Test_DB:$1 Failed!" >> $_log
   		echo "`date +%F-%T` [ERROR] [create_test_db_table] `cat $cret_db_errlog`" >> $_log
		rm -f ${cret_db_tmp_sql}
		echo > $cret_db_errlog
		return 1
	fi
	rm -f ${cret_db_tmp_sql}
	return 0
}

#create_test_db_table

insert_students_sql() {
	#通过while循环生成指定个数的随机数据,最后通过echo输出

	local in_st_xing_txt_len in_st_arow in_st_name_txt_len in_st_brow in_st_name
	local in_st_age in_st_gender in_st_classid in_st_teacherid in_st_val in_st_vals
	local in_st_sql_cmd

	local in_st_num=${1:-1}	
	while [ "$in_st_num" -ge 1 ] ;do
		in_st_xing_txt_len=`cat $_xing |wc -l`
		let in_st_arow=$RANDOM%$in_st_xing_txt_len
		in_st_name_txt_len=`cat $_name |wc -l`
		let in_st_brow=$RANDOM%$in_st_name_txt_len
		[ "$in_st_arow" -eq 0 ] && in_st_arow=1
		[ "$in_st_brow" -eq 0 ] && in_st_brow=1
		in_st_name=`sed -n "${in_st_arow}p" $_xing``sed -n "${in_st_brow}p" $_name`
		
		let in_st_age=$RANDOM%90
		let in_st_gender=$RANDOM%2
		[ "$in_st_gender" -eq 0 ] && in_st_gender='F' || in_st_gender='M'
		
		let in_st_classid=$RANDOM%15
		let in_st_teacherid=$RANDOM%20
		
		in_st_val="('$in_st_name',$in_st_age,'$in_st_gender',$in_st_classid,$in_st_teacherid)"
		in_st_vals="$in_st_vals,$in_st_val"
		let in_st_num--
	done
	in_st_sql_cmd="INSERT INTO students (Name,Age,Gender,ClassID,TeacherID) VALUES${in_st_vals#,}"
	if [ -n "$in_st_vals" ];then
		echo "$in_st_sql_cmd"
		return 0
	else
   		echo "`date +%F-%T` [ERROR] [insert_students_sql] Generate SQL CMD Failed! [in_st_sql_cmd=$in_sc_sql_cmd]" >> $_log
		return 1
	fi
}

insert_scores_sql() {
	#通过while循环生成指定个数的随机数据,最后通过echo输出

	local in_sc_x in_sc_sid in_sc_courseid in_sc_score in_sc_val in_sc_vals
	local in_sc_sid_num

	local in_sc_num=${1:-1}
	local in_sc_sid_arr=(`select_cmd "slct=Stuid frm=students"`)
   	if [ "$?" -ne 0 ]; then
   		echo "`date +%F-%T` [ERROR] [insert_scores_sql] Query MySQL Database Faild!,fetch StuID Failed! ${in_sc_sid_arr[*]}" >> $_log
		return 1
	fi

	in_sc_sid_num=${#in_sc_sid_arr[*]}
   	if [ "$in_sc_sid_num" -eq 0 ]; then
   		echo "`date +%F-%T` [ERROR] [insert_scores_sql] Query MySQL Database Faild!,fetch StuID Failed! [in_sc_sid_arr=$in_sc_sid_arr]" >> $_log
		return 1
	fi

	while [ "$in_sc_num" -ge 1 ]; do
		let in_sc_x=$RANDOM%$in_sc_sid_num
		in_sc_sid=${in_sc_sid_arr[$in_sc_x]}
		
		let in_sc_courseid=$RANDOM%20
		
		let in_sc_score=$RANDOM%100
		in_sc_val="($in_sc_sid,$in_sc_courseid,$in_sc_score)"
		in_sc_vals="$in_sc_vals,$in_sc_val"
		let in_sc_num--
	done
	echo "INSERT INTO scores (stuid,courseid,score) VALUES${in_sc_vals#,}"
	return 0
}


min_max() {
	#此函数仅用于返回一个小数在前 大数在后的两个随机数.
	#若不传入任何参数,就生成默认100以内的随机数.
	#若指定了要生成多少以内的随机数,就按指定的数来生成随机数.
	#若提供了两个数,就将这两个数按照 小数在前 大数在后的顺序返回.
	
	local ch min max

	ch=$#
	if [ "$#" -gt 0 ];then
		#检测用户提供的数字是否为真数字,若为非数字,则自动使用默认值.
		[ -n "$1" -a "$1" -gt 0 ] &>/dev/null && ch=1 || ch=0
		if [ -n "$2" ];then
			[ "$2" -gt 0 ] &>/dev/null && ch=2 || ch=0
		fi
	fi	
	case $ch in
		0)
		  let min=$RANDOM%100
		  let max=$RANDOM%100
		;;
		1)
		  let min=$RANDOM%$1
		  let max=$RANDOM%$1
		;;
		2)
		  let min=$1
		  let max=$2
	esac
	[ "$min" -lt "$max" ] || { v_tmp=$min;min=$max;max=$v_tmp; }
	echo "$min $max"
	return 0
}

#min_max $@
#exit 0


fetch_rand_stuids(){
	#此函数主要用来返回一个,两个,或多个随机学号.

    local fch_stuid_arr fch_sid_num fch_rand1 fch_rand2 fch_sid_list

    fch_stuid_arr=(`select_cmd "slct=StuID frm=students"`)
    if [ "$?" -ne 0 ]; then
    	echo "`date +%F-%T` [ERROR] [fetch_rand_stuids] Query MySQL Database Faild!,fetch StuID Failed! [fch_stuid_arr=$fch_stuid_arr]" >> $_log
		return 1
	fi
	
	fch_sid_num=${#fch_stuid_arr[*]} 
    if [ "$fch_sid_num" -eq 0 ]; then
    	echo "`date +%F-%T` [ERROR] [fetch_rand_stuids] fetch StuID array Failed! [fch_sid_num=$fch_sid_num]" >> $_log
		return 1
	else
		let fch_rand1=$RANDOM%$fch_sid_num
		let fch_rand2=$RANDOM%$fch_sid_num
	fi

	case ${1:-0} in 
		0)
		  fch_sid_list=${fch_stuid_arr[*]:$fch_rand1:$fch_rand1+$fch_rand2}
		  echo "$fch_sid_list" |tr ' ' ','
		;;
		1)
		  echo "${fch_stuid_arr[$fch_rand1]}"
		;;
		2)
		  let fch_rand1=$fch_rand1/2
		  let fch_rand2=$fch_rand2/2
		
		  min_max ${fch_stuid_arr[$fch_rand1]} ${fch_stuid_arr[$fch_rand2]}
		;;
	esac
	return 0
}

#fetch_rand_stuids $@
#exit 0

gen_slct_students_val(){
	#此函数会生成查询students表的表示语句.
    #它需要和select_cmd函数配合使用.
	#此函数仅生成 select_cmd 函数需要的参数.
	#select_cmd 它使用此函数生成的随机查询表示语句,再自动生成可执行的SQL.

	local ch slct_xing_txt_len slct_arow slct_xing_char slct_age_rand slct_age_range

	let ch=$RANDOM%4
	#ch=3
	case $ch in
		0)
		  #随机从姓氏字典文件中获取一个姓,进行模糊查询.
		  slct_xing_txt_len=`cat $_xing |wc -l`
		  let slct_arow=$RANDOM%$slct_xing_txt_len
		  [ "$slct_arow" -eq 0 ] && slct_arow=1
		  slct_xing_char=`sed -n "${slct_arow}p" $_xing`
		  echo "slct=StuID,Name,Age frm=students whe=Name:LIKE:'${slct_xing_char}%'"
		;;
		1)
		  #查询男女的平均年龄,并过滤出平均年龄大于随机年龄的组.
		  let slct_age_rand=$RANDOM%50
		  echo "slct=Gender,avg(Age):AvgAge frm=students grp=Gender hav=AvgAge>$slct_age_rand"
		;;
		2)
		  #查询一个随机年龄段内的学员信息.
		  slct_age_range=`min_max`
		  echo "slct=* frm=students whe=Age:BETWEEN:${slct_age_range/ /:AND:}"
		;;
		3)
		  #查询指定个数的学员ID信息.
		  echo "slct=* frm=students whe=StuID:IN:(`fetch_rand_stuids || echo 0`) odr=Age:ASC"
	esac
}

#gen_slct_students_val
#exit 0

gen_slct_scores_val(){
	#此函数会生成查询scores表的表示语句.
    #它需要和select_cmd函数配合使用.
	#此函数仅生成 select_cmd 函数需要的参数.
	#select_cmd 它使用此函数生成的随机查询表示语句,再自动生成可执行的SQL.

	local ch slct_score_range slct_age_rand

	let ch=$RANDOM%4
	#ch=3
	case $ch in
		0)
		  #
		  slct_score_range=`min_max`
		  echo "slct=* frm=scores whe=score:BETWEEN:${slct_score_range/ /:AND:}"
		;;
		1)
		  let slct_age_rand=$RANDOM%100
		  echo "slct=stuid,avg(score):AvgScore frm=scores grp=StuID hav=AvgScore>$slct_age_rand odr=AvgScore:DESC"
		;;
		2)
		  echo "slct=courseid,sum(score),avg(score):AvgScore frm=scores grp=courseid odr=AvgScore:DESC"
		;;
		3)
		  echo "slct=* frm=scores whe=StuID:IN:(`fetch_rand_stuids || echo 0`) odr=score:ASC"
	esac	
}

#gen_slct_score_val
#exit 0

gen_upds_students_val() {
	#此函数会生成更新students表的表示语句.
    #它需要和update_cmd函数配合使用.
	#此函数仅生成 update_cmd 函数需要的参数.
	#update_cmd 它使用此函数生成的随机查询表示语句,再自动生成可执行的SQL.

	local upd_sid_list upd_sql_cmd upd_sid_rand upd_tid_rand upd_cid_rand
	let ch=$RANDOM%3
	#ch=2
	case $ch in
		0)
		  upd_sid_rand=`fetch_rand_stuids 1`
		  if [ "$?" -ne 0 ]; then
			echo "`date +%F-%T` [ERROR] [gen_upds_students_val] fetch StuID Failed! [upd_sid_rand=$upd_sid_rand]" >> $_log
			return 1
		  fi
		  echo "upd=students set=Age=Age+1 whe=StuID>$upd_sid_rand"
	     ;;
		1)
		  upd_sid_list=`fetch_rand_stuids`
		  if [ "$?" -ne 0 ]; then
			echo "`date +%F-%T` [ERROR] [gen_upds_students_val] fetch StuID list Failed! [upd_sid_list=$upd_sid_list]" >> $_log
			return 1
		  fi

		  let upd_tid_rand=$RANDOM%20
		  let upd_cid_rand=$RANDOM%20
		  upd_sql_cmd="upd=students set=ClassID=$upd_cid_rand whe=StuID:IN:($upd_sid_list)"
		  upd_sql_cmd="$upd_sql_cmd :: upd=students set=TeacherID=$upd_tid_rand whe=StuID:IN:($upd_sid_list)"
		  echo "$upd_sql_cmd"
	    ;;
		2)
		  upd_sid_list=`fetch_rand_stuids`
		  if [ "$?" -ne 0 ]; then
			echo "`date +%F-%T` [ERROR] [gen_upds_students_val] fetch StuID list Failed! [upd_sid_list=$upd_sid_list]" >> $_log
			return 1
		  fi
		
		  echo "upd=students set=Age=Age+1 whe=StuID:IN:($upd_sid_list)"
		;; 
	esac
}

#gen_upds_students_val
#exit 0
#update_cmd `gen_upds_students_val`
#exit 0

gen_upds_scores_val() {
	#此函数会生成更新scores表的表示语句.
    #它需要和update_cmd函数配合使用.
	#此函数仅生成 update_cmd 函数需要的参数.
	#update_cmd 它使用此函数生成的随机查询表示语句,再自动生成可执行的SQL.

	local ch upd_sc_rand upd_sid_list upd_sid_range

	let ch=$RANDOM%2
	#ch=2
	case $ch in
		0)
		  upd_sid_list=`fetch_rand_stuids`
		  if [ "$?" -ne 0 ]; then
			echo "`date +%F-%T` [ERROR] [gen_upds_scores_val] fetch StuID Failed! [upd_sid_list=$upd_sid_list]" >> $_log
			return 1
		  fi
		  echo "upd=scores set=score=score+10 whe=StuID:IN:($upd_sid_list)"
		;;
		1)
		  let upd_sc_rand=$RANDOM%30
		  upd_sid_range=`fetch_rand_stuids 2`
		  if [ "$?" -ne 0 ];then
			 echo "`date +%F-%T` [ERROR] [gen_upds_scores_val] fetch StuID Range Failed! [upd_sid_range=$upd_sid_range]" >> $_log
			 return 1
		  fi
		  echo "upd=scores set=score=score+$upd_sc_rand whe=StuID:BETWEEN:${upd_sid_range/ /:AND:}"
		;;
	esac
}

#gen_upds_scores_val
#exit 0

gen_del_students_scores_val() {
	#此函数会生成删除students 和 scores表的表示语句.
    #它需要和delete_cmd函数配合使用.
	#此函数仅生成 delete_cmd 函数需要的参数.
	#delete_cmd 它使用此函数生成的随机查询表示语句,再自动生成可执行的SQL.
	#因为删除一条学生表记录,与其对应的成绩表中的成绩就没有意义了.
	#因此要一起删除.

	local ch del_sid_range del_sid_list del_sid_num del_age_rand del_cid del_wh
	local query_stuid_sql

	let ch=$RANDOM%30
	#ch=1
	case $ch in
		0)
		  del_sid_range=`fetch_rand_stuids 2`
		  if [ "$?" -ne 0 ];then
			 echo "`date +%F-%T` [ERROR] [gen_del_students_scores_val] fetch StuID Range Failed! [del_sid_range=$del_sid_range]" >> $_log
			 return 1
		  fi

		  let del_age_rand=$RANDOM%50
		  query_stuid_sql="slct=stuid frm=students whe=Age=$del_age_rand:AND:StuID:BETWEEN:${del_sid_range/ /:AND:}"
		  #let age_rand=$RANDOM%100
		  #let rand1=$RANDOM%100
		  #let rand2=$RANDOM%100
		  #sid1=$rand1
		  #sid2=$rand2
		  #[ "$sid1" -lt "$sid2" ] || { sid1=$rand2; sid2=$rand1; } 
		  #query_stuid_sql="slct=stuid frm=students whe=Age>$age_rand:AND:StuID:BETWEEN:${sid1}:AND:${sid2}"	
		;;
		1)
		  let del_cid=$RANDOM%20
		  del_sid_list=`fetch_rand_stuids`
		  if [ "$?" -ne 0 ];then
			 echo "`date +%F-%T` [ERROR] [gen_del_students_scores_val] fetch StuID list Failed! [del_sid_list=$del_sid_list]" >> $_log
			 return 1
		  fi

		  query_stuid_sql="slct=stuid frm=students whe=ClassID=$del_cid:AND:StuID:IN:($del_sid_list)"
		;;
		*)
		  del_sid_num=`fetch_rand_stuids 1`
		  if [ "$?" -ne 0 ];then
			 echo "`date +%F-%T` [ERROR] [gen_del_students_scores_val] fetch StuID Failed! [del_sid_num=$del_sid_num]" >> $_log
			 return 1
		  fi

		  del_wh="whe=StuID=$del_sid_num"
		  echo "frm=students $del_wh :: frm=scores $del_wh"
		  return 0
		;;
	esac
    #echo "`select_cmd "$query_stuid_sql"`"
	#exit 0

	local query_result del_stu_sql del_scores_sql 

    query_result="$(echo `select_cmd "$query_stuid_sql"` |tr ' ' ',')"
	if [ -n "$query_result" ]; then
    	del_stu_sql="frm=students whe=StuID:IN:($query_result)"	
    	del_scores_sql="frm=scores whe=StuID:IN:($query_result)"	
    	echo "$del_stu_sql :: $del_scores_sql"
		return 0
	fi
	return 1
}

#gen_del_students_scores_val
#exit 0

run_mysql() {
	local errlog run_sql run_err_log run_mysql_errlog
	local run_mysql_per_thread_tmp_errlog

	errlog=$_log_basedir/_run_tmp_log.err
	if [ -n "$_database" -o -n "$_DATABASE" ];then
		#echo "run_mysql=$@"
		#_mysql=echo
		#$_mysql -e "$@ ; FLUSH TABLES"
		run_sql="$@"
		if [ -n "$run_sql" ];then
			if ! echo "$run_sql" | grep -q 'SELECT' ; then
			 	run_sql="$run_sql ; FLUSH TABLES"
		 	else
				run_sql="$run_sql"
			fi
			$_mysql -e "$run_sql" 2>$errlog
			run_err_log=`cat $errlog`
		fi
		if [ -n "$run_err_log" ];then
			echo "`date +%F-%T`	[ERROR] [run_mysql] [run_sql=$@] " >> $_log
			run_mysql_err_log="`date +%F-%T`	[ERROR] [run_mysql] $run_err_log "
			if echo "$run_err_log" |egrep -qi '1040|2013|1205'; then
				run_mysql_per_thread_tmp_errlog=`mktemp $_log_basedir/_run_mysql_log.XXXXXXXX.err`
				echo "$run_mysql_err_log" |tee -a $_log >> $run_mysql_per_thread_tmp_errlog
				echo "------------[DATE:`date +%F-%T` EXEC: SHOW FULL PROCESSLIST ]--------------" >> $run_mysql_per_thread_tmp_errlog
				$_mysql -e "SHOW FULL PROCESSLIST" &>> $run_mysql_per_thread_tmp_errlog
				echo "------------[DATE:`date +%F-%T` EXEC: STATUS ]--------------" >> $run_mysql_per_thread_tmp_errlog
				$_mysql -e "STATUS" &>> $run_mysql_per_thread_tmp_errlog
				sleep 1
			fi
			return 1
		fi
		return 0
	else
		echo -e "\033[31m`date +%F-%T` [ERROR] [run_mysql] 请指定默认测试数据库名,设定方式 export _DATABASE=数据库名\033[0m" |tee -a $_log
		#若调用此函数时,是通过运行子进程的方式调用,则这里的exit只能退出子进程,不能退出父进程.
		#也就是说,子进程退出,还有继续执行父进程下面的代码.
		#select_cmd在调用此函数时使用了 `run_mysql ..` 这就是一种子进程调用的方式.
		#	另外( run_mysql ...) $(run_mysql ...) 这些子进程调用的方式应该都是一样的逻辑.
		#	需要特别注意!!
		return 1
	fi
}

run_mysql_errlog_aggregate() {
	#此函数是用于将每个线程生成的MySQL错误日志汇总到一个日志文件中,并删除这些临时日志文件.	

	local logfile

	cd $_log_basedir
	if ls _run_mysql_log.*.err &>/dev/null; then
		ls -t _run_mysql_log.*.err |while read logfile; do
			#echo "$logfile"
			cat $logfile >> ../$_login_mysql_exec_errlog
			rm -f $logfile
		done
	fi
}

select_cmd() {
	#SELECT field1,field2,..
	#  FROM tb_name
	#  WHERE field =|>|<|<>|>=|<=|IN (a,b,c)|BETWEEN a AND b|LIKE 'x%'
	#  GROUP BY field
	#  HAVING field =|>|<|<>|>=|<=|IN (a,b,c)|BETWEEN a AND b|LIKE 'x%'
    #  ORDER BY field ASC|DSC
	#
	# 注意:
	#	WHERE 后面若有多个过滤条件,则将空格用冒号代替.
	#		  如: 
	#			whe="Age>20:AND:Name:LIKE:'yu%':OR:StuID<100"
	#		  最后脚本得到的WHERE条件为:
	#			WHERE Age>20 AND Name LIKE 'yu%' OR StuID<100
	#

	local f i slct_sql_cmd slct_select slct_from slct_where slct_group slct_having slct_order
	for params in $@; do
		case $params in 
			slct=*) 
				slct_select=${params/slct=/}
				slct_select=`echo "${slct_select}" |tr ':' ' '`
				slct_sql_cmd="SELECT $slct_select"
				
				#SELECT name,age FROM students;
				#此SQL返回值放到变量中后,变量的值将为: 
				#   name age NameValue1 AgeValue1 NameValue2 AgeValue2 ...
				#这里统计出实际查询了几个字段,即SELECT 后面跟了几个字段.
				#便于去除变量值中字段名.
				slct_st=(`echo "$slct_select" |tr ',' ' '`)
				slct_st_num=${#st[*]}
				let slct_st_num++
				;;
			frm=*)
				slct_from=${params/frm=/}
				slct_sql_cmd="$slct_sql_cmd FROM $slct_from"
				;;
			whe=*)
				slct_where=`echo "${params/whe=/}" |tr ':' ' '`
				slct_sql_cmd="$slct_sql_cmd WHERE $slct_where"
				;;
			grp=*)
				slct_group=${params/grp=/}
				slct_sql_cmd="$slct_sql_cmd GROUP BY $slct_group"
				;;
			hav=*)
				slct_having=`echo "${params/hav=/}" |tr ':' ' '`
				slct_sql_cmd="$slct_sql_cmd HAVING $slct_having"
				;;
			odr=*)
				od=${params/odr=/}
				slct_order=${od/:/ }
				slct_sql_cmd="$slct_sql_cmd ORDER BY $slct_order"
		esac
	done
	
	#_mysql=/usr/bin/echo
	#$_mysql -e "$sql_cmd"
	#exit 0
	#sql_result=(`$_mysql -e "$sql_cmd" &> $_log`)
	#echo "select_cmd sql_cmd=$sql_cmd"
	#run_mysql "$sql_cmd"
	local slct_sql_result

	slct_sql_result=(`run_mysql "$slct_sql_cmd"`)
	if [ "$?" -ne 0  -a -z "$slct_sql_result" ];then
	   echo -e "`date +%F-%T` [ERROR] [select_cmd] Login MySQL Database EXEC [SELECT] ${slct_sql_cmd} Failed!" >> $_log
	   echo -e "`date +%F-%T` [ERROR] [select_cmd] [slct_sql_result=${slct_sql_result[*]}]" >> $_log
	   return 1
	elif [ -n "$slct_sql_result" ];then
		echo "${slct_sql_result[*]:$slct_st_num}"
		return 0
	fi
	#echo "${sql_result[*]}"
}


insert_cmd() {
	#使用格式:
	#  insert_cmd 表名:要插入多少条测试数据
	#  例如:
	#	 insert_cmd studetns:200
	#	 仅向students表中插入200条测试数据.
	#
	#	 insert_cmd studetns:100 score:100
	#	 就是向 studetns,score表中分别插入100条测试数据.
	
	local tb line in_sql_cmd
	for tb in $@; do
		case $tb in
			students:*)
				in_sql_cmd="`insert_students_sql ${tb#*:}`"
				;;
			scores:*)
				in_sql_cmd="`insert_scores_sql ${tb#*:}`"
				;;
		esac
		#_mysql="/usr/bin/echo"
		#$_mysql -e "${sql_cmd}; FLUSH TABLES;" &> $_log
		run_mysql "${in_sql_cmd}"
		if [ "$?" -ne 0 ];then
		   echo -e "`date +%F-%T` [ERROR] [insert_cmd] Login MySQL Database EXEC [INSERT] ${in_sql_cmd} Failed!" >> $_log
		   return 1
		fi
		sleep ${_sleep_time:-1}
	done

}

#insert_sql $@

update_cmd() {
	#UPDATE tb_name 
	#  SET field=value 
	#  WHERE field =|>|<|<>|>=|<=|IN (a,b,c)|BETWEEN a AND b|LIKE 'x%'
	# 由于有时更新数据可能需要同时修改另一个数据项.
	# 比如: 
	#   学生重新报班了,那新班级教的课程不一样,当然老师也不一样.
	#	因此修改学生的班级编号的同时,也要修改老师的编号.
    
	local p line 
	local upd_sql_cmd upd_where upd_tmp_sql upd_sql_num
	upd_tmp_sql=`mktemp _upd.XXXXXXXX.sql`

	echo -e "${@/::/\n}" |while read line; do
		for p in $line; do
			case $p in
				upd=*)
					upd_sql_cmd="UPDATE ${p/upd=/}"
					;;
				set=*)
					upd_sql_cmd="$upd_sql_cmd SET ${p/set=/}"
					;;
				whe=*)
					upd_where=`echo "${p/whe=/}" |tr ':' ' '`
					upd_sql_cmd="$upd_sql_cmd WHERE $upd_where"
					;;
			esac
		done
		echo "$upd_sql_cmd ;" >> $upd_tmp_sql
    done
		
	#_mysql="/usr/bin/echo"
	#$_mysql -e "${sql_cmd}; FLUSH TABLES" &> $_log
	upd_sql_num=$(cat $upd_tmp_sql |wc -l)
	if [ "$upd_sql_num" -le 1 ];then
		run_mysql "`cat $upd_tmp_sql`"
		#echo "`cat $upd_tmp_sql`"
		upd_return=$?
	else
		upd_sql_cmd="BEGIN; `cat $upd_tmp_sql` COMMIT"
		run_mysql "$upd_sql_cmd"
		#echo "$upd_sql_cmd"
		upd_return=$?
	fi
	rm -f $upd_tmp_sql
	sleep ${_sleep_time:-1}

	if [ "$upd_return" -ne 0 ];then
	   echo -e "`date +%F-%T` [ERROR] [update_cmd] Login MySQL Database EXEC [UPDATE] ${upd_sql_cmd} Failed!" >> $_log
	   return 1
	fi

	return 0
	
	#出现了我实在不理解的问题.
	#	sql_cmd 从while循环中出来后,值就奇怪的丢了.
	#		    最终还是没有找到原因.
	#echo "2 sql_cmd=$sql_cmd"
	#echo "__tmp=$__tmp"

	#_mysql="/usr/bin/echo"
	#_mysql=echo
	#$_mysql -e "${sql_cmd} ; FLUSH TABLES;"
}


delete_cmd() {
	#DELETE FROM tb_name
	#  WHERE field =|>|<|<>|>=|<=|IN (a,b,c)|BETWEEN a AND b|LIKE 'x%'

	local p del_sql_cmd del_where del_line 
	local del_tmp_sql=`mktemp _del.XXXXXXXXXX.sql`

	echo -e "${@/::/\n}" |while read del_line; do
		for p in $del_line; do
			case $p in
				frm=*)
					del_sql_cmd="DELETE FROM ${p/frm=/}"
					;;
				whe=*)
					del_where=`echo "${p/whe=/}" |tr ':' ' '`
					del_sql_cmd="$del_sql_cmd WHERE $del_where"
					;;
			esac
		done
		#echo "del_sql_cmd=$del_sql_cmd"
		[ -n "$del_sql_cmd" ] && echo "$del_sql_cmd ;" >> $del_tmp_sql
	done

	#_mysql="/usr/bin/echo"
	#$_mysql -e "$sql_cmd; FLUSH TABLES;" &> $_log
	del_sql_cmd="BEGIN; `cat $del_tmp_sql` COMMIT "
	rm -f $del_tmp_sql
	run_mysql "${del_sql_cmd}"
	#echo  "${del_sql_cmd}"
	if [ "$?" -ne 0 ];then
	   echo -e "`date +%F-%T` [ERROR] [delete_cmd] Login MySQL Database EXEC [DELETE] ${del_sql_cmd} Failed!" >> $_log
	   return 1
	fi
	sleep ${_sleep_time:-1}
	return 0
}

#delete_sql $@

#Test Data
#_database=robotdb
#_mysql="$_mysql ${_database:-$_DATABASE}"
#
##slct_cmd=`gen_slct_scores_val`
#slct_cmd=`gen_slct_students_val`
##echo "slct_cmd=$slct_cmd"
#select_cmd "$slct_cmd"
#exit 0
#
##upd_cmd=`gen_upds_students_val`
#upd_cmd=`gen_upds_scores_val`
#echo "upd_cmd=$upd_cmd"
#update_cmd "$upd_cmd"
#exit 0
#
#del_cmd=`gen_upds_students_val`
#echo "del_cmd=$del_cmd"
#delete_cmd "$del_cmd"
#exit 0

#insert_scores_sql $@
#exit 0
