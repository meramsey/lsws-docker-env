#!/usr/bin/env bash
CK_RESULT=''
LSDIR='/usr/local/lsws'
HTTPD_CONF='' 

help_message(){
    echo 'Command [-add|-del] [domain_name]'
    echo 'Example 1: domainctl.sh -add example.com'
    echo 'Example 2: domainctl.sh -del example.com'
}

check_lsv(){
    if [ -f ${LSDIR}/bin/litespeed ]; then
        LSV='lsws'
        HTTPD_CONF="${LSDIR}/conf/httpd_config.xml"
    elif [ -f ${LSDIR}/bin/openlitespeed ]; then
        LSV='openlitespeed'
        HTTPD_CONF="${LSDIR}/conf/httpd_config.conf"
    else
        echo 'Version not exist, abort!'
        exit 1     
    fi
}

dot_escape(){
    ESCAPE=$(echo ${1} | sed 's/\./\\./g')
}  

check_duplicate(){
    CK_RESULT=$(grep -E "${1}" ${2})
}

fst_match_line(){
    FIRST_LINE_NUM=$(grep -n -m 1 ${1} ${2} | awk -F ':' '{print $1}')
}
fst_match_after(){
    FIRST_NUM_AFTER=$(tail -n +${1} ${2} | grep -n -m 1 ${3} | awk -F ':' '{print $1}')
}
lst_match_line(){
    fst_match_after ${1} ${2} ${3}
    LAST_LINE_NUM=$((${FIRST_LINE_NUM}+${FIRST_NUM_AFTER}-1))
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

check_www(){
    CHECK_WWW=$(echo ${1} | cut -c1-4)
    if [[ ${CHECK_WWW} == www. ]] ; then
        echo 'www domain shoudnt be passed!'
        exit 1
    fi
}

www_domain(){
    check_www ${1}
    WWW_DOMAIN=$(echo www.${1})
}

add_domain(){
    check_lsv
    dot_escape ${1}
    DOMAIN=${ESCAPE}
    www_domain ${1}
    if [ "${LSV}" = 'lsws' ]; then
        check_duplicate "vhDomain.*${DOMAIN}" ${HTTPD_CONF}
    elif [ "${LSV}" = 'openlitespeed' ]; then
        check_duplicate "member.*${DOMAIN}" ${HTTPD_CONF}
    fi
    if [ "${CK_RESULT}" != '' ]; then
        echo "# It appears the domain already exist! Check the ${HTTPD_CONF} if you believe this is a mistake!"
        exit 1
    else
        if [ "${LSV}" = 'lsws' ]; then
            fst_match_line 'ccl.xml</templateFile>' ${HTTPD_CONF}
            NEWNUM=$((FIRST_LINE_NUM+1))
            sed -i "${NEWNUM}i \ \ \ \ \ \ <member>\n \ \ \ \ \ \ \ <vhName>${1}</vhName>\n \ \ \ \ \ \ \ <vhDomain>${1},${WWW_DOMAIN}</vhDomain>\n \ \ \ \ \ \ </member>" ${HTTPD_CONF}
        elif [ "${LSV}" = 'openlitespeed' ]; then    
            perl -0777 -p -i -e 's/(vhTemplate centralConfigLog \{[^}]+)\}*(^.*listeners.*$)/\1$2
  member '${1}' {
    vhDomain              '${1},${WWW_DOMAIN}'
  }/gmi' ${HTTPD_CONF}
        fi
    fi
}

del_domain(){
    check_lsv
    dot_escape ${1}
    DOMAIN=${ESCAPE}
    if [ "${LSV}" = 'lsws' ]; then
        check_duplicate "vhDomain.*${DOMAIN}" ${HTTPD_CONF}
    elif [ "${LSV}" = 'openlitespeed' ]; then
        check_duplicate "member.*${DOMAIN}" ${HTTPD_CONF}
    fi
    if [ "${CK_RESULT}" = '' ]; then
        echo "# We couldn't find the domain you wanted to remove! Check the ${HTTPD_CONF} if you believe this is a mistake!"
        exit 1
    else
        if [ "${LSV}" = 'lsws' ]; then
            fst_match_line "<vhName>*${1}" ${HTTPD_CONF}
            FIRST_LINE_NUM=$((FIRST_LINE_NUM-1))
            lst_match_line ${FIRST_LINE_NUM} ${HTTPD_CONF} '</member>'
            sed -i "${FIRST_LINE_NUM},${LAST_LINE_NUM}d" ${HTTPD_CONF}
        elif [ "${LSV}" = 'openlitespeed' ]; then     
            fst_match_line ${1} ${HTTPD_CONF}
            lst_match_line ${FIRST_LINE_NUM} ${HTTPD_CONF} '}'
            sed -i "${FIRST_LINE_NUM},${LAST_LINE_NUM}d" ${HTTPD_CONF}
        fi    
    fi
}

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -add | -a | -A) shift
            add_domain ${1}
            ;;
        -del | -d | -D | -delete) shift
            del_domain ${1}
            ;;          
        *) 
            help_message
            ;;
    esac
    shift
done