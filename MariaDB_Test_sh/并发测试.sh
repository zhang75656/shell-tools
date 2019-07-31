#!/bin/bash

sql_funcs=genSql.sh
[ -s "$sql_funcs" ] && source $sql_funcs || { echo "请提供SQL函数脚本.";exit 1; }

#生成100个子进程,分别随机调用select,insert,update,delete

gen_sub_procs(){
	sub_num=${1:-10}
	for i in `seq $sub_num`; do
		let ch=$RANDOM%30
		if [ "$ch" -eq 0 ];then
			#( delete_cmd `gen_del_students_scores_val` &>> $_log ) &
				#delete_cmd "$sql_cmd" 1>/dev/null 2>>$_log 
			( 	sql_cmd=`gen_del_students_scores_val`
				[ "$?" -eq 0 ] || exit 1 
				delete_cmd "$sql_cmd" &>>$_log 
			) &
		elif [ "$ch" -lt 5 ]; then
			#( update_cmd `gen_upds_students_val` &>> $_log ) &
			#( update_cmd `gen_upds_scores_val` &>> $_log ) &
				#update_cmd "$sql_cmd" 1>/dev/null 2>>$_log 
			( 	sql_cmd=`gen_upds_students_val`
				[ "$?" -eq 0 ] || exit 1 
				update_cmd "$sql_cmd" &>>$_log 
			) &
				#update_cmd "$sql_cmd" 1>/dev/null 2>>$_log 
			( 	sql_cmd=`gen_upds_scores_val`
				[ "$?" -eq 0 ] || exit 1 
				update_cmd "$sql_cmd" &>>$_log 
			) &
		elif [ "$ch" -lt 15 ]; then
			#let num_rand=$RANDOM%100
			num_rand=10
			#( insert_cmd students:$num_rand scores:$num_rand  &>> $_log) &
			( insert_cmd students:$num_rand scores:$num_rand 1>/dev/null 2>>$_log ) &
		else
			#( select_cmd `gen_slct_students_val` &>> $_log ) &
			#( select_cmd `gen_slct_scores_val` $>> $_log ) &
			( select_cmd `gen_slct_students_val` 1>/dev/null 2>>$_log ) &
			( select_cmd `gen_slct_scores_val` 1>/dev/null 2>>$_log ) &
		fi
	done
	wait
	#[ -s "$_log" ] && grep -i 'error' $_log 
}


#默认测试数据库的名字为 _database
_database=robotdb

#默认启动的测试线程数为 num
num=3

#默认执行INSERT,UPDATE,DELETE时,睡眠秒数为1秒.
#_sleep_time=1

#设定日志文件存储的根目录.
_log_basedir=_log
[ -d "$_log_basedir" ] || mkdir $_log_basedir

#默认日志文件名 _log
_log=$_log_basedir/_err.`basename ${0}`.log
_login_mysql_exec_errlog=_run_mysql_log.err
case $1 in
	init)
	   #生成姓和名的字典文件.
	   #create_dict_txt BaiJiaXing.txt QianZiWen.txt
	   #初始化数据库和表
	   create_test_db_table ${_database:-$_DATABASE}
	   #exit 0
	   
	   #生成初始数据
		_mysql="$_mysql ${_database:-$_DATABASE}"
	   insert_cmd students:10
	   insert_cmd scores:10
	;;
	-h|--help)
	   echo "Usage: $0 [<init> | [启动测试线程数 (default:3)]]"
	;;
	*)
		_mysql="$_mysql ${_database:-$_DATABASE}"

       [ "$1" -ge 0 ] &>/dev/null && num=$1
	   gen_sub_procs $num	

	   #不能将此汇总mysql错误日志的函数放到gen_sub_procs函数中.
	   #否则,gen_sub_procs快速生成完所有子进程后,它去执行此函数.
	   #就会报错,因为子进程还没有遇到MySQL错误.肯定不会有错误日志.
	   run_mysql_errlog_aggregate

	   #select_cmd `gen_slct_students_val`
	   #exit 0
	   
	   #select_cmd `gen_slct_scores_val`
	   #exit 0
	   
	   #let num_rand=$RANDOM%100
	   #num_rand=1
	   #insert_cmd students:$num_rand scores:$num_rand
	   #exit 0
	   
	   #gen_upds_students_val
	   #exit 0
	   #update_cmd `gen_upds_students_val`
	   #exit 0
	   
	   #update_cmd `gen_upds_scores_val`
	   #exit 0
	   
	   #sql_cmd=`gen_del_students_scores_val`
	   #[ "$?" -eq 0 ] || exit 1
	   #delete_cmd "$sql_cmd"
	   #exit 0
	;;
esac

