#!/bin/bash

# This shell script was based on the version:
# DiG 9.8.2rc1-RedHat-9.8.2-0.62.rc1.el6_9.1

if [ ! -t 0 ]; then
    #there is input comming from pipe or file, add to the end of $@
    set -- $(cat) "${@}"
fi

script_name=$(basename $0)

list_files=()
list_in_files=()
list_addresses=()
list_domains=()

ip_regex_pattern='(([[:digit:]]|[1-9][[:digit:]]|1[[:digit:]][[:digit:]]|2[0-4][[:digit:]]|25[0-5])\.){3}([[:digit:]]|[1-9][[:digit:]]|1[[:digit:]][[:digit:]]|2[0-4][[:digit:]]|25[0-5])'

function cmd_chk() {
    type dig > /dev/null 2>&1
    if [ "${?}" != 0 ]; then
        echo -e "dig: command not found\nPlease try: 'yum -y install bind-utils'\nThis script is based on the dig version: DiG 9.8.2rc1-RedHat-9.8.2-0.62.rc1.el6_9.1"
        exit 1
    else
        cmd=$(which dig)
    fi
}

function help_info() {
    echo ""
    echo "Usage: ${script_name} [options] list_file|host_name [list_file2] [host_name2] [record_type] [@nameserver]"
    echo ""
    echo "Supported record type: SOA, NS, MX, A, AAAA, CNAME, PTR, TXT, ANY"
    echo "Nameserver ipv4 address is supported only."
    echo "If host_name is a ip address or there are ip addresses in the"
    echo "list_file, than this shell script will query PTR record for them"
    echo "automatically."
    echo "options:"
    echo "	-a  dispaly anwser section only"
    echo "	-b  separate replied infromation with blank line for each query"
    echo "	-c  classify NS records"
    echo "	-h --help"
    echo "	    dispaly help information"
    echo ""
    echo "Example:"
    echo "${script_name} -a dmlist.txt dmlist2.txt"
    echo "${script_name} www.example.com -a"
    echo "${script_name} dmlist.txt cname"
    echo "${script_name} www.example.com ns @8.8.8.8"
    echo "${script_name} soa dmlist.txt"
    echo "${script_name} @8.8.8.8 aaaa -ab dmlist.txt"
    echo "${script_name} 119.9.5.12"
    echo "${script_name} cat dmlist.txt |cldig.sh cname"
    echo "cat dmlist.txt |${script_name} cname"
    echo ""
}

function cs_nsrv_if() {
    if [ "${nsrv_val}" != "1" ]; then
        nsrv="${1}"
        nsrv_val=1
    fi
}

function cs_tp_if() {
    if [ "${tp_val}" != "1" ]; then
        tp_in="-t ${1}"
        tp_val=1
    fi
}

function cs_arg_tgt() {
    if [ -f "${1}" ]; then
        list_files+=("${1}")
    elif [[ "${1}" =~ ^$ip_regex_pattern$ ]]; then
        list_addresses+=("${1}")
    else
        list_domains+=("${1}")
    fi
}

function arg_chk() {
    case ${1} in
        -*)
            if [[ ${1} =~ ^-.*h ]] || [ "${1}" == "--help" ]; then
                help_info
                exit 0
            fi
            if [[ ${1} =~ ^-.*a ]]; then
                ans_only=1
            fi
            if [[ ${1} =~ ^-.*b ]]; then
                blk_ln=1
            fi
            if [[ ${1} =~ ^-.*c ]]; then
                clasfy=1
            fi
            ;;
        @*)
            if ! [[ ${1} =~ ^@$ip_regex_pattern$ ]]; then
                echo "${script_name}: couldn't get address for '${1}': not found" | sed 's/@//g'
                exit 1
            fi
            ${cmd} net. ${1} > /dev/null 2>&1
            if [ "${?}" == 9 ]; then
                echo ";; connection timed out; no servers could be reached"
                exit 1
            fi
            cs_nsrv_if ${1}
            ;;
        [sS][oO][aA])
            cs_tp_if ${1}
            ;;
        [nN][sS])
            cs_tp_if ${1}
            ;;
        [mM][xX])
            cs_tp_if ${1}
            ;;
        [aA])
            cs_tp_if ${1}
            ;;
        [aA][aA][aA][aA])
            cs_tp_if ${1}
            ;;
        [cC][nN][aA][mM][eE])
            cs_tp_if ${1}
            ;;
        [pP][tT][rR])
            cs_tp_if ${1}
            ;;
        [tT][xX][tT])
            cs_tp_if ${1}
            ;;
        [aA][nN][yY])
            cs_tp_if ${1}
            ;;
        *)
            cs_arg_tgt ${1}
            ;;
    esac
}

function get_nsrv_and_time() {
    nsrv_and_time=$(${cmd} ${nsrv} | /bin/egrep 'SERVER|WHEN')
}

function add_domains_in_files() {
if [ ${#list_files[@]} -gt 0 ];then
    trap "exit" INT
    for file in ${list_files[@]}
    do
        list_in_files+=($(cat $file))
    done

    trap "exit" INT
    for element in ${list_in_files[@]}
    do
        if [[ "${element}" =~ ^$ip_regex_pattern$ ]];then
            list_addresses+=("${element}")
        else
            list_domains+=("$element")
        fi
    done
fi

}


cmd_chk
ans_only=0
clasfy=0
condition="| /bin/egrep 'IN.*[[:upper:]]'"
classify_condition=''

while (( ${#} != 0 ))
do
    arg_chk ${*}
    shift
done

add_domains_in_files

if  [ ${#list_domains[@]} -eq 0 ] && [ ${#list_addresses[@]} -eq 0 ]; then
    echo "You must indicate at least one domain name or a domain list file first."
    help_info
    exit 1
else
    get_nsrv_and_time
fi


if [ "${ans_only}" == 1 ]; then
    condition="| /bin/egrep -v '^;|^$'"
fi
if [ "${clasfy}" == 1 ] && [[ "${tp_in}" =~ [nN][sS] ]]; then
    condition="| /bin/egrep -v '^;|^$'"
    classify_condition="|sed -r -e 's/pdns246.ultradns.(org|biz|com|net)\\./ultradns/g' -e 's/(fay|sid).ns.cloudflare.com\\./cloudflare1/g' -e 's/(gabe|coco).ns.cloudflare.com\\./cloudflare ?/g' -e 's/(a|b|c).dnspod.com\\./dnspod/g' -e 's/f1g1ns[1,2].dnspod.net\\./dnspod.cn/g' -e 's/p?ns[0-9]*.cloudns.net./cloudns/g' -e 's/dns[1-3].zoneedit.com\\./zoneedit/g' -e 's/dns(8|12|15).pointhq.com\\./pointhq3/g' -e 's/dns14.pointhq.com\\./pointhq2/g' -e 's/dns(4|6|7|9|10|11).pointhq.com\\./pointhq1/g' -e 's/(deb|todd).ns.cloudflare.com\\./cloudflare2/g' -e 's/dns[0-9]+.hichina.com\\./hichina/g' -e 's/ns(1|2|3|4|5).he.net\\./hurricane_electric/g' -e 's/ns[0-9]+\\.domaincontrol.com\\./godaddy/g' -e 's/ns(1|2).hover.com\\./hover/g' |sort |uniq |sed -e 's/com\\..*\\t/com\\t/g' -e 's/net\\..*\\t/net\\t/g' -e 's/org\\..*\\t/org\\t/g' -e 's/info\\..*\\t/info\\t/g' -e 's/space\\..*\\t/space\\t/g' -e 's/biz\\..*\\t/biz\\t/g' -e 's/vip\\..*\\t/vip\\t/g' -e 's/club\\..*\\t/club\\t/g' -e 's/me\\..*\\t/me\\t/g' -e 's/co\\..*\\t/co\\t/g' -e 's/cc\\..*\\t/cc\\t/g' -e '/pointhq2/{n;d}' -e '/pointhq1/{n;d}'"
fi


if [ ${#list_domains[@]} -gt 0 ];then
    trap "exit" INT
    for domain in ${list_domains[@]}
    do
        domain=${domain%,}
        eval ${cmd} ${domain} ${tp_in} ${nsrv} ${condition} ${classify_condition}
        if [ "${blk_ln}" == 1 ]; then
            echo ""
        fi
    done
fi
tp_in='-t ptr'

if [ ${#list_addresses[@]} -gt 0 ];then
    trap "exit" INT
    for address in ${list_addresses[@]}
    do
        rev_addrs=$(echo ${address} | awk -F"." '{print$4"."$3"."$2"."$1".in-addr.arpa"}')
        eval ${cmd} ${rev_addrs} ${tp_in} ${nsrv} ${condition}
        if [ "${blk_ln}" == 1 ]; then
            echo ""
        fi
    done
fi
if [ "${clasfy}" != 1 ]; then
    echo "${nsrv_and_time}"
fi
