#!/bin/bash -

#Title       : get_data.sh
#Date Created: Wed Oct 31 18:02:31 CST 2012
#Last Edit   : Wed Oct 31 18:02:31 CST 2012
#Author      : "Johandry Amador" < johandry@me.com >
#Version     : 1.00
#Description : Identify what local applications are in use
#Usage       : 



#Default netstat command options
DEFAULT_NETSTAT='netstat -natp'

#Save from where the script was executed
initial_pwd="$PWD"
#The script home directory
home=""

#Description: Print errors and warnings
#Parameters :
function 

#Description: Get netstat options base on OS used.
#Parameters : 
function set_netstat {
	os=$(uname)
	[ "$os" = "Darwin" ] && NETSTAT='netstat -nat'  && return #Mac OS X
	[ "$os" = "Linux"  ] && NETSTAT='netstat -natp' && return #Linux
	[ "$os" = "CygWin" ] && NETSTAT='netstat'       && return #CygWin on Windows
	echo "Unknown OS ($os). Review command netstat and include it in the function set_netstat" 1>&2
	NETSTAT=$DEFAULT_NETSTAT
}

#Description: Get formated output from Netstat for Listen or Establish connections
#Parameters : $1 = 'LISTEN' or 'ESTABLISHED' or 'LISTENING' or 'CONNECTED'
function get_netstat {
	#echo "[$(date)]"
	if [ "$1" = "LISTEN" ] || [ "$1" = "ESTABLISHED" ]
	then
		sudo $NETSTAT | grep "$1" | awk '{print $4","$5","$7}'
	else
		sudo $NETSTAT | grep "$1" | awk '{print "$7}'
	fi
}

#Description: Parse information obtained from netstat and save it in a DB
#Parameters : $1 = 'listen.dat' or 'estabished.dat'
function parse_data {
	data_file=$home/data/$1
	OIFS=$IFS
	while read line
	do
		foreing=$(echo $line | cut -d, -f1)
		foreing_ip=$(echo $foreing | cut -d: -f1)
		foreing_port=$(echo $foreing | cut -d: -f2)
		local=$(echo $line | cut -d, -f2)
		local_ip=$(echo $local | cut -d: -f1)
		local_port=$(echo $local | cut -d: -f2)
		app=$(echo $line | cut -d, -f3)
		app_pid=$(echo $app | cut -d/ -f1)
		app_name=$(echo $app | cut -d/ -f2)
		
		#Add Applications if do not exists
		app_id=$(sqlite3 $home/data/migration.db "select id from Apps where name='$app_name';")
		[ -z "$app_id" ] && sqlite3 $home/data/migration.db "insert into Apps (name) values ('$app_name');"
		
		#Add Server if do not exists
		server_id=$(sqlite3 $home/data/migration.db "select id from Servers where ip='$foreing_ip';")
		[ -z "$server_id" ] && sqlite3 $home/data/migration.db "insert into Servers (ip) values ('$foreing_ip');"
		server_id=$(sqlite3 $home/data/migration.db "select id from Servers where ip='$local_ip';")
		[ -z "$server_id" ] && sqlite3 $home/data/migration.db "insert into Servers (ip) values ('$local_ip');"
	done < $data_file
}

## MAIN 
#Get the parameters of netstat according to the OS
set_netstat


get_netstat 'LISTEN' > $home/data/listen.dat
parse_data 'listen.dat'

get_netstat 'ESTABLISHED' > $home/data/estabished.dat
