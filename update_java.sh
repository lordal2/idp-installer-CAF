#!/bin/bash
Spath="$(cd "$(dirname "$0")" && pwd)"
if [ ! -z "`echo ${Spath} | grep \"/bin$\"`" ]; then
	Spath=`dirname ${Spath}`
fi

. ${Spath}/files/script.messages.sh
. ${Spath}/files/script.bootstrap.functions.sh
setEcho
. ${Spath}/files/script.functions.sh

cd ${Spath}

git pull

installOracleJava
