#!/bin/bash
 
####### CONFIG START  ########
 
OWNER_NAME='root' # Пользователь, которому будет принадлежать директория вирт. хоста 
OWNER_GROUP='root' # Группа, которой будет принадлежать директория вирт. хоста 
HOME_WWW=/sites # Домашняя директория для вирт. хостов 
HOST_DIRS=('logs' 'www') 
SERVER_IP='127.0.0.1' # IP адрес сервера
 
WHEREIS_NGINX=/etc/nginx
 
NGINX_HOSTS_DIR=$WHEREIS_NGINX'/sites-available'
NGINX_HOSTS_ENABLED=$WHEREIS_NGINX'/sites-enabled'
 
######## CONFIG END ##########
 
# COLORS
SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"
SETCOLOR_NOTICE="echo -en \\033[1;33;40m"
 
# FUNCTIONS
 
function restart_servers {
 
    echo 'Перезапускаем Nginx'
    /etc/init.d/nginx reload
 
    return 1
}
 
function error_config {
    $SETCOLOR_FAILURE
    echo "$(tput hpa $(tput cols))$(tput cub 6)[Fail]"
    echo '[CONFIG ERROR]: '$1
    $SETCOLOR_NORMAL
 
    exit
}
 
function error_force_exec {
    $SETCOLOR_FAILURE
    echo "$(tput hpa $(tput cols))$(tput cub 6)[Fail]"
    echo -n '[FORCE EXEC ERROR]: '
 
    if [ -z "$1" ]; then
	echo 'Скрипт не может корректно выполнить все процедуры в автоматическом режиме'
    else
	echo $1
    fi
 
    $SETCOLOR_NORMAL
 
    exit
}
 
function error_failure {
    $SETCOLOR_FAILURE
    echo "$(tput hpa $(tput cols))$(tput cub 6)[Fail]"
    echo '[ERROR]: '$1
    $SETCOLOR_NORMAL
 
    exit
}
 
function error_notice {
    $SETCOLOR_NOTICE
    echo '[NOTICE]: '$1
    $SETCOLOR_NORMAL
 
    return 1
}
 
# Если запущен с ключем -f, значит задаем пользователю минимум вопросов 
# Игнорируются вопросы: 
# - имя директории виртуального хоста 
# - вопрос о перезапуске серверров (будут перезапущены)
 
if [ "$1" == "-f" ]; then
    force_execution=true
else
    force_execution=false
fi
 
echo
 
$SETCOLOR_NORMAL
 
if [ -d $HOME_WWW ]; then
    cd $HOME_WWW
else
    error_config "Директория $HOME_WWW не существует"
fi
 
# Запрашивает имя домена, пока не будет введено
function get_domain_name {
    echo -n "Имя домена: "
    read domain_name
 
    # Если ничего не было введено
    if [ -z $domain_name ]; then
	$SETCOLOR_FAILURE
	echo "Вы не ввели имя домена"
	$SETCOLOR_NORMAL
	get_domain_name
    else
	return 1
    fi
}
 
# Запрашивает имя директории для виртуального хоста или предлагает создать автоматически 
# проверяет его на существование
function get_host_dir {
    echo -n "Имя директории хоста: "
    read host_dir
 
    # Если ничего не было введено
    if [ -z $host_dir ]; then
	$SETCOLOR_NOTICE
	echo -n "Вы не ввели имя директории хоста. Создать автоматически? [Н/д]? "
	$SETCOLOR_NORMAL
 
	read answer
 
	    case "$answer" in
	    Y|y|д|Д)
		host_dir=${domain_name//\./_}
		host_dir=${host_dir//\-/}
 
		if [ -d ${HOME_WWW}'/'${host_dir} ]; then
		    error_notice "Автоматический выбор имени директории невозможен. Задайте его самостоятельно"
		    get_host_dir
		else
		    error_notice "Директория хоста будет создана автоматически: $host_dir"
		fi
		return 1
		;;
	    N|n|о|О) get_host_dir
		;;
	    *) get_host_dir
		;;
	    esac
	get_host_dir
    else
	return 1
    fi
}
 
get_domain_name
 
if $force_execution; then
    host_dir=${domain_name//\./_}
 
    if [ -d ${HOME_WWW}'/'${host_dir} ]; then
	error_force_exec
    fi
else
    get_host_dir
fi
 
# Проверяем пути nginx из конфига
if [ -d $NGINX_HOSTS_DIR ]; then
    if [ -a $NGINX_HOSTS_DIR'/'$domain_name ]; then
        error_failure "Виртуальный хост $domain_name уже существует Nginx"
    fi
else
    error_config "Директория $NGINX_HOSTS_DIR не существует"
fi
 
echo "Домен: $domain_name"
 
# Создаем директории виртуального хоста
host_dir_path=${HOME_WWW}'/'${host_dir}
echo "Создаем директории виртуального хоста:"
 
mkdir $host_dir_path
#mkdir $host_dir_path/www
#mkdir $host_dir_path/logs
for dir_name in ${HOST_DIRS[@]}; do
	mkdir $host_dir_path'/'$dir_name
	echo -e "\t $host_dir_path/$dir_name"
done
 
touch ${host_dir_path}'/www/index.html'
 
# Рекурсивно проставляем права
chown -R $OWNER_NAME:$OWNER_GROUP $host_dir_path
 
# создаем симлинк
a2ensite $domain_name
 
nginx_template="server {
      listen *:80;
 
      server_name $domain_name www.$domain_name;
      access_log  $HOME_WWW/$host_dir/logs/nginx.access.log;
 
      location ~* ^.+\.(jpg|jpeg|gif|png|svg|js|css|mp3|ogg|mpe?g|avi|zip|gz|bz2?|rar) {
            root $HOME_WWW/$host_dir/www;
      }
 
 
      location / {
            proxy_pass http://backend;
            proxy_redirect off;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
 
            charset utf-8;
            index index.html;
            root $HOME_WWW/$host_dir/www;
      }
}"
 
 
# Создаем конфиг виртуального хоста nginx
echo 'Создаем конфиг виртуального хоста nginx:'
touch ${NGINX_HOSTS_DIR}'/'${domain_name}
echo -e "\t"${NGINX_HOSTS_DIR}'/'${domain_name}
 
temp_ifs=$IFS
IFS=
echo $nginx_template > ${NGINX_HOSTS_DIR}'/'$domain_name
IFS=$temp_ifs
 
# создаем симлинк
ln -s $NGINX_HOSTS_DIR'/'$domain_name $NGINX_HOSTS_ENABLED'/'$domain_name
 
# Перезапускаем сервера
if $force_execution; then
    restart_servers
else
    echo -n 'Перезапустить Nginx? [Д/н] '
    read restart_answer
 
    case "$restart_answer" in
	Y|y|д|Д)
	    restart_servers
	;;
	*)
	    echo 'Nginx не был перезагружен'
	;;
    esac
 
fi
 
$SETCOLOR_SUCCESS
echo "$(tput hpa $(tput cols))$(tput cub 6)[OK]"
$SETCOLOR_NORMAL
