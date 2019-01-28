#!/bin/sh
###############################################################################
CMD_GETCFG="/sbin/getcfg"
CMD_SETCFG="/sbin/setcfg"
CMD_LN="/bin/ln"
CMD_SED="/bin/sed"
CMD_ECHO="/bin/echo"
CMD_RM="/bin/rm"
CMD_TOUCH="/bin/touch"
CMD_CHMOD="/bin/chmod"
CMD_CHOWN="/bin/chown"
CMD_KILL="/bin/kill"
CMD_CAT="/bin/cat"
CMD_GREP="/bin/grep"
CMD_PS="/bin/ps"
CMD_MKDIR="/bin/mkdir"
CMD_CP="/bin/cp"
CMD_LOG_TOOL="/sbin/log_tool"

###############################################################################
LOG_DUP_STDOUT=y # flag for app_log() duplicate to stdout


info_log() {
	$CMD_LOG_TOOL -t 0 -u System -p 127.0.0.1 -m localhost -a "$1"
	app_log "[Info] ${1}"
}

warning_log() {
	$CMD_LOG_TOOL -t 1 -u System -p 127.0.0.1 -m localhost -a "$1"
	app_log "[Warning] ${1}"
}

err_log() {
	$CMD_LOG_TOOL -t 2 -u System -p 127.0.0.1 -m localhost -a "$1"
	app_err_log ${1}
}

app_log() {
	# log information to app's log file
	$CMD_ECHO "[$(date '+%Y/%m/%d %H:%M:%S')] [$$] $@" >> $QPKG_LOG_FILE
	[ ! -z "${LOG_DUP_STDOUT}" ] && $CMD_ECHO "[$(date '+%Y/%m/%d %H:%M:%S')] [$$] $@"
}

app_err_log() {
	# log error to app's log file
	$CMD_ECHO "[$(date '+%Y/%m/%d %H:%M:%S')] [$$] [Error] $@" >> $QPKG_LOG_FILE
	[ ! -z "${LOG_DUP_STDOUT}" ] &&  $CMD_ECHO "[$(date '+%Y/%m/%d %H:%M:%S')] [$$] [Error] $@"
}

app_err_exit_log() {
	$CMD_ECHO "[$(date '+%Y/%m/%d %H:%M:%S')] [$$] [Error exit] $@" >> $QPKG_LOG_FILE
	[ ! -z "${LOG_DUP_STDOUT}" ] && $CMD_ECHO "[$(date '+%Y/%m/%d %H:%M:%S')] [$$] [Error exit] $@"
	exit 1
}


exec_err() {
	"$@"
	status=$?
	if [ $status -ne 0 ]; then
		app_err_log "ERROR: Encountered error (${status}) while running the following:" >&2
		app_err_log "           $@"  >&2
		app_err_log "       (at line ${BASH_LINENO[0]} of file $0.)"  >&2
		app_err_log "       Aborting." >&2
		exit $status
	fi
}


print_caller()
{
	if [ -d "/proc/$PPID" ] && [ -f "/proc/$PPID/cmdline" ]; then
		app_log "caller:$PPID ($($CMD_CAT /proc/$PPID/cmdline) $@)"
	else
		app_log "caller:$PPID"
	fi
}


# config hosting html files by apache server
web_hosting()
{
	app_log "[ $FUNCNAME $@ ] ..."
	QPKG_APPWEB_LN_PATH="/mnt/ext/opt/apps/$QPKG_NAME"
	QPKG_APPWEB_ROOT_PATH="$QPKG_ROOT/web"
	QPKG_APPWEB_REDIRECT="$QPKG_ROOT/redirect/index.html"

	case "$1" in
		start)
			if [ ! -L "$QPKG_APPWEB_LN_PATH" ]; then
				# exec_err $CMD_LN -sf $QPKG_APPWEB_ROOT_PATH $QPKG_APPWEB_LN_PATH
				$CMD_MKDIR $QPKG_APPWEB_LN_PATH
				$CMD_CP $QPKG_APPWEB_REDIRECT $QPKG_APPWEB_LN_PATH
			elif [ ! -e "$QPKG_APPWEB_LN_PATH" ]; then
				# handle qpkg install volume changed and install path changed, fix web soft link"
				exec_err $CMD_RM $QPKG_APPWEB_LN_PATH
				# exec_err $CMD_LN -sf $QPKG_APPWEB_ROOT_PATH $QPKG_APPWEB_LN_PATH
				$CMD_MKDIR $QPKG_APPWEB_LN_PATH
				$CMD_CP $QPKG_APPWEB_REDIRECT $QPKG_APPWEB_LN_PATH
			fi
			;;
		stop)
			if [ -L "$QPKG_APPWEB_LN_PATH" ]; then
				exec_err $CMD_RM $QPKG_APPWEB_LN_PATH
			fi
			;;
	esac
	app_log "[ $FUNCNAME $@ ] done ..."
}


backend_server()
{
	app_log "[ $FUNCNAME $@ ] ..."
	local _pidfile="${QPKG_TMP}/httapi.pid"

	case "$1" in
		start)
			$QPKG_ROOT/start_server 1>>$QPKG_LOG_FILE 2>&1 &
			ret=$?
			echo $! > ${_pidfile}
			if [ "$ret" == "0" ]; then
				app_log "[ $FUNCNAME $@ ] done ..."
			else
				app_err_log "[ $FUNCNAME $@ ] fail ..."
			fi
			cd $QPKG_ROOT
			;;
		stop)
			# handle mutli stop when qpkg upgrade
			kill -0 $(cat ${_pidfile}) 2>/dev/null
			if [ "$?" == "0" ]; then
				kill $(cat ${_pidfile}) &>/dev/null
				if [ "$?" == "0" ]; then
					app_log "[ $FUNCNAME $@ ] ... done"
				else
					app_err_log "[ $FUNCNAME $@ ] ... fail"
				fi
			else
				app_log "[ $FUNCNAME $@ ] process not exist... done"
			fi
			[ -f ${_pidfile} ] && rm ${_pidfile}
			;;
	esac
}


qpkg_env()
{
	QPKG_CONF="/etc/config/qpkg.conf"
	QPKG_NAME="create-qpkg"
	QPKG_ROOT=`/sbin/getcfg $QPKG_NAME Install_Path -f ${QPKG_CONF}`
	QPKG_TMP="${QPKG_ROOT}/tmp"
	QPKG_LOG_FILE="${QPKG_TMP}/${QPKG_NAME}_sh.log"

	[ ! -d ${QPKG_TMP} ] && $CMD_MKDIR ${QPKG_TMP}
	export QNAP_QPKG=$QPKG_NAME
	export PATH=${CONTAINERSTATION_PATH}/bin:$PATH

	app_log "PWD: `pwd`"
	app_log "PATH: $PATH"
	app_log "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
}


###############################################################################
# prepare shell environment variable
qpkg_env;

cd $QPKG_ROOT &>/dev/null || (echo "install path not exist" && exit 1)
print_caller $@

case "$1" in
	start)
		app_log  "$0 $1 -- in"
		ENABLED=$(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f $QPKG_CONF)
		if [ "$ENABLED" != "TRUE" ]; then
			app_err_log "exit by $QPKG_NAME is disabled."
			exit 1
		fi
		web_hosting $1
		backend_server $1
		;;

	stop)
		web_hosting $1
		backend_server $1
		;;

	restart)
		$0 stop
		$0 start
		;;

	qpkg_env)
		qpkg_env
		;;

	*)
		if [ "$1" != "" ]; then
			app_log  "$0 $1 -- in"
			$1 $2 $3 $4;
			app_log  "$0 $1 -- done"
		else
			echo ""
			echo "Usage: $0 {start|stop|restart|qpkg_env}"
			echo ""
		fi
		;;
esac

exit 0
