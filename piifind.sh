#!/usr/bin/env bash

default_pii_patterns="name|email|address|zip-code"
print_fns="log|info|warn|error|debug"
pii_patterns=$default_pii_patterns

function usage_exit {
    cat <<EOF
Usage: piifind [-a "foo|bar|hoge"] [FILE]

e.g. Basic usage
piifind src/

e.g. With additional PII patterns to look for
piifind -a billing|phone src/

e.g. Reading from STDIN
piifind <<EOD
(log "print address %s" address)
EOD

EOF
    exit 0
}

while getopts p:h OPT
do
    case $OPT in
        p)  extra_patterns=$OPTARG
            ;;
        h)  usage_exit
            ;;
        \?) usage_exit
            ;;
    esac
done
shift $(($OPTIND - 1))

if [ ! -z "$extra_patterns" ]; then
    pii_patterns="${pii_patterns}|$extra_patterns"
fi

# Good enough regex that looks for a Clojure form that starts with one of $print_fns
# followed by one of $pii_patterns.
# Examples that match
# (infof "debug: %s"
#        address)
# https://regex101.com/r/lF0fI1/238
regex="\((${print_fns})[^)]*(${pii_patterns})[^)]*\)"

if [ ! -z "$1" ]; then
    echo "Reading from file: $1"
    if [ ! -e $1 ]; then
        echo "File not found: $1"
        exit 1
    fi

    grep -r -i --include='*.clj' --include='*.cljs' -PHz --color=auto $regex $1
else
    echo "Reading from stdin"
    cat - | grep -i -PHz --color=auto $regex
fi

# Grep returns 0 if matchs
if [ $? -eq 0 ]; then
    cat <<EOF


*************************************************************
Possibly logging PII in your code!! Check the output above
and make sure code doesn't accidentally logs PII.
*************************************************************
EOF
    exit 1
else
    echo "No PII :)"
    exit 0
fi
