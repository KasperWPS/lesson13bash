#!/bin/bash

#sort --version
#sort (GNU coreutils) 9.4
#Packaged by Gentoo (9.4 (p0))

#uniq --version
#uniq (GNU coreutils) 9.4
#Packaged by Gentoo (9.4 (p0))

#grep --version
#grep (GNU grep) 3.11

# Если есть файл статус - значит скрипт запущен или был прерван в процессе работы
# TODO: реализовать проверку unix timestamp создания
if [ -f ./.status ]; then
    exit 0
fi
touch ./.status

#Log apache
originallog=./apache_logs

apachelog=`mktemp`
email=`mktemp`

fproc=0

startline=1
# В .previous последняя строка лога обработанная впрошлый раз
if [ -f ./.previous ]; then
    laststr=`tail -n 1 ./.previous | sed 's/\[/\\\[/g; s/\]/\\\]/g'`
    startline=`grep -nx ./apache_logs -e "${laststr}" | awk -F ':' '{print $1}'`

    # Если искомой строки нет, начинаем с начала файла
    if [[ -z ${startline} ]]; then
        startline=0
    fi

    # Всего строк в файле
    count=`wc -l ${originallog} | awk '{print $1}'`
    count_get=$(( ${count}-${startline}  ))

    if [[ ${count_get} < 1 ]]; then
        fproc=1
    fi

    tail -n ${count_get} ${originallog} > ${apachelog}
else
    cat ${originallog} > ${apachelog}
fi

if [ ${fproc} -eq 0 ]; then
    dbegin=`head -n 1 ${apachelog} | awk '{sub(/\[/,"",$4); print $4}' | sed 's/\([0-9]\{2\}\)\/\([A-z]\{3\}\)\/\([0-9]\{4\}\):\([0-9]\{2\}\):\([0-9]\{2\}\):\([0-9]\{2\}\)/\1 \2 \3 \4:\5:\6/i'`
    dlast=`tail -n 1 ${apachelog} | awk '{sub(/\[/,"",$4); print $4}' | sed 's/\([0-9]\{2\}\)\/\([A-z]\{3\}\)\/\([0-9]\{4\}\):\([0-9]\{2\}\):\([0-9]\{2\}\):\([0-9]\{2\}\)/\1 \2 \3 \4:\5:\6/i'`

    echo "Статистика по логу apache с ${dbegin} по ${dlast}" > ${email}

    echo -e "\nTop-10 ip-адресов по количеству запросов" >> ${email}
    cat ${apachelog} | grep -o "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}" | sort | uniq -cd | sort -nr | head | awk '{print $1,":",$2}' >> ${email}

    echo -e "\nTop-10 запросов" >> ${email}
    awk '{print $7}' ${apachelog} | sort | uniq -cd | sort -nr | head | awk '{print $1,":",$2}' >> ${email}

    echo -e "\nВсе коды возврата" >> ${email}
    awk '{print $9}' ${apachelog} | sort | uniq -cd | sort -nr | awk '{print $1,":",$2}' >> ${email}

    echo -e "\nКоды отличные от кода 200" >> ${email}
    awk '{if ($9 != "200") print $9,"",$7}' ${apachelog} | sort | uniq -cd >> ${email}

    tail -n 1 ${apachelog} > ./.previous

    cat ${email} | mail -s "Apache log" kasper_wps@mail.ru
fi

rm ${email}
rm ${apachelog}
rm ./.status
