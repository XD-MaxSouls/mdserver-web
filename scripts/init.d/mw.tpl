#!/bin/bash
# chkconfig: 2345 55 25
# description: MW Cloud Service

### BEGIN INIT INFO
# Provides:          Midoks
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts mw
# Description:       starts the mw
### END INIT INFO


PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export LANG=en_US.UTF-8

mw_path={$SERVER_PATH}
PATH=$PATH:$mw_path/bin


if [ -f $mw_path/bin/activate ];then
    source $mw_path/bin/activate
    if [ "$?" != "0" ];then
        echo "load local python env fail!"
    fi
fi

mw_start_panel()
{
    isStart=`ps -ef|grep 'gunicorn -c setting.py app:app' |grep -v grep|awk '{print $2}'`
    if [ "$isStart" == '' ];then
        echo -e "starting mw-panel... \c"
        cd $mw_path &&  gunicorn -c setting.py app:app
        port=$(cat ${mw_path}/data/port.pl)
        isStart=""
        while [[ "$isStart" == "" ]];
        do
            echo -e ".\c"
            sleep 0.5
            isStart=$(lsof -n -P -i:$port|grep LISTEN|grep -v grep|awk '{print $2}'|xargs)
            let n+=1
            if [ $n -gt 60 ];then
                break;
            fi
        done
        if [ "$isStart" == '' ];then
            echo -e "\033[31mfailed\033[0m"
            echo '------------------------------------------------------'
            tail -n 20 ${mw_path}/logs/error.log
            echo '------------------------------------------------------'
            echo -e "\033[31mError: mw-panel service startup failed.\033[0m"
            return;
        fi
        echo -e "\033[32mdone\033[0m"
    else
        echo "starting mw-panel... mw(pid $(echo $isStart)) already running"
    fi
}


mw_start_task()
{
    isStart=$(ps aux |grep 'task.py'|grep -v grep|awk '{print $2}')
    if [ "$isStart" == '' ];then
        echo -e "starting mw-tasks... \c"
        cd $mw_path && python3 task.py >> ${mw_path}/logs/task.log 2>&1 &
        sleep 0.3
        isStart=$(ps aux |grep 'task.py'|grep -v grep|awk '{print $2}')
        if [ "$isStart" == '' ];then
            echo -e "\033[31mfailed\033[0m"
            echo '------------------------------------------------------'
            tail -n 20 $mw_path/logs/task.log
            echo '------------------------------------------------------'
            echo -e "\033[31mError: mw-tasks service startup failed.\033[0m"
            return;
        fi
        echo -e "\033[32mdone\033[0m"
    else
        echo "starting mw-tasks... mw-tasks (pid $(echo $isStart)) already running"
    fi
}

mw_start()
{
    mw_start_task
	mw_start_panel
}

# /www/server/mdserver-web/tmp/panelTask.pl && service mw restart_task
mw_stop_task()
{
    if [ -f $mw_path/tmp/panelTask.pl ];then
        echo -e "\033[32mthe task is running and cannot be stopped\033[0m"
        exit 0
    fi

    echo -e "stopping mw-tasks... \c";
    pids=$(ps aux | grep 'task.py'|grep -v grep|awk '{print $2}')
    arr=($pids)
    for p in ${arr[@]}
    do
        kill -9 $p  > /dev/null 2>&1
    done
    echo -e "\033[32mdone\033[0m"
}

mw_stop_panel()
{
    echo -e "stopping mw-panel... \c";

    pidfile=${mw_path}/logs/mw.pid
    if [ -f $pidfile ];then
        pid=`cat $pidfile`
        kill -9 $pid > /dev/null 2>&1
        rm -f $pidfile
    fi

    arr=`ps aux|grep 'gunicorn -c setting.py app:app'|grep -v grep|awk '{print $2}'`
    for p in ${arr[@]}
    do
        kill -9 $p > /dev/null 2>&1
    done
    
    echo -e "\033[32mdone\033[0m"
}

mw_stop()
{
    mw_stop_task
    mw_stop_panel
}

mw_status()
{
    isStart=$(ps aux|grep 'gunicorn -c setting.py app:app'|grep -v grep|awk '{print $2}')
    if [ "$isStart" != '' ];then
        echo -e "\033[32mmw (pid $(echo $isStart)) already running\033[0m"
    else
        echo -e "\033[31mmw not running\033[0m"
    fi
    
    isStart=$(ps aux |grep 'task.py'|grep -v grep|awk '{print $2}')
    if [ "$isStart" != '' ];then
        echo -e "\033[32mmw-task (pid $isStart) already running\033[0m"
    else
        echo -e "\033[31mmw-task not running\033[0m"
    fi
}


mw_reload()
{
	isStart=$(ps aux|grep 'gunicorn -c setting.py app:app'|grep -v grep|awk '{print $2}')
    
    if [ "$isStart" != '' ];then
    	echo -e "reload mw... \c";
	    arr=`ps aux|grep 'gunicorn -c setting.py app:app'|grep -v grep|awk '{print $2}'`
		for p in ${arr[@]}
        do
                kill -9 $p
        done
        cd $mw_path && gunicorn -c setting.py app:app
        isStart=`ps aux|grep 'gunicorn -c setting.py app:app'|grep -v grep|awk '{print $2}'`
        if [ "$isStart" == '' ];then
            echo -e "\033[31mfailed\033[0m"
            echo '------------------------------------------------------'
            tail -n 20 $mw_path/logs/error.log
            echo '------------------------------------------------------'
            echo -e "\033[31mError: mw service startup failed.\033[0m"
            return;
        fi
        echo -e "\033[32mdone\033[0m"
    else
        echo -e "\033[31mmw not running\033[0m"
        mw_start
    fi
}

mw_close(){
    echo 'True' > $mw_path/data/close.pl
}

mw_open()
{
    if [ -f $mw_path/data/close.pl ];then
        rm -rf $mw_path/data/close.pl
    fi
}

mw_unbind_domain()
{
    if [ -f $mw_path/data/bind_domain.pl ];then
        rm -rf $mw_path/data/bind_domain.pl
    fi
}

error_logs()
{
	tail -n 100 $mw_path/logs/error.log
}

mw_update()
{
    LOCAL_ADDR=common
    ping  -c 1 github.com > /dev/null 2>&1
    if [ "$?" != "0" ];then
        LOCAL_ADDR=cn
    fi
    if [ "$LOCAL_ADDR" == "common" ];then
        curl --insecure -fsSL https://raw.githubusercontent.com/midoks/mdserver-web/master/scripts/update.sh | bash
    else
        curl --insecure -fsSL  https://code.midoks.me/midoks/mdserver-web/raw/branch/dev/scripts/update.sh | bash
    fi
}

mw_update_dev()
{
    LOCAL_ADDR=common
    ping  -c 1 github.com > /dev/null 2>&1
    if [ "$?" != "0" ];then
        LOCAL_ADDR=cn
    fi
    if [ "$LOCAL_ADDR" == "common" ];then
        curl --insecure -fsSL https://raw.githubusercontent.com/midoks/mdserver-web/dev/scripts/update_dev.sh | bash
    else
        curl --insecure -fsSL https://code.midoks.me/midoks/mdserver-web/raw/branch/dev/scripts/update_dev.sh | bash
    fi
    cd /www/server/mdserver-web
}

mw_mirror()
{
    LOCAL_ADDR=common
    ping  -c 1 github.com > /dev/null 2>&1
    if [ "$?" != "0" ];then
        LOCAL_ADDR=cn
    fi
    if [ "$LOCAL_ADDR" == "common" ];then
        bash <(curl --insecure -sSL https://raw.githubusercontent.com/midoks/change-linux-mirrors/main/change-mirrors.sh)
    else
        bash <(curl --insecure -sSL https://gitee.com/SuperManito/LinuxMirrors/raw/main/ChangeMirrors.sh)
    fi
    cd /www/server/mdserver-web
}

mw_install_app()
{
    bash $mw_path/scripts/quick/app.sh
}

mw_close_admin_path(){
    if [ -f $mw_path/data/admin_path.pl ]; then
        rm -rf $mw_path/data/admin_path.pl
    fi
}

mw_force_kill()
{
    PLIST=`ps -ef|grep app:app |grep -v grep|awk '{print $2}'`
    for i in $PLIST
    do
        kill -9 $i
    done

    pids=`ps -ef|grep task.py | grep -v grep |awk '{print $2}'`
    arr=($pids)
    for p in ${arr[@]}
    do
        kill -9 $p
    done
}

mw_debug(){
    mw_stop
    mw_force_kill

    port=7200    
    if [ -f $mw_path/data/port.pl ];then
        port=$(cat $mw_path/data/port.pl)
    fi

    if [ -d /www/server/mdserver-web ];then
        cd /www/server/mdserver-web
    fi
    gunicorn -b :$port -k geventwebsocket.gunicorn.workers.GeventWebSocketWorker -w 1  app:app
}

case "$1" in
    'start') mw_start;;
    'stop') mw_stop;;
    'reload') mw_reload;;
    'restart') 
        mw_stop
        mw_start;;
    'restart_panel')
        mw_stop_panel
        mw_start_panel;;
    'restart_task')
        mw_stop_task
        mw_start_task;;
    'status') mw_status;;
    'logs') error_logs;;
    'close') mw_close;;
    'open') mw_open;;
    'update') mw_update;;
    'update_dev') mw_update_dev;;
    'install_app') mw_install_app;;
    'close_admin_path') mw_close_admin_path;;
    'unbind_domain') mw_unbind_domain;;
    'debug') mw_debug;;
    'mirror') mw_mirror;;
    'default')
        cd $mw_path
        port=7200
        
        if [ -f $mw_path/data/port.pl ];then
            port=$(cat $mw_path/data/port.pl)
        fi

        if [ ! -f $mw_path/data/default.pl ];then
            echo -e "\033[33mInstall Failed\033[0m"
            exit 1
        fi

        password=$(cat $mw_path/data/default.pl)
        if [ -f $mw_path/data/domain.conf ];then
            address=$(cat $mw_path/data/domain.conf)
        fi
        if [ -f $mw_path/data/admin_path.pl ];then
            auth_path=$(cat $mw_path/data/admin_path.pl)
        fi
	    
        if [ "$address" == "" ];then
            v4=$(python3 $mw_path/tools.py getServerIp 4)
            v6=$(python3 $mw_path/tools.py getServerIp 6)

            if [ "$v4" != "" ] && [ "$v6" != "" ]; then

                if [ ! -f $mw_path/data/ipv6.pl ];then
                    echo 'True' > $mw_path/data/ipv6.pl
                    mw_stop
                    mw_start
                fi

                address="MW-Panel-Url-Ipv4: http://$v4:$port$auth_path \nMW-Panel-Url-Ipv6: http://[$v6]:$port$auth_path"
            elif [ "$v4" != "" ]; then
                address="MW-Panel-Url: http://$v4:$port$auth_path"
            elif [ "$v6" != "" ]; then

                if [ ! -f $mw_path/data/ipv6.pl ];then
                    #  Need to restart ipv6 to take effect
                    echo 'True' > $mw_path/data/ipv6.pl
                    mw_stop
                    mw_start
                fi
                address="MW-Panel-Url: http://[$v6]:$port$auth_path"
            else
                address="MW-Panel-Url: http://you-network-ip:$port$auth_path"
            fi
        else
            address="MW-Panel-Url: http://$address:$port$auth_path"
        fi

        show_panel_ip="$port|"
        echo -e "=================================================================="
        echo -e "\033[32mMW-Panel default info!\033[0m"
        echo -e "=================================================================="
        echo -e "$address"
        echo -e `python3 $mw_path/tools.py username`
        echo -e `python3 $mw_path/tools.py password`
        # echo -e "password: $password"
        echo -e "\033[33mWarning:\033[0m"
        echo -e "\033[33mIf you cannot access the panel. \033[0m"
        echo -e "\033[33mrelease the following port (${show_panel_ip}888|80|443|22) in the security group.\033[0m"
        echo -e "=================================================================="
        ;;
    *)
        cd $mw_path && python3 $mw_path/tools.py cli $1
        ;;
esac
