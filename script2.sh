#!/bin/bash

####### CONFIG START  ########
 
NGINXPATH='/etc/nginx/' # Путь Nginx

####### CONFIG END  ########

EXP4FND='-type f -name '*.conf''

SERVERNAME=$(find $NGINXPATH $EXP4FND -exec cat {} \;| grep server_name | awk '{print $2}' | paste -sd, )
SERVERNAMEOUT=$(find $NGINXPATH $EXP4FND -exec cat {} \;| grep server_name | awk '{print $1 NR, $2}' )
IFS=\, read SERVERNAME1 SERVERNAME2 SERVERNAME3 SERVERNAME4 SERVERNAME5 <<< $SERVERNAME
KEYGEN=$(shuf -e {A..Z} {a..z} {0..9} -zrn16 | xargs -0 | sed s/' '//g )

echo -e "$SERVERNAMEOUT" 

#Заполняем json
JSONBODY="{
	\"key\": \"<$KEYGEN>\" ,
	\"vhosts\": \"<$SERVERNAME1, $SERVERNAME2, $SERVERNAME3, $SERVERNAME4, $SERVERNAME5> \"
}"

echo "Введите имя формируемого файла"
read NAMEJSON

temp_ifs=$IFS
IFS=
echo $JSONBODY > $NAMEJSON.json
IFS=$temp_ifs

echo "Файл $NAMEJSON.json сформирован"

echo "Введите адрес для POST запроса (example: http(s)://example.com"
read postadress

curl --location -request POST $postadress -H "Content-Type: application/json"  -F "json=@$NAMEJSON.json"
