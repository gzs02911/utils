#!/bin/bash 

if [ "$#" -lt "4" ]; then 
	echo "Us: $0 SERVER PORT USER PASSWD"
	echo "Opcionalment es pot afegir la versió final desitjada" 
	echo "Us: $0 SERVER PORT USER PASSWD VERSIO"
	exit 1
fi

UC_URL="https://updates.jenkins.io"
DDIR=../plugin-downdoads/

get_lts_version(){
	local version
	version=$(curl -sSL https://updates.jenkins.io/stable/latestCore.txt)
#	if [ $? -ne "0" ]; then 
#		echo "No s'ha definit versió base del Jenkins ni s'ha pogut detectar a l'Update Center en linea." 
#		echo "Es cancel·la el procés"
#		exit 1
#	fi
	major=$(echo $version | cut -d '.' -f 1)
	minor=$(echo $version | cut -d '.' -f 2)
	echo "${major}.${minor}"
}

get_jenkins_version(){
	local JENKINS_HOST=$1
	SERVERPORT=$(echo $JENKINS_HOST | cut -d '@' -f 2)
	wgetErrorLog=$(mktemp)

	if ! [ -f "jenkins-cli.jar" ]; then
		#echo "No s'ha trobat el binari de jenkins-cli.jar. Descarregant..." 
		#wget http://jenkins.agbar.net/jnlpJars/jenkins-cli.jar -O jenkins-cli.jar > /dev/null 2>${wgetErrorLog}
		wget http://${SERVERPORT}/jnlpJars/jenkins-cli.jar -O jenkins-cli.jar > /dev/null 2>${wgetErrorLog}
		if [ $? -ne "0" ]; then 
			echo "No podem recuperar el client de jenkins per consultar la versió actual. Log:"
			echo "+++++++++++++++++"
			cat ${wgetErrorLog}
			echo "-----------------"
		        echo "Es cancel·la el procés" 
			rm -rf ${wgetErrorLog}
			exit 1
		#else 
		#	echo "Descarregat"
		fi
	fi
	version=$(java -jar jenkins-cli.jar -s http://$JENKINS_HOST version)
	estat=$?
	echo $version
	return $estat
}

proces_info(){
	local jenkinsVersion=$1
	local ltsVersion=$2
	local plugins=$3

	echo "Iniciant el procés des descarrega de plugins del jenkins."
	echo "========================================================="
	echo ""
	echo " Actual Jenkins Version: $jenkinsVersion"
	echo " Plugins trobats: $(echo $plugins| wc -w)"
	echo " Jenkins LTS Version: $ltsVersion"
	echo ""
	echo "========================================================="
}

main() {
	SERVER=$1
	PORT=$2
	USER=$3
	PASSWD=$4
	VERSION=$5
	JENKINS_HOST="${USER}:${PASSWD}@${SERVER}:${PORT}"
	JENKINS_VERSION="$(get_jenkins_version $JENKINS_HOST)"

	if [ -z "$VERSION" ]; then 
		# Agafem la última LTS del repositori
		VERSION=$(get_lts_version)
	fi

	#Llistat de plugins actual
	PLUGINS=$(curl -sSL "http://$JENKINS_HOST/pluginManager/api/xml?depth=1&xpath=/*/*/shortName|/*/*/version&wrapper=plugins" | perl -pe 's/.*?<shortName>([\w-]+).*?<version>([^<]+)()(<\/\w+>)+/\1\n/g')
	if [ $? -ne "0" ];then 
		echo "No s'ha pogut recollir la llista de plugins actualment instal·lats a ${SERVER}"
		echo "Es cancel·la el procés" 
		exit 1
	fi

	proces_info $JENKINS_VERSION $VERSION "$PLUGINS"

	#Creem la URL de descarrega en base a la últma LTS
	URL="${UC_URL}/${VERSION}/latest"
	echo " URL de descàrrega: ${URL}"

	FINALDDIR="${DDIR}/${VERSION}"

	if [ -d "${FINALDDIR}" ]; then 
		echo " Reutilitzant Directori de descàrrega: ${FINALDDIR}"
	else
		mkdir -p ${FINALDDIR}
		echo " Creat directori de descàrrega: ${FINALDDIR}"
	fi
	
	DOWNLOADED=0
	FAILED=0
	wgetErrorLog=$(mktemp)

	echo " Iniciant descàrrega de plugins..."
	for plugin in $PLUGINS; do 
		tempWgetErrorLog=$(mktemp)
		echo -n " + Descarregant plugin - ${plugin} - $URL/${plugin}.hpi ..."
		wget -q $URL/${plugin}.hpi -O $FINALDDIR/${plugin}.hpi > /dev/null 2>${tempWgetErrorLog}
		if [ $? -eq "0" ];then 
			echo "OK!"
			((DOWNLOADED++))
		else
			echo "ERROR!"
			echo -e "${plugin} - $URL/${plugin}.hpi\n=========================================================\n${tempWgetErrorLog} " >> ${wgetErrorLog}
			((FAILED++))
			rm -rf ${tempWgetErrorLog}
		fi
	done

	echo ""
	echo "========================================================="
	echo ""
	echo " Finalitzat el procés de descàrrega." 
	echo " S'han descarregat ${DOWNLOADED} plugins correctament. Han fallat ${FAILED}."
	if [ -f "${wgetErrorLog}" ]; then 
		echo "Registre de errors de descàrrega:"
		cat ${wgetErrorLog}
	fi
	echo ""
	echo "========================================================="
	echo " Finalitzat el procés" 
	echo "========================================================="

}

main "$@"

