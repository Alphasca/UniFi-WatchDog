#!/bin/bash

# IP ADDRESS TO PING
EXT_IP=8.8.4.4
INT1_IP=gateway
INT2_IP=10.31.32.254

# FAILURE COUNT TO REBOOT
maxpingfail=10

# Ping count
pingcount=1

#STARTUP DELAY (sec)
delay=300

# Ping fail count file
pingfailcountfile=/var/log/watchdogpingfailcount

# Watchdog startup delay file
watchdogdelayfile=/var/log/watchdogdelayfile

# Watchdog logfile
watchdoglogfile=/var/log/watchdog.log

# UnixTime Now
timenow=`date +%s`

result="success"

# Logfile check
if [ ! -f $watchdoglogfile ] ; then
	touch $watchdoglogfile
	echo "`date '+%Y-%m-%d %H:%M:%S'` - [?/?/?] Start log" > $watchdoglogfile
fi

# Load watchdog startup delay
if [ -f $watchdogdelayfile ] ; then
	watchdogdelay=`cat $watchdogdelayfile`
else
	touch $watchdogdelayfile
	watchdogdelay=$timenow
	echo "$timenow" > $watchdogdelayfile
	echo "`date '+%Y-%m-%d %H:%M:%S'` - [?/?/?] Watchdog startup delay file created!" >> $watchdoglogfile
fi


# Load ping fail counter
if [ -f $pingfailcountfile ] ; then
	pingfailcount=`cat $pingfailcountfile`
else
	touch $pingfailcountfile
	echo "0" > $pingfailcountfile
fi

if [ "$EXT_IP" = "gateway" ] ; then
	EXT_IP=`ip route | awk '/default/{print$3}'`
fi

if [ "$INT1_IP" = "gateway" ] ; then
	INT1_IP=`ip route | awk '/default/{print$3}'`
fi

if [ "$INT2_IP" = "gateway" ] ; then
	INT2_IP=`ip route | awk '/default/{print$3}'`
fi

#echo "`date '+%Y-%m-%d %H:%M:%S'` - [?/?/?] Watchdog started ( $timenow $watchdogdelay $delay $pingfailcountfile $pingfailcount)" >> $watchdoglogfile
if [ "$[$timenow-$watchdogdelay]" -ge "$delay" ] ; then
	#echo "`date '+%Y-%m-%d %H:%M:%S'` - [?/?/?] Start ping EXTERNAL IP ($EXT_IP)" >> $watchdoglogfile
	sudo /bin/ping -c$pingcount $EXT_IP &> /dev/null && result="success" || result="fail"
	if [ "$result" = "fail" ] ; then
		#echo "`date '+%Y-%m-%d %H:%M:%S'` - [F/?/?] Start ping INTERNAL IP ($INT1_IP)" >> $watchdoglogfile
		sudo /bin/ping -c$pingcount $INT1_IP &> /dev/null && result="success" || result="fail"
		if [ "$result" = "fail" ] ; then
			#echo "`date '+%Y-%m-%d %H:%M:%S'` - [F/F/?] Start ping INTERNAL IP ($INT2_IP)" >> $watchdoglogfile
			sudo /bin/ping -c$pingcount $INT2_IP &> /dev/null && result="success" || result="fail"
			if [ "$result" = "fail" ] ; then
				let "pingfailcount += 1"
				echo "$pingfailcount" > $pingfailcountfile
				#echo "`date '+%Y-%m-%d %H:%M:%S'` - [F/F/F] pingfailcount:  $pingfailcount , maxpingfail: $maxpingfail" >> $watchdoglogfile
				if [ "$pingfailcount" -ge "$maxpingfail" ] ; then
					echo "`date '+%Y-%m-%d %H:%M:%S'` - [F/F/F] All pings failed! [Count: $pingfailcount] Reboot NOW!" >> $watchdoglogfile
					/sbin/reboot
				else
					echo "`date '+%Y-%m-%d %H:%M:%S'` - [F/F/F] All pings failed! [Count: $pingfailcount]" >> $watchdoglogfile
				fi
			else
				echo "`date '+%Y-%m-%d %H:%M:%S'` - [F/F/T] EXTERNAL IP ($EXT_IP) and INTERNAL IP ($INT1_IP) didn't ping" >> $watchdoglogfile
				if [ "$pingfailcount" -ge "0" ] ; then
					echo "0" > $pingfailcountfile
				fi
			fi
		else
			echo "`date '+%Y-%m-%d %H:%M:%S'` - [F/T/?] EXTERNAL IP ($EXT_IP) didn't ping" >> $watchdoglogfile
			if [ "$pingfailcount" -ge "0" ] ; then
				echo "0" > $pingfailcountfile
			fi
		fi
	else
		#echo "`date '+%Y-%m-%d %H:%M:%S'` - [T/?/?] All good! " >> $watchdoglogfile
		if [ "$pingfailcount" -ge "0" ] ; then
			echo "0" > $pingfailcountfile
		fi
	fi
else
	echo "`date '+%Y-%m-%d %H:%M:%S'` - STARTUP DELAY. Need waite $[$delay-$[$[$timenow-$watchdogdelay]]] sec for start monitoring." >> $watchdoglogfile
fi
