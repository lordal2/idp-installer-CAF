#!/bin/sh
# UTF-8



setBackTitle ()
{
	#	echo "in setBackTitle"
		btVar="BackTitle${my_ctl_federation}"
	#echo "in setBackTitle btVar=${btVar}, ${!btVar}"

	BackTitle="${!btVar} ${BackTitle}"
	
	# used in script.eduroam.functions.sh
	GUIbacktitle="${BackTitle}"

}

installDependanciesForInstallation ()
{
	${Echo} "Updating repositories and installing generic dependencies"
	#${Echo} "Live logging can be seen by this command in another window: tail -f ${statusFile}"
	eval ${distCmdU} &> >(tee -a ${statusFile}) 
	eval ${distCmd1} &> >(tee -a ${statusFile})
	${Echo} "Done."
}

patchFirewall()
{
        #Replace firewalld with iptables (Centos7)
        ${Echo} "Updating firewall settings - changing from firewalld to iptables "
		${Echo} "Working with Distro:${dist} with version: ${redhatDist}"
        
        if [ "${dist}" == "centos" -a "${redhatDist}" == "7" ]; then
        ${Echo} "Detected ${dist} ${redhatDist}"
                systemctl stop firewalld
                systemctl mask firewalld
                eval "yum -y install iptables-services" >> ${statusFile} 2>&1
                systemctl enable iptables
                systemctl start iptables

        elif [ "${dist}" == "redhat" -a "${redhatDist}" == "7" ]; then
        ${Echo} "Detected ${dist} ${redhatDist}"
                systemctl stop firewalld
                systemctl mask firewalld
                eval "yum -y install iptables-services" >> ${statusFile} 2>&1
                systemctl enable iptables
                systemctl start iptables

	elif [ "${dist}" == "ubuntu" ]; then
        ${Echo} "Detected ${dist} ${redhatDist}"

		DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent	
        fi

}

fetchJavaIfNeeded ()

{
	${Echo} "setJavaHome deprecates fetchJavaIfNeeded and ensures latest java is used"
	# install java if needed
	#javaBin=`which java 2>/dev/null`
	#if [ ! -s "${javaBin}" ]; then
	#	eval ${distCmd2}
	#	eval ${distCmd3}
		
	#	javaBin=`which java 2>/dev/null`
	#fi
	#if [ ! -s "${javaBin}" ]; then
	#	${Echo} "No java could be found! Install a working JRE and re-run this script."
	#	${Echo} "Try: ${distCmd2} and ${distCmd3}"
	#	cleanBadInstall
	#fi

}

notifyMessageDeployBeginning ()
{
	${Echo} "Starting deployment!"
}


setVarUpgradeType ()

{

	if [ -d "/opt/shibboleth-idp" ]; then
		upgrade=1
	fi
}

setVarPrepType ()

{
prep="prep/${type}"

}

setVarCertCN ()

{
certCN=`${Echo} ${idpurl} | cut -d/ -f3`

}
setVarIdPScope ()
{

	idpScope="${freeRADIUS_realm}"
}

setJavaHome () {

        # force the latest java onto the system to ensure latest is available for all operations.
        # including the calculation of JAVA_HOME to be what this script sees on the system, not what a stale environment may have

        # June 23, 2015, altering java detection behaviour to be more platform agnostic

	if [ -L "/usr/java/default" -a -d "/usr/java/jre${javaVer}" ]; then
		
                export JAVA_HOME=/usr/java/default
                ${Echo} "Detected Java allready installed in ${JAVA_HOME}."

				# return 0  This is not accurate, we need to prepare the host for java settings regardless.
	else

		${Echo} "Java not detected, downloading and installing.."

        unset JAVA_HOME

        #Install from src
        javaSrc="jre-8u25-linux-x64.tar.gz"
        if [ ! -s "${downloadPath}/${javaSrc}" ]; then
                ${fetchCmd} ${downloadPath}/${javaSrc} -j -L -H "Cookie: oraclelicense=accept-securebackup-cookie"  https://download.oracle.com/otn-pub/java/jdk/8u25-b17/${javaSrc} >> ${statusFile} 2>&1
        fi
        if [ ! -d "/usr/java" ]; then
		mkdir /usr/java
	fi
        tar xzf ${downloadPath}/${javaSrc} -C /usr/java/
        ln -s /usr/java/jre${javaVer}/ /usr/java/latest
        ln -s /usr/java/latest /usr/java/default
        export JAVA_HOME="/usr/java/default"
		export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        #Set the alternatives
        for i in `ls $JAVA_HOME/bin/`; do rm -f /var/lib/alternatives/$i;update-alternatives --install /usr/bin/$i $i $JAVA_HOME/bin/$i 100; done
        for i in `ls $JAVA_HOME/bin/`;do update-alternatives --set $i $JAVA_HOME/bin/$i; done

        echo "***javahome is: ${JAVA_HOME}"
        # validate java_home and ensure it runs as expected before going any further
        
    fi

    	# Regardless of origin, let's validate it's existence then ensure it's in our .bashrc and our path


        ${JAVA_HOME}/bin/java -version >> ${statusFile} 2>&1
		retval=$?

        if [ "${retval}" -ne 0 ]; then
                ${Echo} "\n\n\nAn error has occurred in the configuration of the JAVA_HOME variable."
                ${Echo} "Please review the java installation and status.log to see what went wrong."
                ${Echo} "Install is aborted until this is resolved."
                cleanBadInstall
                exit
        else

                ${Echo} "\n\n\n JAVA_HOME version verified as good."
                jEnvString="export JAVA_HOME=${JAVA_HOME}"

                 if [ -z "`grep 'JAVA_HOME' /root/.bashrc`" ]; then

                         ${Echo} "${jEnvString}" >> /root/.bashrc
                         ${Echo} "\n\n\n JAVA_HOME added to end of /root/.bashrc"

                 else

                         ${Echo} "${jEnvString}" >> /root/.bashrc
                         ${Echo} "\n\n\n ***EXISTING JAVA_HOME DETECTED AND OVERRIDDEN!***"
                         ${Echo} "\n A new JAVA_HOME has been appended to end of /root/.bashrc to ensure the latest javahome is used. Hand edit as needed\n\n"

                 fi

                 # Ensure the java is in our execution path both in execution AND in the .bashrc
                 
                 jEnvPathString="export PATH=${PATH}:${JAVA_HOME}/bin"
                 ${Echo} "${jEnvPathString}" >> /root/.bashrc
                 ${Echo} "\n\n\n Updated PATH to add java bin dir at end of /root/.bashrc"

                 export PATH=${PATH}:${JAVA_HOME}/bin

        fi

}

setJavaCACerts ()

{
        javaCAcerts="${JAVA_HOME}/lib/security/cacerts"
        keytool="${JAVA_HOME}/bin/keytool"
	
}


setJavaCryptographyExtensions ()
{
# requires that Oracle's java is already installed in the system and will auto-accept the license.
# download instructions are found here: http://www.oracle.com/technetwork/java/javase/downloads/jce8-download-2133166.html
#
# because they are crypto settings, this function is abstracted out

	${Echo} "Setting Java Cryptography Extensions to unlimited strength" | tee -a ${statusFile}

# Backup originals
	JCEBkp1="local_policy.jar"
	JCEBkp2="US_export_policy.jar"
	JCEBkpPostfix=`date +%F-%s`
	${Echo} "Backing up ${JCEBkp1} and ${JCEBkp1} from ${JAVA_HOME} to ${Spath}/backups" | tee -a ${statusFile}
	eval "cp ${JAVA_HOME}/lib/security/${JCEBkp1} ${Spath}/backups/${JCEBkp1}-${JCEBkpPostfix}" &> >(tee -a ${statusFile})
	eval "cp ${JAVA_HOME}/lib/security/${JCEBkp2} ${Spath}/backups/${JCEBkp2}-${JCEBkpPostfix}" &> >(tee -a ${statusFile})

# Fetch new policy file
	${Echo} "Fetching Java Cryptography Extensions from Oracle" | tee -a ${statusFile}

        jcePolicySrc="jce_policy-8.zip"

        if [ ! -s "${downloadPath}/${jcePolicySrc}" ]; then
                ${fetchCmd} ${downloadPath}/${jcePolicySrc} -j -L -H "Cookie: oraclelicense=accept-securebackup-cookie"  http://download.oracle.com/otn-pub/java/jce/8/${jcePolicySrc} >> ${statusFile} 2>&1
        fi
       
# Extract locally into downloads directory

       eval "(pushd ${downloadPath}; unzip -o ${downloadPath}/${jcePolicySrc}; popd)" &> >(tee -a ${statusFile})

# copy into place
	${Echo} "Putting Java Cryptography Extensions from Oracle into ${JAVA_HOME}/lib/security/" | tee -a ${statusFile}

	JCEWorkingDir="${downloadPath}/UnlimitedJCEPolicyJDK8"
	eval "cp ${JCEWorkingDir}/${JCEBkp1} ${JAVA_HOME}/lib/security/${JCEBkp1}" &> >(tee -a ${statusFile})
	eval "cp ${JCEWorkingDir}/${JCEBkp2} ${JAVA_HOME}/lib/security/${JCEBkp2}" &> >(tee -a ${statusFile})

	${Echo} "Testing Java Cryptography Extensions" | tee -a ${statusFile}
	JCEUnlimitedResponse="2147483647"
	JCETestCmd="java -classpath ${downloadPath} checkJCEStrength"
	JCETestResults=$(eval ${JCETestCmd}) 

	if [ "${JCETestResults}" ==  "${JCEUnlimitedResponse}" ]
	     then
            ${Echo} "Java Cryptography Extensions update succeeded" | tee -a ${statusFile}
	else
			${Echo} "**Java Cryptography Extensions update failed! rolling back using backups**" | tee -a ${statusFile}
			${Echo} "**Install will succeed but you will not operate at full crypto strength **" | tee -a ${statusFile}
			${Echo} "**Some Service Providers will fail to negotiate. See https://github.com/canariecaf/idp-installer-CAF/issues/71 **" | tee -a ${statusFile}

	eval "cp  ${Spath}/backups/${JCEBkp1}-${JCEBkpPostfix} ${JAVA_HOME}/lib/security/${JCEBkp1}" &> >(tee -a ${statusFile})
	eval "cp ${Spath}/backups/${JCEBkp2}-${JCEBkpPostfix} ${JAVA_HOME}/lib/security/${JCEBkp2}" &> >(tee -a ${statusFile})


	fi



}




generatePasswordsForSubsystems ()

{
	# generate keystore pass
	if [ -z "${pass}" ]; then
		pass=`${passGenCmd}`

		if [ "${installer_interactive}" = "n" ]; then
			${Echo} "Shibboleth keystore password is '${pass}'" >> ${statusFile}
		fi
	fi
	if [ -z "${httpspass}" ]; then
		httpspass=`${passGenCmd}`

		if [ "${installer_interactive}" = "n" ]; then
			${Echo} "HTTPS JKS keystore password is '${httpspass}'" >> ${statusFile}
		fi
	fi
	if [ -z "${mysqlPass}" -a "${eptid}" != "n" ]; then
		mysqlPass=`${passGenCmd}`
		${Echo} "Mysql root password generated\nPassword is '${mysqlPass}'" >> ${messages}

		if [ "${installer_interactive}" = "n" ]; then
			${Echo} "MySQL password is '${mysqlPass}'" >> ${statusFile}
		fi
	fi

}

installEPEL() {
	
	if [ ! -z "`rpm -q epel-release | grep ' is not installed'`" ]; then
			
		${Echo} "Detected no EPEL and Jpackage, adding repos into /etc/yum.repos.d/ and updating them"	


	cat > /etc/yum.repos.d/jpackage-generic-free.repo << EOF
[jpackage-generic-free]
name=JPackage generic free
baseurl=http://ftp.heanet.ie/pub/jpackage/6.0/generic/free
mirrorlist=http://www.jpackage.org/mirrorlist.php?dist=generic&type=free&release=6.0
enabled=1
gpgcheck=1
gpgkey=http://www.jpackage.org/jpackage.asc
EOF

	cat > /etc/yum.repos.d/jpackage-generic-devel.repo << EOF
[jpackage-generic-devel]
name=JPackage Generic Developer
baseurl=http://ftp.heanet.ie/pub/jpackage/6.0/generic/free
mirrorlist=http://www.jpackage.org/mirrorlist.php?dist=generic&type=free&release=6.0
enabled=1
gpgcheck=1
gpgkey=http://www.jpackage.org/jpackage.asc
EOF

	eval $redhatEpel >> ${statusFile} 2>&1

else

	${Echo} "Dected EPEL and JPackage EXIST on this system. Skipping this step as system already updated"
fi


}

setHostnames() {
	FQDN=`hostname`
	FQDN=`host -t A ${FQDN} | awk '{print $1}' | sed -re 's/\s+//g'`
	Dname=`${Echo} ${FQDN} | cut -d\. -f2-`
	if [ "${FQDN}" = "Host" ]
	then
		eval ${dist_install_netstat} >> ${statusFile} 2>&1

		myInterface=`netstat -nr | grep "^0.0.0.0" | awk '{print $NF}'`
		myIP=`ip addr list ${myInterface} | grep "inet " | cut -d' ' -f6 | cut -d/ -f1`
		Dname=`host -t A ${myIP} | head -1 | awk '{print $NF}' | cut -d\. -f2- | sed 's/\.$//'`
		FQDN=`host -t A ${myIP} | head -1 | awk '{print $NF}' | sed 's/\.$//'`
	fi
}



fetchCas() {
	${Echo} "Cas-client not found, fetching from web"
	${fetchCmd} ${downloadPath}/cas-client-${casVer}-release.zip ${casClientURL}

	if [ ! -s ${downloadPath}/cas-client-${casVer}-release.zip ]; then
		${Echo} "Error while downloading CAS client, aborting."
		cleanBadInstall
	fi
}

fetchMysqlCon() {

	echo "Mysql Connector now in the download folder"
	#  Deprecated fetching to presence in downloadPath

	#	if [ ! -s "${downloadPath}/mysql-connector-java-${mysqlConVer}.tar.gz" ]; then
	#		${Echo} "Error while downloading mysql-connector, aborting."
	#		cleanBadInstall
	#	fi
}


installEPTIDSupport ()
        {
        if [ "${eptid}" != "n" ]; then
                ${Echo} "Installing EPTID support"

		if [ "${dist}" == "ubuntu" ]; then
			test=`dpkg -s mysql-server > /dev/null 2>&1`
			isInstalled=$?

		elif [ "${dist}" == "centos" -o "${dist}" == "redhat" ]; then
			if [ "${redhatDist}" == "6" ]; then
				[ -f /etc/init.d/mysqld ]
				isInstalled=$?

			elif [ "${redhatDist}" == "7" ]; then
				#Add Oracle repos
				if [ ! -z "`rpm -q mysql-community-release | grep ' is not installed'`" ]; then
					${Echo} "Detected no MySQL, adding repos into /etc/yum.repos.d/ and updating them"
					mysqlOracleRepo="rpm -Uvh http://repo.mysql.com/mysql-community-release-el7.rpm"
					eval $mysqlOracleRepo >> ${statusFile} 2>&1
				else
					${Echo} "Dected MySQL Repo EXIST on this system."

				fi
				test=`rpm -q mysql-community-server > /dev/null 2>&1`
				isInstalled=$?

			fi
		fi

                if [ "${isInstalled}" -ne 0 ]; then
                        export DEBIAN_FRONTEND=noninteractive
                        eval ${distCmd5} >> ${statusFile} 2>&1

                        mysqldTest=`pgrep mysqld`
                        if [ -z "${mysqldTest}" ]; then
                                if [ ${dist} == "ubuntu" ]; then
                                        service mysql restart >> ${statusFile} 2>&1
                                else
                                        service mysqld restart >> ${statusFile} 2>&1
                                fi
                        fi
                        # set mysql root password
                        tfile=`mktemp`
                        if [ ! -f "$tfile" ]; then
                                return 1
                        fi
                        cat << EOM > $tfile
USE mysql;
UPDATE user SET password=PASSWORD("${mysqlPass}") WHERE user='root';
FLUSH PRIVILEGES;
EOM

                        mysql --no-defaults -u root -h localhost <$tfile
                        retval=$?
                        # moved removal of MySQL command file to be in the if-then-else statement set below

                        if [ "${retval}" -ne 0 ]; then
                                ${Echo} "\n\n\nAn error has occurred in the configuration of the MySQL installation."
                                ${Echo} "Please correct the MySQL installation and make sure a root password is set and it is possible to log in using the 'mysql' command."
                                ${Echo} "When MySQL is working, re-run this script."
                                ${Echo} "The file being run in MySQL is ${tfile} and has not been deleted, please review and delete as necessary."
                                cleanBadInstall
                        else
                                rm -f $tfile
                        fi


                        if [ "${dist}" != "ubuntu" ]; then
                                /sbin/chkconfig mysqld on
                        fi
                fi

                fetchMysqlCon
                cd /opt
                tar zxf ${downloadPath}/mysql-connector-java-${mysqlConVer}.tar.gz -C /opt >> ${statusFile} 2>&1
                cp /opt/mysql-connector-java-${mysqlConVer}/mysql-connector-java-${mysqlConVer}-bin.jar /opt/shibboleth-idp/edit-webapp/WEB-INF/lib/
		/opt/shibboleth-idp/bin/build.sh -Didp.target.dir=/opt/shibboleth-idp

        fi



        }

installCasClientIfEnabled() {

if [ "${type}" = "cas" ]; then

	if [ ! -f "${downloadPath}/cas-client-${casVer}-release.zip" ]; then
		fetchCas
	fi
	unzip -qo ${downloadPath}/cas-client-${casVer}-release.zip -d /opt
	if [ ! -s "/opt/cas-client-${casVer}/modules/cas-client-core-${casVer}.jar" ]; then
		${Echo} "Unzip of cas-client failed, check zip file: ${downloadPath}/cas-client-${casVer}-release.zip"
		cleanBadInstall
	fi

	if [ -z "${idpurl}" ]; then
		idpurl=$(askString "IDP URL" "Please input the URL to this IDP (https://idp.xxx.yy)" "https://${FQDN}")
	fi

	if [ -z "${casurl}" ]; then
		casurl=$(askString "CAS URL" "Please input the URL to yourCAS server (https://cas.xxx.yy/cas)" "https://cas.${Dname}/cas")
	fi

	if [ -z "${caslogurl}" ]; then
		caslogurl=$(askString "CAS login URL" "Please input the Login URL to your CAS server (https://cas.xxx.yy/cas/login)" "${casurl}/login")
	fi

	cp /opt/cas-client-${casVer}/modules/cas-client-core-${casVer}.jar /opt/shibboleth-idp/edit-webapp/WEB-INF/lib/
	cp ${Spath}/downloads/shib-cas-authenticator-3.0.0.jar /opt/shibboleth-idp/edit-webapp/WEB-INF/lib/
	cp /opt/shibboleth-idp/webapp/WEB-INF/web.xml /opt/shibboleth-idp/edit-webapp/WEB-INF/
	mkdir -p /opt/shibboleth-idp/flows/authn/Shibcas
	cp ${Spath}/${prep}/shibcas-authn-beans.xml ${Spath}/${prep}/shibcas-authn-flow.xml /opt/shibboleth-idp/flows/authn/Shibcas

	patch /opt/shibboleth-idp/edit-webapp/WEB-INF/web.xml -i ${Spath}/${prep}/${shibDir}-web.xml.diff >> ${statusFile} 2>&1
	patch /opt/shibboleth-idp/conf/authn/general-authn.xml -i ${Spath}/${prep}/${shibDir}-general-authn.xml.diff >> ${statusFile} 2>&1

	/opt/shibboleth-idp/bin/build.sh -Didp.target.dir=/opt/shibboleth-idp

else
	${Echo} "Authentication type: ${type}, CAS Client Not Requested"


fi



}

fetchAndUnzipShibbolethIdP ()

{
	cd /opt

	if [ ! -f "${downloadPath}/${shibDir}-${shibVer}.tar.gz" ]; then
		${Echo} "Shibboleth not found, fetching from web"
		${fetchCmd} ${downloadPath}/${shibDir}-${shibVer}.tar.gz ${shibbURL}

		if [ ! -s ${downloadPath}/${shibDir}-${shibVer}.tar.gz ]; then
		${Echo} "Error while downloading Shibboleth, aborting."
		cleanBadInstall
		fi
	fi

# 	unzip all files
	${Echo} "Unzipping dependancies"

	tar xzf ${downloadPath}/${shibDir}-${shibVer}.tar.gz -C /opt
	chmod -R 755 /opt/${shibDir}-${shibVer}
	ln -s ${shibDir}-${shibVer} ${shibDir}
}



createCertificatePathAndHome ()

{

mkdir -p ${certpath}
	

}

fetchLDAPCertificates ()
{
	# Fetch ldap cert
	${Echo} "Fetching LDAP Certificates for ldap-server.crt used in idp.properties"
	for loopServer in ${ldapserver}; do
		${Echo} "QUIT" | openssl s_client -connect ${loopServer}:636 2>/dev/null | sed -ne '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' >> ${certpath}/ldap-server.crt
	done

}

installCertificates()

{

# change to certificate path whilst doing this part
cd ${certpath}
${Echo} "Fetching TCS CA chain from web"
        ${fetchCmd} ${certpath}/server.chain ${certificateChain}
        if [ ! -s "${certpath}/server.chain" ]; then
                ${Echo} "Can not get the certificate chain, aborting install."
                cleanBadInstall
        fi

        ${Echo} "Installing TCS CA chain in java cacert keystore"
        cnt=1
        for i in `cat ${certpath}server.chain | sed -re 's/\ /\*\*\*/g'`; do
                n=`${Echo} ${i} | sed -re 's/\*\*\*/\ /g'`
                ${Echo} ${n} >> ${certpath}${cnt}.root
                ltest=`${Echo} ${n} | grep "END CERTIFICATE"`
                if [ ! -z "${ltest}" ]; then
                        cnt=`expr ${cnt} + 1`
                fi
        done
        ccnt=1
        while [ ${ccnt} -lt ${cnt} ]; do
                md5finger=`${keytool} -printcert -file ${certpath}${ccnt}.root | grep MD5 | cut -d: -f2- | sed -re 's/\s+//g'`
                test=`${keytool} -list -keystore ${javaCAcerts} -storepass changeit | grep ${md5finger}`
                subject=`openssl x509 -subject -noout -in ${certpath}${ccnt}.root | awk -F= '{print $NF}'`
                if [ -z "${test}" ]; then
                        ${keytool} -import -noprompt -trustcacerts -alias "${subject}" -file ${certpath}${ccnt}.root -keystore ${javaCAcerts} -storepass changeit >> ${statusFile} 2>&1
                fi
                files="`${Echo} ${files}` ${certpath}${ccnt}.root"
                ccnt=`expr ${ccnt} + 1`
        done

}



askForConfigurationData() {
	if [ -z "${type}" ]; then
		tList=""
		tAccept=""
		tGo=0
		for i in `ls ${Spath}/prep | sed -re 's/\n/\ /g'`; do
			tDesc=`cat ${Spath}/prep/${i}/.desc`
			tList="`${Echo} ${tList}` \"${i}\" \"${tDesc}\""
			tAccept=`${Echo} ${tAccept} ${i}`
		done

		while [ ${tGo} -eq 0 ]; do
			type=$(askList "Authentication type" "Which authentication type do you want to use?" "${tList}")
			for i in ${tAccept}; do
				if [ "${i}" = "${type}" ]; then
					tGo=1
					break
				fi
			done
		done
	fi
	prep="prep/${type}"

	if [ -z "${google}" ]; then
		google=$(askYesNo "Attributes to Google" "Do you want to release attributes to google?\nSwamid, Swamid-test and testshib.org installed as standard" "no")
	fi

	if [ "${google}" != "n" -a -z "${googleDom}" ]; then
		googleDom=$(askString "Your Google domain name" "Please input your Google domain name (student.xxx.yy)." "student.${Dname}")
	fi

	if [ -z "${ntpserver}" ]; then
		ntpserver=$(askString "NTP server" "Please input your NTP server address." "ntp.${Dname}")
	fi

	if [ -z "${ldapserver}" ]; then
		ldapserver=$(askString "LDAP server" "Please input yout LDAP server(s) (ldap.xxx.yy).\n\nSeparate multiple servers with spaces.\nLDAPS is used by default." "ldap.${Dname}")
	fi

	if [ -z "${ldapbasedn}" ]; then
		ldapbasedn=$(askString "LDAP Base DN" "Please input your LDAP Base DN")
	fi

	if [ -z "${ldapbinddn}" ]; then
		ldapbinddn=$(askString "LDAP Bind DN" "Please input your LDAP Bind DN")
	fi

	if [ -z "${ldappass}" ]; then
		ldappass=$(askString "LDAP Password" "Please input your LDAP Password")
	fi

	if [ "${type}" = "ldap" -a -z "${subsearch}" ]; then
		subsearch=$(askYesNo "LDAP Subsearch" "Do you want to enable LDAP subtree search?")
		subsearch="false"
		if [ "${subsearchNum}" = "y" ]; then
			subsearch="true"
		fi
	fi

	if [ -z "${ninc}" ]; then
		ninc=$(askString "norEduPersonNIN" "Please specify LDAP attribute for norEduPersonNIN (YYYYMMDDnnnn)" "norEduPersonNIN")
	fi

	if [ -z "${idpurl}" ]; then
		idpurl=$(askString "IDP URL" "Please input the URL to this IDP (https://idp.xxx.yy)" "https://${FQDN}")
	fi

	if [ "${type}" = "cas" ]; then
		if [ -z "${casurl}" ]; then
			casurl=$(askString "CAS URL" "Please input the URL to yourCAS server (https://cas.xxx.yy/cas)" "https://cas.${Dname}/cas")
		fi

		if [ -z "${caslogurl}" ]; then
			caslogurl=$(askString "CAS login URL" "Please input the Login URL to your CAS server (https://cas.xxx.yy/cas/login)" "${casurl}/login")
		fi
	fi

	if [ -z "${certOrg}" ]; then
		certOrg=$(askString "Certificate organisation" "Please input organisation name string for certificate request")
	fi

	if [ -z "${certC}" ]; then
		certC=$(askString "Certificate country" "Please input country string for certificate request" "SE")
	fi

	if [ -z "${certAcro}" ]; then
		acro=""
		for i in ${certOrg}; do
			t=`${Echo} ${i} | cut -c1`
			acro="${acro}${t}"
		done

		certAcro=$(askString "Organisation acronym" "Please input organisation Acronym (eg. 'HiG')" "${acro}")
	fi

	if [ -z "${certLongC}" ]; then
		certLongC=$(askString "Country descriptor" "Please input country descriptor (eg. 'Sweden')" "Sweden")
	fi

	if [ -z "${fticks}" ]; then
		fticks=$(askYesNo "Send anonymous data" "Do you want to send anonymous usage data to ${my_ctl_federation}?\nThis is recommended")
	fi

	if [ -z "${eptid}" ]; then
		eptid=$(askYesNo "eduPersonTargetedID" "Do you want to install support for eduPersonTargetedID?\nThis is recommended")
	fi

	if [ "${eptid}" != "n" -a "${passw_input}" = "y" ]; then
		mysqlPass=$(askString "MySQL password" "MySQL is used for supporting the eduPersonTargetedId attribute.\n\n Please set the root password for MySQL.\nAn empty string generates a randomized new password" "" 1)
	fi

	if [ -z "${selfsigned}" ]; then
		selfsigned=$(askYesNo "Self signed certificate" "Create a self signed certificate for HTTPS?\n\nThis is NOT recommended for production systems! Only for testing purposes" "y")
	fi

	if [ "${passw_input}" = "y" ]; then
		pass=$(askString "IDP keystore password" "The IDP keystore is for the Shibboleth software itself and not the webserver. Please set your IDP keystore password.\nAn empty string generates a randomized new password" "" 1)
		httpspass=$(askString "HTTPS Keystore password" "The webserver uses a separate keystore for itself. Please input your Keystore password for the end user facing HTTPS.\n\nAn empty string generates a randomized new password" "" 1)
	fi

	if [ -z "${consentEnabled}" ]; then
		subsearch=$(askYesNo "User consent" "Do you want to enable user consent?")
	fi

	if [ -z "${ECPEnabled}" ]; then
		subsearch=$(askYesNo "Enable ECP" "Do you want to enable SAML2 ECP?")
	fi


}


prepConfirmBox() {
	cat > ${downloadPath}/confirm.tx << EOM
Options passed to the installer:


Authentication type:       ${type}

Release to Google:         ${google}
Google domain name:        ${googleDom}

NTP server:                ${ntpserver}

LDAP server:               ${ldapserver}
LDAP Base DN:              ${ldapbasedn}
LDAP Bind DN:              ${ldapbinddn}
LDAP Subsearch:            ${subsearch}
norEduPersonNIN:           ${ninc}

IDP URL:                   ${idpurl}
CAS Login URL:             ${caslogurl}
CAS URL:                   ${casurl}

Cert org string:           ${certOrg}
Cert country string:       ${certC}
norEduOrgAcronym:          ${certAcro}
Country descriptor:        ${certLongC}

Usage data to ${my_ctl_federation}:      ${fticks}
EPTID support:             ${eptid}

Create self seigned cert:  ${selfsigned}
EOM
}

writeConfigFile() {
		cat > ${Spath}/config << EOM
type="${type}"
google="${google}"
googleDom="${googleDom}"
ntpserver="${ntpserver}"
ldapserver="${ldapserver}"
ldapbasedn="${ldapbasedn}"
ldapbinddn="${ldapbinddn}"
subsearch="${subsearch}"
idpurl="${idpurl}"
caslogurl="${caslogurl}"
casurl="${casurl}"
certOrg="${certOrg}"
certC="${certC}"
fticks="${fticks}"
eptid="${eptid}"
selfsigned="${selfsigned}"
ninc="${ninc}"
certAcro="${certAcro}"
certLongC="${certLongC}"
EOM
}

installMavenRC() {

maven2URL="http://mirror.its.dal.ca/apache/maven/maven-3/3.1.1/binaries/apache-maven-3.1.1-bin.tar.gz"
maven2File="${maven2URL##*/}"

maven2Path=`basename ${maven2File}  -bin.tar.gz`

	if [ -a "/opt/${maven2Path}/bin/mvn" ]
	then
		echo "Maven detected as installed"
	else
		echo "Fetching Maven from ${maven2URL}"

		${fetchCmd} ${downloadPath}/${maven2File} "{$maven2URL}"
		cd /opt
		tar zxf ${downloadPath}/${maven2File} >> ${statusFile} 2>&1

		
	fi
	export PATH=${PATH}:${maven2Path}/bin	


#	if [ ! -s "${downloadPath}/apache-maven-3.1.0-bin.tar.gz" ]; then
#		${fetchCmd} ${downloadPath}/apache-maven-3.1.0-bin.tar.gz http://mirrors.gigenet.com/apache/maven/maven-3/3.1.0/binaries/apache-maven-3.1.0-bin.tar.gz >> ${statusFile} 2>&1
#	fi

#	if [ ! -d "/opt/apache-maven-3.1.1/bin/" ]; then
#		tar -zxf ${downloadPath}/apache-maven-3.1.0-bin.tar.gz -C /opt
#	fi
	if [ ! -s "/etc/profile.d/maven-3.1.sh" ]; then
		cat > /etc/profile.d/maven-3.1.sh << EOM
export M2_HOME=/opt/apache-maven-3.1.1
export M2=\$M2_HOME/bin
PATH=\$M2:\$PATH
EOM
	fi
	if [ -z "${M2_HOME}" ]; then
		. /etc/profile.d/maven-3.1.sh
	fi
}

configShibbolethXMLAttributeResolverForLDAP ()
{
	# using ${my_ctl_federation} as the federation tag to pivot on regarding what to do.
	
	ldapServerStr=""
	for i in `${Echo} ${ldapserver}`; do
		ldapServerStr="`${Echo} ${ldapServerStr}` ldaps://${i}"
	done
	ldapServerStr=`${Echo} ${ldapServerStr} | sed -re 's/^\s+//'`
	orgTopDomain=`${Echo} ${certCN} | cut -d. -f2-`

	${Echo} "Processing Attribute-resolver.xml customizations"

	cat ${Spath}/xml/${my_ctl_federation}/attribute-resolver.xml.template \
		| sed -re "s/NiNcRePlAcE/${ninc}/;s/CeRtAcRoNyM/${certAcro}/;s/CeRtOrG/${certOrg}/;s/CeRtC/${certC}/;s/CeRtLoNgC/${certLongC}/" \
		| sed -re "s/SCHAC_HOME_ORG/${orgTopDomain}/;s/LdApUsErAtTr/${attr_filter}/g" \
		> ${Spath}/xml/${my_ctl_federation}/attribute-resolver.xml
	files="`${Echo} ${files}` ${Spath}/xml/${my_ctl_federation}/attribute-resolver.xml"

        cat ${Spath}/xml/${my_ctl_federation}/ldapconn.template \
                | sed -re "s/AtTrFiLtEr/${attr_filter}/" \
                > ${Spath}/xml/${my_ctl_federation}/ldapconn.txt
        files="`${Echo} ${files}` ${Spath}/xml/${my_ctl_federation}/ldapconn.txt"


}

runShibbolethInstaller ()

{
        #       run shibboleth installer
        cd /opt/${shibDir}
        ${Echo} "Running shiboleth installer"


	# Set some default values

        if [ -x ${ldap_type} ]; then
                ldap_type="ad"
        fi

	if [ -x ${ldapStartTLS} ]; then
		ldapStartTLS="true"
	fi

        if [ -x ${ldapSSL} ]; then
                ldapSSL="false"
	fi

        if [ -x ${user_field} ]; then
                user_field="samaccountname"
        fi

        if [ -x ${attr_filter} ]; then
                attr_filter="uid"
        fi

        if [ -x ${ldap_attr} ]; then
                ldap_attr=""
        fi

	# ActiveDirectory specific
	if [ "${ldap_type}" = "ad" ]; then

              #Set idp.authn.LDAP.authenticator
              ldapAuthenticator="adAuthenticator"
	      # Extract AD domain from baseDN
	      #ldapbasedn_tmp=$(echo ${ldapbasedn}  | tr '[:upper:]' '[:lower:]')
	      #ldapDomain=$(echo ${ldapbasedn_tmp#ou*dc=} | sed "s/,dc=/./g")
	      #ldapDnFormat="%s@${ldapDomain}"
	      ldapDnFormat="%s@${ldapdn}"	

	 # Other LDAP implementations
	 else
	       #Set idp.authn.LDAP.authenticator
               ldapAuthenticator="bindSearchAuthenticator"
	       ldapDnFormat="uid=%s,${ldapbasedn}"
	 fi

#  Establish which authentication flows we have to configure

idpAuthnFlowsDefault="Password"
idpAuthnFlows=""

if [ "${ECPEnabled}" = "y" -a "${type}" = "ldap" ]; then

	idpAuthnFlows="${idpAuthnFlows}|RemoteUserInternal"
	${Echo} "ECP Specific setting detected: idp.properties authn flows are now set to ldap and ECP: ${idpAuthnFlows}"

elif [ "${ECPEnabled}" = "y" -a "${type}" = "cas" ]; then

	idpAuthnFlows="Shibcas|RemoteUserInternal"
	${Echo} "ECP Specific setting detected: idp.properties authn flows are now set to CAS and ECP: ${idpAuthnFlows}"

else
	
	idpAuthnFlows="${idpAuthnFlowsDefault}"
	${Echo} "idp.properties authn flows are set to the default use of password : ${idpAuthnFlows}"

fi


#  Auth flows part 2: what do we need to set for the installation?

	if [ "${type}" = "ldap" ]; then

	       cat << EOM > idp.properties.tmp
idp.scope               =${idpScope}
idp.entityID            = https://${certCN}/idp/shibboleth
idp.sealer.storePassword= ${pass}
idp.sealer.keyPassword  = ${pass}
idp.authn.flows		= Password
EOM

	elif [ "${type}" = "cas" ]; then

                cat << EOM > idp.properties.tmp
idp.scope                  = ${idpScope}
idp.entityID               = https://${certCN}/idp/shibboleth
idp.sealer.storePassword   = ${pass}
idp.sealer.keyPassword     = ${pass}
idp.authn.flows            = Shibcas
shibcas.casServerUrlPrefix = ${casurl}
shibcas.casServerLoginUrl  = \${shibcas.casServerUrlPrefix}/login
shibcas.serverName         = https://${certCN}
EOM

	fi

	# Set LDAP configuration (needed for both cas and ldap)
        cat << EOM > ldap.properties.tmp
idp.authn.LDAP.authenticator                    = ${ldapAuthenticator}
idp.authn.LDAP.ldapURL                          = ${ldapurl}
idp.authn.LDAP.useStartTLS                      = ${ldapStartTLS}
idp.authn.LDAP.useSSL                           = ${ldapSSL}
idp.authn.LDAP.sslConfig                        = certificateTrust
idp.authn.LDAP.trustCertificates                = %{idp.home}/ssl/ldap-server.crt
idp.authn.LDAP.trustStore                       = %{idp.home}/credentials/ldap-server.truststore
idp.authn.LDAP.returnAttributes                 = ${ldap_attr}
idp.authn.LDAP.baseDN                           = ${ldapbasedn}
idp.authn.LDAP.subtreeSearch                    = true
idp.authn.LDAP.userFilter                       = (${attr_filter}={user})
idp.authn.LDAP.bindDN                           = ${ldapbinddn}
idp.authn.LDAP.bindDNCredential                 = ${ldappass}
idp.authn.LDAP.dnFormat                         = ${ldapDnFormat}
EOM

	# Run the installer
	JAVA_HOME=/usr/java/default sh bin/install.sh \
	-Didp.src.dir=./ \
	-Didp.target.dir=/opt/shibboleth-idp \
	-Didp.host.name="${certCN}" \
	-Didp.scope="${idpScope}" \
	-Didp.keystore.password="${pass}" \
	-Didp.sealer.password="${pass}" \
	-Dldap.merge.properties=./ldap.properties.tmp \
	-Didp.merge.properties=./idp.properties.tmp

}

enableECPUpdateIdPWebXML ()
{
		${Echo} "ECP Step: Update the web.xml of the idp and rebuild"
		${Echo} "ECP Step: make backup of web.xml"
		webXML="web.xml"
		webAppWEBINFOverride="/opt/shibboleth-idp/edit-webapp/WEB-INF"
		webAppWEBINF="/opt/shibboleth-idp/webapp/WEB-INF"
		# set to the overridden one provided it exists
		tgtFileToUpdate="${webAppWEBINFOverride}/${webXML}"
		tgtFileToUpdateBackup="${tgtFileToUpdate}.orig"

		# expected entry conditions of this if-then-else and subsequent logic block:
		# A. users and this code who touch web.xml will place file in Shibboleth edit-webapp location
		# B. syntactically the file will have the closing XML tag on the very last line (no extra spaces)
		# C. regardless of the use of CAS (which places the web.xml in the override location) we will pivot around overriding existing web.xml
		# D. the function enableECPUpdateIdPWebXML is executed after the detection and manipulation of the items for CAS
		# E.  the overriden web.xml is syntactically correct (we validate after processing but will not validate before)
		if [ -s "${tgtFileToUpdate}" ]; then
				${Echo} "ECP Step: CAS is your AuthN technique, web.xml being manipulated:${tgtFileToUpdate}"
		else				
				${Echo} "ECP Step: Regular Shibboleth AuthN detected, web.xml being cloned from webapp/WEB-INF into edit-webapp/WEB-INF"
				cp ${webAppWEBINF}/${webXML} ${webAppWEBINFOverride}
		fi

		# make the backup
		cp ${tgtFileToUpdate} ${tgtFileToUpdateBackup}


		${Echo} "ECP Step: modify web.xml to enable ECP features of jetty container"
			#  NOTE: The use of the greater than overwrites the file web.xml and we cat the fragment to complete it.
			#  this is intentional			
			head -n -1 ${tgtFileToUpdateBackup} > ${tgtFileToUpdate}
			cat ${Spath}/prep/jetty/web.xml.fragment.template >> ${tgtFileToUpdate}
		${Echo} "ECP Step: modify web.xml to enable ECP features of jetty container"
		
		mytest=`/usr/bin/xmllint ${tgtFileToUpdate} > /dev/null 2>&1`
		# $? is the most recent foreground pipeline exit status.  If it's ok, we did our job right.
		isWebXMLOK=$?

        if [ "${isWebXMLOK}" -ne 0 ]; then
			${Echo} "ECP Step: RUH-OH! web.xml failed to validate via xmllint. saving to web.xml.failed and reverting to original"
			cp ${tgtFileToUpdate} ${tgtFileToUpdate}.failed
			cp ${tgtFileToUpdateBackup} ${tgtFileToUpdate}
			${Echo} "ECP Step: RUH-OH! manual intervention required for ECP to work, but regular SSO operations should be ok."
				
        else
			${Echo} "ECP Step: web.xml validates via xmllint, good to proceed."
  
        fi
		${Echo} "ECP Step: Proceeding to rebuilding the war and deploying"
 		/opt/shibboleth-idp/bin/build.sh -Didp.target.dir=/opt/shibboleth-idp


}

enableECP ()

{

	# Based off of: https://wiki.shibboleth.net/confluence/display/IDP30/ECPConfiguration


	if [ "${ECPEnabled}" = "y" ]; then
	
		${Echo} "ECP Enabled is yes, processing ECP steps"


		${Echo} "ECP Step: Adding in JAAS connector in idp.home/conf/authn/jaas.config"
		jaasConfigFile="/opt/shibboleth-idp/conf/authn/jaas.config"
		ldapServerStr=""
		for i in `${Echo} ${ldapserver}`; do
			ldapServerStr="`${Echo} ${ldapServerStr}` ldap://${i}"
		done
		ldapServerStr="`${Echo} ${ldapServerStr} | sed -re 's/^\s+//'`"
		ldapUserFilter="${attr_filter}={user}"

		cat ${Spath}/${prep}/jaas.config.template \
			| sed -re "s#LdApUrI#${ldapServerStr}#;s/LdApBaSeDn/${ldapbasedn}/;s/SuBsEaRcH/${subsearch}/;s/LdApCrEdS/${ldapbinddn}/;s/LdApPaSsWoRd/${ldappass}/;s/LdApUsErFiLtEr/${ldapUserFilter}/;s/LdApSsL/${ldapSSL}/;s/LdApTlS/${ldapStartTLS}/" \
			> ${jaasConfigFile}

		${Echo} "ECP Step: ensure jetty:jetty owns idp.home/conf/authn/jaas.config"
		chown jetty:jetty ${jaasConfigFile}


		enableECPUpdateIdPWebXML

	else
				${Echo} "ECP Enabled is disabled, skipping  idp.home/conf/authn/jaas.config processing"

	fi


}

configShibbolethSSLForLDAPJavaKeystore()

{

# 	Fetch certificates from LDAP servers
	lcnt=1
	capture=0
	ldapCert="ldapcert.pem"
	${Echo} 'Fetching and installing certificates from LDAP server(s)'
	for i in `${Echo} ${ldapserver}`; do
		#Get certificate info
		${Echo} "QUIT" | openssl s_client -showcerts -connect ${i}:636 > ${certpath}${i}.raw 2>&1
		files="`${Echo} ${files}` ${certpath}${i}.raw"

		for j in `cat ${certpath}${i}.raw | sed -re 's/\ /\*\*\*/g'`; do
			n=`${Echo} ${j} | sed -re 's/\*\*\*/\ /g'`
			if [ ! -z "`${Echo} ${n} | grep 'BEGIN CERTIFICATE'`" ]; then
				capture=1
				if [ -s "${certpath}${ldapCert}.${lcnt}" ]; then
					lcnt=`expr ${lcnt} + 1`
				fi
			fi
			if [ ${capture} = 1 ]; then
				${Echo} ${n} >> ${certpath}${ldapCert}.${lcnt}
			fi
			if [ ! -z "`${Echo} ${n} | grep 'END CERTIFICATE'`" ]; then
				capture=0
			fi
		done
	done

	numLDAPCertificateFiles=0
	minRequiredLDAPCertificateFiles=1

	for i in `ls ${certpath}${ldapCert}.*`; do

		numLDAPCertificateFiles=$[$numLDAPCertificateFiles +1]
		md5finger=`${keytool} -printcert -file ${i} | grep MD5 | cut -d: -f2- | sed -re 's/\s+//g'`
		test=`${keytool} -list -keystore ${javaCAcerts} -storepass changeit | grep ${md5finger}`
		subject=`openssl x509 -subject -noout -in ${i} | awk -F= '{print $NF}'`
		if [ -z "${test}" ]; then
			${keytool} -import -noprompt -alias "${subject}" -file ${i} -keystore ${javaCAcerts} -storepass changeit >> ${statusFile} 2>&1
		fi
		files="`${Echo} ${files}` ${i}"
	done

	# note the numerical comparison of 
	if [ "$numLDAPCertificateFiles" -ge "$minRequiredLDAPCertificateFiles" ]; then

		${Echo} "Successfully fetched LDAP SSL certificate(s) fetch from LDAP directory. Number loaded: ${numLDAPCertificateFiles} into this keystore ${javaCAcerts}"
		

	else
		${Echo} "***SEVERE ERROR*** \n\nAutomatic LDAP SSL certificate fetch from LDAP directory failed!"
		${Echo} " As a result, the Shibboleth IdP will not connect properly.\nPlease ensure the provided FQDN (NOT IP ADDRESS) is resolvable and pingable before starting again"
		${Echo} "\n\nCleaning up and exiting"
		
		cleanBadInstall
		exit
		# Note for dev: if this was called prior to MySQL installation, it may be possible to just run again without doing VM Image restore

	fi



}

configContainerSSLServerKey()

{

        #set up ssl store
        if [ ! -s "${certpath}server.key" ]; then
                ${Echo} "Generating SSL key and certificate request"
                openssl genrsa -out ${certpath}server.key 2048 2>/dev/null
                openssl req -new -key ${certpath}server.key -out ${certREQ} -config ${Spath}/files/openssl.cnf -subj "/CN=${certCN}/O=${certOrg}/C=${certC}"
        fi
        if [ "${selfsigned}" = "n" ]; then
                ${Echo} "Put the certificate from TCS in the file: ${certpath}server.crt" >> ${messages}
                ${Echo} "Run: openssl pkcs12 -export -in ${certpath}server.crt -inkey ${certpath}server.key -out ${httpsP12} -name container -passout pass:${httpspass}" >> ${messages}
        else
                openssl x509 -req -days 365 -in ${certREQ} -signkey ${certpath}server.key -out ${certpath}server.crt
                if [ ! -d "/opt/shibboleth-idp/credentials/" ]; then
                        mkdir /opt/shibboleth-idp/credentials/
                fi

                ${Echo} "Self-signed webserver cert/key generated and placed in PKCS12 format in ${httpsP12} for port 443 usage"
                openssl pkcs12 -export -in ${certpath}server.crt -inkey ${certpath}server.key -out ${httpsP12} -name container -passout pass:${httpspass}
        
    			${Echo} "Loading self-signed webserver cert: ${certpath}server.crt into ${javaCAcerts} to permit TLS port 443 connections"

				svrSubject=`openssl x509 -subject -noout -in ${certpath}server.crt | awk -F= '{print $NF}'`
                ${keytool} -import -noprompt -alias "${svrSubject}" -file ${certpath}server.crt -keystore ${javaCAcerts} -storepass changeit >> ${statusFile} 2>&1

        fi
}


patchShibbolethLDAPLoginConfigs ()

{
	# 	application server specific
	if [ "${type}" = "ldap" ]; then
		ldapServerStr=""
		for i in `${Echo} ${ldapserver}`; do
			ldapServerStr="`${Echo} ${ldapServerStr}` ldap://${i}"
		done
		ldapServerStr="`${Echo} ${ldapServerStr} | sed -re 's/^\s+//'`"

		cat ${Spath}/${prep}/login.conf.diff.template \
			| sed -re "s#LdApUrI#${ldapServerStr}#;s/LdApBaSeDn/${ldapbasedn}/;s/SuBsEaRcH/${subsearch}/" \
			> ${Spath}/${prep}/login.conf.diff
		files="`${Echo} ${files}` ${Spath}/${prep}/login.conf.diff"
		patch /opt/shibboleth-idp/conf/login.config -i ${Spath}/${prep}/login.conf.diff >> ${statusFile} 2>&1
	fi

}

configShibbolethFederationValidationKey ()

{

	${fetchCmd} ${idpPath}/credentials/md-signer.crt http://md.swamid.se/md/md-signer.crt
	cFinger=`openssl x509 -noout -fingerprint -sha1 -in ${idpPath}/credentials/md-signer.crt | cut -d\= -f2`
	cCnt=1
	while [ "${cFinger}" != "${mdSignerFinger}" -a "${cCnt}" -le 10 ]; do
		${fetchCmd} ${idpPath}/credentials/md-signer.crt http://md.swamid.se/md/md-signer.crt
		cFinger=`openssl x509 -noout -fingerprint -sha1 -in ${idpPath}/credentials/md-signer.crt | cut -d\= -f2`
		cCnt=`expr ${cCnt} + 1`
	done
	if [ "${cFinger}" != "${mdSignerFinger}" ]; then
		 ${Echo} "Fingerprint error on md-signer.crt!\nGet ther certificate from http://md.swamid.se/md/md-signer.crt and verify it, then place it in the file: ${idpPath}/credentials/md-signer.crt" >> ${messages}
	fi

}

updateMachineTime ()
{
	${Echo} "Updating time from: ${ntpserver}"
	/usr/sbin/ntpdate ${ntpserver} > /dev/null 2>&1

# 	add crontab entry for ntpdate
	test=`crontab -l 2>/dev/null | grep "${ntpserver}" | grep ntpdate`
	if [ -z "${test}" ]; then
		${Echo} "Adding crontab entry for ntpdate"
		CRONTAB=`crontab -l 2>/dev/null | sed -re 's/^$//'`
		if [ ! -z "${CRONTAB}" ]; then
			CRONTAB="${CRONTAB}\n"
		fi
		${Echo} "${CRONTAB}*/5 *  *   *   *     /usr/sbin/ntpdate ${ntpserver} > /dev/null 2>&1" | crontab
	fi
}

updateMachineHealthCrontab ()
{


${Echo} "Installing and adding daily crontab health checks"

	# make sure directory is in place
	${Echo} "Creating IdP Installer installation in ${idpInstallerBase}"
	idpInstallerBin="${idpInstallerBase}/bin"
	dailyTasks="${idpInstallerBin}/dailytasks.sh"
	mkdir -p ${idpInstallerBin}

	${Echo} "adding dailytasks.sh to ${idpInstallerBin}"
	# note that this file is not federation specific, but generic 
	# 
	cp ${Spath}/files/dailytasks.sh.template ${dailyTasks}
	chmod ugo+rx ${dailyTasks}


	${Echo} "Preparing Crontab installation"
	
	test=`crontab -l 2>/dev/null | grep dailytasks`
	if [ -z "${test}" ]; then
		${Echo} "Adding crontab entry for dailytasks.sh "
		CRONTAB=`crontab -l 2>/dev/null | sed -re 's/^$//'`
		if [ ! -z "${CRONTAB}" ]; then
			CRONTAB="${CRONTAB}\n"
		fi
		${Echo} "${CRONTAB}0 23  *   *   *     ${dailyTasks} > /dev/null 2>&1" | crontab
	fi
		# fetch crontab again to show it
		CRONTAB=`crontab -l 2>/dev/null | sed -re 's/^$//'`
	
${Echo} "Crontab work complete, current crontab: ${CRONTAB} "

}


cleanupFilesRoutine ()
{

if [ "${cleanUp}" -eq 1 ]; then
# 	remove configs with templates
	for i in ${files}; do
		rm ${i}
	done
else
	${Echo} "Files created by script"
	for i in ${files}; do
		${Echo} ${i}
	done
fi

}
notifyUserBeforeExit()
{

	${Echo} "======================================"
	${Echo} "Install processing complete\n\n"

	if [ "${selfsigned}" = "n" ]; then
		cat ${certREQ}
		${Echo} "Looks like you have chosen to use use a commercial certificate for Shibboleth"
		${Echo} "Here is the certificate request you need to request a certificate from a commercial provider"
		${Echo} "Or replace the cert files in ${certpath}"
		${Echo} "\nNOTE!!! the keystore for https is a PKCS12 store\n"
	fi
	${Echo} ""
	${Echo} "If you installed Shibboleth, the default installation for Shibboleth is done.\n"
	${Echo} "To test it, register at testshib.org and register this idp and run a logon test."
	${Echo} "Certificate for idp metadata is in the file: /opt/shibboleth-idp/credentials/idp.crt"

if [ "${type}" = "ldap" ]; then
	${Echo} "\n"
	${Echo} "Looks like you have chosen to use ldap for Shibboleth single sign on."
	${Echo} "Please read this to customize the logon page: https://wiki.shibboleth.net/confluence/display/SHIB2/IdPAuthUserPassLoginPage"
fi

	${Echo} "Processing complete. You may want to reboot to ensure all services start up as expected.\nExiting.\n"


}



showAndCleanupMessagesFile ()

{

if [ -s "${messages}" ]; then
	cat ${messages}
	rm ${messages}
fi

}


askForSaveConfigToLocalDisk ()
{

cAns=$(askYesNo "Save config" "Do you want to save theese config values?\n\nIf you save theese values the current config file will be ovverwritten.\n NOTE: No passwords will be saved.")

	if [ "${cAns}" = "y" ]; then
		writeConfigFile
	fi

	if [ "${GUIen}" = "y" ]; then
		${whiptailBin} --backtitle "${my_ctl_federation} IDP Deployer" --title "Confirm" --scrolltext --clear --textbox ${downloadPath}/confirm.tx 20 75 3>&1 1>&2 2>&3
	else
		cat ${downloadPath}/confirm.tx
	fi
	cAns=$(askYesNo "Confirm" "Do you want to install this IDP with theese options?" "no")

	rm ${downloadPath}/confirm.tx
	if [ "${cAns}" = "n" ]; then
		exit
	fi

}

performStepsForShibbolethUpgradeIfRequired ()

{

if [ "${upgrade}" -eq 1 ]; then

${Echo} "Previous installation found, performing upgrade."

	eval ${distCmd1} &> >(tee -a ${statusFile})
	cd /opt
	currentShib=`ls -l /opt/${shibDir} | awk '{print $NF}'`
	currentVer=`${Echo} ${currentShib} | awk -F\- '{print $NF}'`
	if [ "${currentVer}" = "${shibVer}" ]; then
		mv ${currentShib} ${currentShib}.${ts}
	fi

	if [ ! -f "${downloadPath}/${shibDir}-${shibVer}.tar.gz" ]; then
		fetchAndUnzipShibbolethIdP
	fi
	tar xzf ${downloadPath}/${shibDir}-${shibVer}.tar.gz -C /opt
	chmod -R 755 /opt/${shibDir}-${shibVer}

	# Backup previous V2 environment
        #tar zcfP ${bupFile} --remove-files /opt/shibboleth-idp
        service tomcat6 stop

	if [ ! -d /opt/bak ]; then
		cp -ar /opt/shibboleth-idp /opt/bak 2>/dev/null
	fi

        rm -rf /opt/shibboleth-idp

	unlink /opt/${shibDir}
	ln -s /opt/${shibDir}-${shibVer} /opt/${shibDir}

	if [ -d "/opt/cas-client-${casVer}" ]; then
		installCasClientIfEnabled
	fi

	setJavaHome
else
	${Echo} "This is a fresh Shibboleth Install"


fi


}

jettySetupSetDefaults ()
{

        # ensure Jetty has proper startup environment for Java for all platforms
        jettyDefaults="/etc/default/jetty"
        jEnvString="export JAVA_HOME=${JAVA_HOME}"
 		jEnvPathString="export PATH=${PATH}:${JAVA_HOME}/bin"
 		jEnvJavaDefOpts='export JAVA_OPTIONS="-Didp.home=/opt/shibboleth-idp -Xmx1024M"'
 		# suppressed -XX:+PrintGCDetails because it was too noisy

		${Echo} "${jEnvString}" >> ${jettyDefaults}
       	${Echo} "${jEnvPathString}" >> ${jettyDefaults}
       	${Echo} "${jEnvJavaDefOpts}" >> ${jettyDefaults}
       	
        ${Echo} "Updated ${jettyDefaults} to add JAVA_HOME: ${JAVA_HOME} and java to PATH"

}
jettySetupManageCiphers() {


		removeCiphers="TLS_RSA_WITH_AES_128_GCM_SHA256 TLS_RSA_WITH_AES_128_CBC_SHA256 TLS_RSA_WITH_AES_128_CBC_SHA TLS_RSA_WITH_AES_256_CBC_SHA SSL_RSA_WITH_3DES_EDE_CBC_SHA"
	for cipher in $removeCiphers; do
		sed -i "/${cipher}/d" /opt/jetty/jetty-base/etc/jetty.xml
	done

}

jettySetup() {

        #Installing a specific version of Jetty

        # As of Aug 11, 2015, Jetty 9.3.x has not quieted down from having changes done.
        # to mitigate issues: ( https://bugs.eclipse.org/bugs/show_bug.cgi?id=473321 )
        #
        # This Jetty setup will use a specific Jetty version placed in the ~/downloads directory
        # Also be warned that the jetty site migrates links from the current jettyBaseURL to an archive
        # at random times.

		# Variable 'jetty9File' now originates from script.messages.sh to make it easier to 
		# manage versions
		
        #jetty9File='jetty-distribution-9.2.13.v20150730.tar.gz'

		# Ability to override version:
		# To override the downloads folder containing the binary: jetty-distribution-9.2.13.v20150730.tar.gz
        # uncomment the below variable assignment to dynamically fetch it instead:
        # jettyBaseURL is defined in script.messages.sh

        #jetty9File=`curl -s ${jettyBaseURL} | grep -oP "(?>)jetty-distribution.*tar.gz(?=&)"`
        

		jetty9Path=`basename ${jetty9File}  .tar.gz`
		jetty9URL="${jettyBaseURL}${jetty9File}"

		${Echo} "Preparing to install Jetty webserver ${jetty9File}"

        if [ ! -s "${downloadPath}/${jetty9File}" ]; then
                ${Echo} "Fetching Jetty from ${jetty9URL}"
                ${fetchCmd} ${downloadPath}/${jetty9File} "{$jetty9URL}"
        else
        	${Echo} "Skipping Jetty download, it exists here: ${downloadPath}/${jetty9File}"
                	
        fi

        # Manipulate Jetty configuration for the deployment
        
        cd /opt
        tar zxf ${downloadPath}/${jetty9File} >> ${statusFile} 2>&1
        cp -r /opt/${shibDir}/jetty-base /opt/${jetty9Path}/
        ln -s /opt/${jetty9Path} /opt/jetty
        sed -i 's/\# JETTY_HOME/JETTY_HOME=\/opt\/jetty/g' /opt/jetty/bin/jetty.sh
        sed -i 's/\# JETTY_USER/JETTY_USER=jetty/g' /opt/jetty/bin/jetty.sh
        sed -i 's/\# JETTY_BASE/JETTY_BASE=\/opt\/jetty\/jetty-base/g' /opt/jetty/bin/jetty.sh
        sed -i 's/TMPDIR:-\/tmp/TMPDIR:-\/opt\/jetty\/jetty-base\/tmp/g' /opt/jetty/bin/jetty.sh
        useradd -d /opt/jetty -s /bin/bash jetty
        ln -s /opt/jetty/bin/jetty.sh /etc/init.d/jetty

        if [ "${dist}" != "ubuntu" ]; then
                chkconfig jetty on
        else
                update-rc.d jetty defaults
        fi

        cat ${Spath}/files/idp.ini | sed -re "s#ShIbBKeyPaSs#${pass}#;s#HtTpSkEyPaSs#${httpspass}#" > /opt/jetty/jetty-base/start.d/idp.ini

        # Setting ownership
        chown jetty:jetty /opt/jetty/ -R
        chown -R jetty:jetty /opt/shibboleth-idp/

        jettySetupSetDefaults
        
        jettySetupManageCiphers


}

applyIptablesSettings ()

{

        iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
        iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 7443 -j ACCEPT
        iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 8443 -j ACCEPT
        iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 7443
        iptables -t nat -I OUTPUT -p tcp -o lo --dport 443 -j REDIRECT --to-ports 7443
        
        if [ "${dist}" == "centos" -o "${dist}" == "redhat" ]; then
		iptables-save > /etc/sysconfig/iptables
        elif [ "${dist}" == "ubuntu" ]; then
	 	iptables-save > /etc/iptables/rules.v4
	fi

	service iptables restart

}

restartJettyService ()

{
     
		${Echo} "Restarting Jetty to ensure everything has taken effect"

        if [ -f /var/run/jetty.pid ]; then
                service jetty stop
        fi
        service jetty start

     
}

applyFTICKS ()
{
		# Logic:
		#		If there is a federation specific setting for the loghost, use it, otherwise overlay configuraiton files

	

	# A. create salt automatically
	if [ -z "${fticksSalt}" ]; then
		fticksSalt=`openssl rand -base64 36 2>/dev/null`
	fi

	# B. overlay new audit.xml, logback.xml so bean and technique is in place (make backup first)
	overlayFiles="audit.xml logback.xml"
	for i in ${overlayFiles}; do
		cp /opt/shibboleth-idp/conf/${i} /opt/shibboleth-idp/conf/${i}.b4.replacement
		cp ${Spath}/files/${my_ctl_federation}/${i}.template /opt/shibboleth-idp/conf/${i}
	done

	# C. place 3 lines at end of idp.properties:
	# 		idp.fticks.federation=CAF
	# 		idp.fticks.salt=salt123salt
	# 		idp.fticks.loghost=localhost unless otherwise specified by existence of fticks-loghost.txt in Federation directory

	my_fticks_loghost_file="${Spath}/files/${my_ctl_federation}/fticks-loghost.txt"
	my_fticks_loghost_value="localhost"

	 if [ -s "${my_fticks_loghost_file}" ]; then
                ${Echo} "applyFTICKS detected a loghost file to use"
                my_fticks_loghost_value=`cat ${my_fticks_loghost_file}`

        else
				${Echo} "applyFTICKS did not detect an override to loghost"
        fi

				${Echo} "applyFTICKS loghost: ${my_fticks_loghost_value}"


	cp /opt/shibboleth-idp/conf/idp.properties /opt/shibboleth-idp/conf/idp.properties.b4.replacement
	echo "idp.fticks.federation=${my_ctl_federation}" >> /opt/shibboleth-idp/conf/idp.properties
	echo "idp.fticks.salt=${fticksSalt}" >> /opt/shibboleth-idp/conf/idp.properties
	echo "idp.fticks.loghost=${my_fticks_loghost_value}" >> /opt/shibboleth-idp/conf/idp.properties

	${Echo} "applyFTICKS updates completed"
}

patchShibbolethConfigs ()

{

	# patch shibboleth config files
        ${Echo} "Patching config files"
        mv /opt/shibboleth-idp/conf/attribute-filter.xml /opt/shibboleth-idp/conf/attribute-filter.xml.dist

        ${Echo} "patchShibbolethConfigs:Overlaying attribute-filter.xml with federation defaults"

        cp ${Spath}/files/${my_ctl_federation}/attribute-filter.xml.template /opt/shibboleth-idp/conf/attribute-filter.xml
        chmod ugo+r /opt/shibboleth-idp/conf/attribute-filter.xml

        ${Echo} "patchShibbolethConfigs:Overlaying relying-filter.xml with federation trusts"
        cat ${Spath}/xml/${my_ctl_federation}/metadata-providers.xml > /opt/shibboleth-idp/conf/metadata-providers.xml
        cat ${Spath}/xml/${my_ctl_federation}/attribute-resolver.xml > /opt/shibboleth-idp/conf/attribute-resolver.xml
        cat ${Spath}/files/${my_ctl_federation}/relying-party.xml > /opt/shibboleth-idp/conf/relying-party.xml

	if [ "${consentEnabled}" = "n" ]; then
		sed -i 's#<bean parent="Shibboleth.SSO" p:postAuthenticationFlows="attribute-release" />#<bean parent="Shibboleth.SSO" />#;s#<bean parent="SAML2.SSO" p:postAuthenticationFlows="attribute-release" />#<bean parent="SAML2.SSO" />#' /opt/shibboleth-idp/conf/relying-party.xml
	fi

        if [ "${google}" != "n" ]; then
                repStr='<!-- PLACEHOLDER DO NOT REMOVE -->'
                sed -i -e "/^${repStr}$/r ${Spath}/xml/${my_ctl_federation}/google-filter.add" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-filter.xml
                cat ${Spath}/xml/${my_ctl_federation}/google-relay.diff.template | sed -re "s/IdPfQdN/${certCN}/" > ${Spath}/xml/${my_ctl_federation}/google-relay.diff
                files="`${Echo} ${files}` ${Spath}/xml/${my_ctl_federation}/google-relay.diff"
                patch /opt/shibboleth-idp/conf/relying-party.xml -i ${Spath}/xml/${my_ctl_federation}/google-relay.diff >> ${statusFile} 2>&1
                cat ${Spath}/xml/${my_ctl_federation}/google.xml | sed -re "s/GoOgLeDoMaIn/${googleDom}/" > /opt/shibboleth-idp/metadata/google.xml
        fi

        if [ "${fticks}" != "n" ]; then
              
              	# apply an enhanced application of the FTICKS functionality

              	applyFTICKS
        fi

        if [ "${eptid}" != "n" ]; then
                if [ -z "${epass}" ]; then
                        epass=`${passGenCmd}`
                fi
		# grant sql access for shibboleth
		esalt=`openssl rand -base64 36 2>/dev/null`
		cat ${Spath}/xml/${my_ctl_federation}/eptid.sql.template | sed -re "s#SqLpAsSwOrD#${epass}#" > ${Spath}/xml/${my_ctl_federation}/eptid.sql
		files="`${Echo} ${files}` ${Spath}/xml/${my_ctl_federation}/eptid.sql"

		${Echo} "Create MySQL database and shibboleth user."
		mysql -uroot -p"${mysqlPass}" < ${Spath}/xml/${my_ctl_federation}/eptid.sql
		retval=$?
		if [ "${retval}" -ne 0 ]; then
			${Echo} "Failed to create EPTID database, take a look in the file '${Spath}/xml/${my_ctl_federation}/eptid.sql.template' and corect the issue." >> ${messages}
			${Echo} "Password for the database user can be found in: /opt/shibboleth-idp/conf/attribute-resolver.xml" >> ${messages}
		fi

                cat ${Spath}/xml/${my_ctl_federation}/eptid.add.attrCon.template \
                        | sed -re "s#SqLpAsSwOrD#${epass}#;s#Large_Random_Salt_Value#${esalt}#" \
                        > ${Spath}/xml/${my_ctl_federation}/eptid.add.attrCon
                files="`${Echo} ${files}` ${Spath}/xml/${my_ctl_federation}/eptid.add.attrCon"

                repStr='<!-- EPTID RESOLVER PLACEHOLDER -->'
                sed -i -e "/^${repStr}$/r ${Spath}/xml/${my_ctl_federation}/eptid.add.resolver" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-resolver.xml

                repStr='<!-- EPTID ATTRIBUTE CONNECTOR PLACEHOLDER -->'
                sed -i -e "/^${repStr}$/r ${Spath}/xml/${my_ctl_federation}/eptid.add.attrCon" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-resolver.xml

                repStr='<!-- EPTID PRINCIPAL CONNECTOR PLACEHOLDER -->'
                sed -i -e "/^${repStr}$/r ${Spath}/xml/${my_ctl_federation}/eptid.add.princCon" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-resolver.xml

                repStr='<!-- EPTID FILTER PLACEHOLDER -->'
                sed -i -e "/^${repStr}$/r ${Spath}/xml/${my_ctl_federation}/eptid.add.filter" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-filter.xml
        fi

        repStr='<!-- LDAP CONNECTOR PLACEHOLDER -->'
        sed -i -e "/^${repStr}$/r ${Spath}/xml/${my_ctl_federation}/ldapconn.txt" -e "/^${repStr}$/d" /opt/shibboleth-idp/conf/attribute-resolver.xml

	echo "applying chown "
	chmod o+r /opt/shibboleth-idp/conf/attribute-filter.xml

}


performPostUpgradeSteps ()
{
        if [ "${upgrade}" -eq 1 ]; then
                cat /opt/bak/credentials/idp.crt > /opt/shibboleth-idp/credentials/idp-signing.crt
                cat /opt/bak/credentials/idp.key > /opt/shibboleth-idp/credentials/idp-signing.key
        fi

}

checkAndLoadBackupFile ()
{
	backFile=`ls ${Spath} | egrep "^idp-export-.+tar.gz"`
	if [ "x${backFile}" != "x" ]; then
		${Echo} "Found backup, extracting and load settings" >> ${statusFile} 2>&1
		mkdir ${Spath}/extract 2>/dev/null
		cd ${Spath}/extract
		tar zxf ${Spath}/${backFile}
		if [ -s "${Spath}/extract/opt/shibboleth-idp/conf/fticks-key.txt" ]; then
			fticksSalt=`cat ${Spath}/extract/opt/shibboleth-idp/conf/fticks-key.txt`
		fi
		. settingsToImport.sh
		cd ${Spath}
	else
		${Echo} "No backup found." >> ${statusFile} 2>&1
	fi
}


loadDatabaseDump ()
{
	if [ -s "${Spath}/extract/sql.dump" ]; then
		if [ "${ehost}" = "localhost" -o "${ehost}" = "127.0.0.1" ]; then
			if [ "${etype}" = "mysql" ]; then
				mysql -uroot -p"${mysqlPass}" -D ${eDB} < ${Spath}/extract/sql.dump
			fi
		else
			${Echo} "Database not on localhost, skipping database import." >> ${messages}
		fi
	fi
}


overwriteConfigFiles ()
{
# 	if [ -d "${Spath}/extract/opt/shibboleth-idp/conf" -a "x`ls ${Spath}/extract/opt/shibboleth-idp/conf`" != "x" ]; then
# 		for i in `ls ${Spath}/extract/opt/shibboleth-idp/conf/`; do
# 			mv ${Spath}/extract/opt/shibboleth-idp/conf/$i /opt/shibboleth-idp/conf
# 			chown jetty /opt/shibboleth-idp/conf/$i
# 		done
# 	fi
	if [ -d "${Spath}/extract/opt/shibboleth-idp/metadata" -a "x`ls ${Spath}/extract/opt/shibboleth-idp/metadata 2>/dev/null`" != "x" ]; then
		for i in `ls ${Spath}/extract/opt/shibboleth-idp/metadata/`; do
			mv ${Spath}/extract/opt/shibboleth-idp/metadata/$i /opt/shibboleth-idp/metadata
			chown jetty /opt/shibboleth-idp/metadata/$i
		done
	fi
}


overwriteKeystoreFiles ()
{
	if [ -d "${Spath}/extract/opt/shibboleth-idp/credentials" -a "x`ls ${Spath}/extract/opt/shibboleth-idp/credentials 2>/dev/null`" != "x" ]; then
		mv ${Spath}/extract/opt/shibboleth-idp/credentials/* /opt/shibboleth-idp/credentials
		chown jetty /opt/shibboleth-idp/credentials/*
	fi
	if [ -f "${Spath}/extract/${httpsP12}" ]; then
		mv ${Spath}/extract/${httpsP12} ${httpsP12}
		chown jetty ${httpsP12}
	fi
	if [ "x${keyFile}" != "x" -a -f "${Spath}/extract/${keyFile}" ]; then
		mv ${Spath}/extract/${keyFile} ${keyFile}
		chown jetty ${keyFile}
	fi
}


invokeShibbolethInstallProcessJetty9 ()
{

        ### Begin of SAML IdP installation Process

	containerDist="Jetty9"

	installDependanciesForInstallation

	# check for installed IDP
	setVarUpgradeType

	setJavaHome

	# Override per federation
	performStepsForShibbolethUpgradeIfRequired

# 	check for backup file and use it if available
	checkAndLoadBackupFile

	if [ "${installer_interactive}" = "y" ]
	then
		askForConfigurationData
		prepConfirmBox
		askForSaveConfigToLocalDisk
	fi

	notifyMessageDeployBeginning


	setVarPrepType
	setVarCertCN
	setVarIdPScope
	
	setJavaCACerts

	setJavaCryptographyExtensions


	generatePasswordsForSubsystems

	patchFirewall

	# installEPEL Sept 26 - no longer needed since Maven is installed via zip

	[[ "${upgrade}" -ne 1 ]] && fetchAndUnzipShibbolethIdP

	configShibbolethXMLAttributeResolverForLDAP

	runShibbolethInstaller

        installEPTIDSupport

	installCasClientIfEnabled

	createCertificatePathAndHome

	# Override per federation
	installCertificates

	# process certificates for LDAP connections
	fetchLDAPCertificates
	configShibbolethSSLForLDAPJavaKeystore

	# Override per federation
	configContainerSSLServerKey

	# Override per federation
	configShibbolethFederationValidationKey

        patchShibbolethConfigs

	performPostUpgradeSteps

        jettySetup

	enableECP

	updateMachineTime

	updateMachineHealthCrontab

# 	install files from backup
	overwriteConfigFiles
	overwriteKeystoreFiles

# 	load the database dump if available
	loadDatabaseDump

	applyIptablesSettings

	restartJettyService

}


invokeShibbolethUpgradeProcess()
{
        if [ -a "/opt/${jetty9Path}/bin/jetty.sh" ]; then
                echo "Jetty detected as installed"
        else
                if [ ${dist} == "ubuntu" ]; then
                        apt-get -y remove --purge tomcat6 openjdk* default-jre java*
                else
                        yum -y remove tomcat* java*
                fi
                cleanBadInstall "NotExit"
                fticks="y"
                eptid="n"
                invokeShibbolethInstallProcessJetty9
        fi
}

invokeShibbolethInstallProcess () ##Default
{

        invokeShibbolethInstallProcessJetty9

}

