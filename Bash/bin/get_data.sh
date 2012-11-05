#!/bin/bash

#Title       : get_data.sh
#Date Created: Wed Oct 31 18:02:31 CST 2012
#Last Edit   : Wed Oct 31 18:02:31 CST 2012
#Author      : "Johandry Amador" < johandry@me.com >
#Version     : 1.00
#Description : Identify what local applications are in use
#Usage       : 

#The script home directory. Change it if you change the script to other directory.
home="/home/jamador/Development/MyNetwork/Bash"
#Default netstat command options
DEFAULT_NETSTAT='netstat -natp'

#Save from where the script was executed
initial_pwd="$PWD"

#Description: Print log messages, errors and warnings
#Parameters : [<type>] <message>
#             <type>: Could be: msg, error, warn. Default is msg
function log {
	log_type="$1" && shift
	case "${log_type}" in
		(msg) 
			printf "%b" "$*\n"
			;;
		(warn) 
			printf "%b" "WARNING: $*\n" >&2
			;;
		(error) 
			printf "%b" "ERROR: $*\n" >&2
			exit 1;
			;;
		(*) 
			printf "%b" "${log_type} $*\n"
			;;
	esac
}

#Description: Get netstat options base on OS used.
#Parameters : 
function set_netstat {
	ostype=$(uname)
	[ "${ostype}" = "Darwin" ] && NETSTAT='netstat -nat'  && return #Mac OS X
	[ "${ostype}" = "Linux"  ] && NETSTAT='netstat -natp' && return #Linux
	[ "${ostype}" = "CygWin" ] && NETSTAT='netstat'       && return #CygWin on Windows (TODO: Validate)
	log warn "Unknown OS (${ostype}). Review command netstat and include it in the function set_netstat"
	NETSTAT=$DEFAULT_NETSTAT
}

#Description: Validations and Initializations before start the execution
#Parameters :
function init {
	myname=$(basename $0)
	bin_name="${home}/bin/$myname"
	db_name="${home}/data/${myname}.db"
	#Validate the home directory
	[ -d "${home}" -a -e "${bin_name}" ] || log error "Home directory is not correct, update the variable \${home}".
	
	#Get the parameters of netstat according to the OS type
	set_netstat
	
	#Create DB if do not exists
	if [ ! -e "${db_name}" ]
	then
		sqlite3 "${db_name}"
	fi
}

#Description: Get formated output from Netstat for Listen or Establish connections
#Parameters : $1 = 'LISTEN' or 'ESTABLISHED' or 'LISTENING' or 'CONNECTED'
function get_netstat {
	cmd="$1" && shift
	if [ "${cmd}" = "LISTEN" ] || [ "${cmd}" = "ESTABLISHED" ]
	then
		sudo $NETSTAT | grep "${cmd}" | awk '{print $4","$5","$7}'
	else
		sudo $NETSTAT | grep "${cmd}" | awk '{print $7}'
	fi
}

#Description: Parse information obtained from netstat and save it in a DB
#Parameters : $1 = 'listen.dat' or 'estabished.dat'
function parse_data {
	data_file="${home}/data/$1"
	OIFS=$IFS
	while read line
	do
		foreing=$(echo ${line} | cut -d, -f1)
		foreing_ip=$(echo ${foreing} | cut -d: -f1)
		foreing_port=$(echo ${foreing} | cut -d: -f2)
		local=$(echo ${line} | cut -d, -f2)
		local_ip=$(echo ${local} | cut -d: -f1)
		local_port=$(echo ${local} | cut -d: -f2)
		app=$(echo ${line} | cut -d, -f3)
		app_pid=$(echo ${app} | cut -d/ -f1)
		app_name=$(echo ${app} | cut -d/ -f2)
		
		#Add Applications if do not exists
		app_id=$(sqlite3 ${home}/data/migration.db "select id from Apps where name='${app_name}';")
		[ -z "${app_id}" ] && sqlite3 "${home}/data/migration.db" "insert into Apps (name) values ('${app_name}');"
		
		#Add Server if do not exists
		server_id=$(sqlite3 "${home}/data/migration.db" "select id from Servers where ip='${foreing}_ip';")
		[ -z "$server_id" -a -z "${foreing_ip}" ] && sqlite3 "${home}/data/migration.db" "insert into Servers (ip) values ('${foreing_ip}');"
		server_id=$(sqlite3 "${home}/data/migration.db" "select id from Servers where ip='${local}_ip';")
		[ -z "$server_id" -a -z "${local_ip}" ] && sqlite3 "${home}/data/migration.db" "insert into Servers (ip) values ('${local_ip}');"
		
		
	done < "${data_file}"
	IFS=$OIFS
}

## MAIN 
init

get_netstat 'LISTEN' > "${home}/data/listen.dat"
parse_data 'listen.dat'

get_netstat 'ESTABLISHED' > "${home}/data/estabished.dat"
parse_data 'estabished.dat'