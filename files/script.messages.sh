#!/bin/sh
# UTF-8

mdSignerFinger="12:60:D7:09:6A:D9:C1:43:AD:31:88:14:3C:A8:C4:B7:33:8A:4F:CB"
GUIen=y
cleanUp=1
upgrade=0

# Important directories

shibDir="shibboleth-identity-provider"
idpInstallerBase="/opt/idp-installer"
idpInstallerBin="${idpInstallerBase}/bin"
fileBkpPostfix="b4UpdatesApplied"
systemdHome="/usr/lib/systemd/system"

#
# Key Component Versions

shibVer="3.2.1"
casVer="3.3.3"
mysqlConVer="5.1.35"
jettyVer="9.2.14.v20151106"

# database pooling connectivity dependancies
commonsDbcp2Ver="2.1.1"
commonsPool2Ver="2.4.2"

# uncomment if you want an older jetty version: jettyVer="9.2.13.v20150730"

javaBuildName="8u65-b17"
javaName="8u65"
javaMajorVersion="8"
javaVer="1.8.0_65"
jcePolicySrc="jce_policy-8.zip"
JCEUnlimitedResponse="2147483647"

# this is the java starting heap size. We put the 'M' after it upon installation
javaMaxHeapSize="2048"


#
# IdP-Installer file manifest (ie the files we create for ourselves)

# these are in the bin directory
idpIFiledailyTasks="dailytasks.sh"
idpIFilejettySystemdService="jetty.service"

# Key Component Versions end
#

# This URL determines which base to derive 'latest' from
# --> this is the very very latest: jettyBaseURL="http://download.eclipse.org/jetty/stable-9/dist/"
# Below is the 9.2.11 one
jettyBaseURL="http://download.eclipse.org/jetty/${jettyVer}/dist/"
# this determines which file to check for in the downloads directory first.
jetty9File="jetty-distribution-${jettyVer}.tar.gz"

# Prior to Shibboleth v3.2.0 the jettyBasePath is commented as below, otherwise it's the uncommented one
	#jettyBasePath="/opt/${shibDir}/jetty-base"
jettyBasePath="/opt/${shibDir}/embedded/jetty-base"
	# as well, it is also missing the the tmp and logs directories which we will take care of 
	# in the method to set up things.


files=""
ts=`date "+%s"`
whiptailBin=`which whiptail 2>/dev/null`
if [ ! -x "${whiptailBin}" ]
then
	GUIen="n"
fi

#
# Other variables used in configuration
#
backupPath="${Spath}/backups/"
filesPath="${Spath}/files"
templatePath="${Spath}/assets"
templatePathEduroamCentOS="${Spath}/assets/etc/raddb"
templatePathEduroamCentOS7="${Spath}/assets/etc/raddb7"
templatePathEduroamUbuntu="${Spath}/assets/etc/freeradius"
templatePathEduroamRedhat="${Spath}/assets/etc/raddb"
CentOSEduroamModules="/modules"
CentOS7EduroamModules="/mods-available"
UbuntuEduroamModules="/modules"
RedhatEduroamModules="/modules"
downloadPath="${Spath}/downloads"
backupList="${backupPath}/recoverypoints.txt"
freeradiusfile="${Spath}/files/freeradius.tx"


mainMenuExitFlag=0
whipSize="13 75"
certpath="/opt/shibboleth-idp/ssl/"
httpsP12="/opt/shibboleth-idp/credentials/https.p12"
certREQ="${certpath}webserver.csr"
passGenCmd="openssl rand -base64 20"
epass=`${passGenCmd}`
messages="${Spath}/msg.txt"
statusFile="${Spath}/status.log"
bupFile="/opt/backup-shibboleth-idp.${ts}.tar.gz"

idpPath="/opt/shibboleth-idp"
idpConfPath="${idpPath}/conf"
idpEditWebappDir="${idpPath}/edit-webapp"
idpEditWebappLibDir="${idpEditWebappDir}/WEB-INF/lib/"

esalt=`openssl rand -base64 36 |tr -d '/\\+' 2>/dev/null`
certificateChain="https://webkonto.student.hig.se/chain.pem"
digicertChain="https://webkonto.student.hig.se/digichain.pem"
jettyDepend="https://build.shibboleth.net/nexus/content/repositories/releases/net/shibboleth/utilities/jetty9/jetty9-dta-ssl/1.0.0/jetty9-dta-ssl-1.0.0.jar"
dist=""
distCmdU=""
distCmdUa=""
distCmd1=""
distCmd2=""
#Deprecated:2016-12-22:TODO:remove next release distCmd3=""
distCmd4=""
distCmd5=""
dist_install_nc=""
dist_install_netstat=""
dist_install_ldaptools=""
distCmdEduroam=""
distEduroamPath=""
distRadiusGroup=""
templatePathEduroamDist=""
distEduroamModules=""
fetchCmd="curl --silent -k -L --output"
shibbURL="http://shibboleth.net/downloads/identity-provider/${shibVer}/${shibDir}-${shibVer}.tar.gz"
casClientURL="http://downloads.jasig.org/cas-clients/cas-client-${casVer}-release.zip"
mysqlConnectorURL="http://ftp.sunet.se/pub/unix/databases/relational/mysql/Downloads/Connector-J/mysql-connector-java-${mysqlConVer}.tar.gz"

# Titles for the whiptail environment for branding
BackTitleSWAMID="SWAMID"
BackTitleCAF="Canadian Access Federation"
BackTitle="IDP Deployer"

# define commands
ubuntuCmdU="apt-get update --fix-missing"
ubuntuCmdUa="apt-get -y upgrade"
ubuntuCmd1="apt-get -y install patch ntpdate unzip curl libxml2-utils xsltproc"
ubuntuCmd2="apt-get -y install git-core"
ubuntuCmd3="apt-get -y install openjdk-6-jdk default-jre"
ubuntuCmd4="apt-get -y install tomcat6"
ubuntuCmd5="apt-get -y install mysql-server"
tomcatSettingsFileU="/etc/default/tomcat6"
ubutnu_install_nc="apt-get -y install netcat"
ubuntu_install_ldaptools="apt-get -y install ldap-utils"
ubuntuEduroamPath="/etc/freeradius"
ubuntuRadiusGroup="freerad"

redhatCmdU="yum -y update"
redhatCmd1="yum -y install patch ntpdate unzip curl libxslt libxml2"
redhatCmd2="yum -y install git-core"
#Deprecated:2016-12-22:TODO:remove next releaseredhatCmd3="yum -y install java-1.7.0-openjdk java-1.7.0-openjdk-devel"
redhatCmd4="yum -y install tomcat6"
redhatCmd5="yum -y install mysql-server"
redhat_install_nc="yum -y install nc"
redhat_install_netstat="yum -y install net-tools"
redhat_install_ldaptools="yum -y install openldap-clients"
redhatEduroamPath="/etc/raddb"
redhatRadiusGroup="radiusd"

ubuntuCmdEduroam="apt-get install -y ntpdate samba winbind freeradius freeradius-krb5 freeradius-ldap freeradius-utils freeradius-mysql make"
redhatCmdEduroam="yum -y install bind-utils net-tools samba samba-winbind samba-winbind-clients freeradius freeradius-krb5 freeradius-ldap freeradius-perl freeradius-python freeradius-utils freeradius-mysql make" 
#redhatCmdFedSSO="yum -y install java-1.6.0-openjdk-devel tomcat6 mysql-server mysql"
centosCmdEduroam="yum -y install bind-utils net-tools samba samba-winbind samba-winbind-clients freeradius freeradius-krb5 freeradius-ldap freeradius-perl freeradius-python freeradius-utils freeradius-mysql make" 
centosCmdFedSSO="yum -y install java-1.6.0-openjdk-devel tomcat6 mysql-server mysql"

centosCmdU="yum -y update"
centosCmdUa="yum clean all"
centosCmd1="yum -y install patch ntpdate unzip curl libxml2"
centosCmd2="yum -y install git"
#Deprecated:2016-12-22:TODO:remove next release centosCmd3="yum -y install java-1.7.0-openjdk java-1.7.0-openjdk-devel"
centosCmd4="yum -y install tomcat6"
centosCmd5="yum -y install mysql-server"
tomcatSettingsFileC="/etc/sysconfig/tomcat6"
centos_install_nc="yum -y install nc"
centos_install_netstat="yum -y install net-tools"
centos_install_ldaptools="yum -y install openldap-clients"
centosEduroamPath="/etc/raddb"
centosRadiusGroup="radiusd"

redhatEpel5="rpm -Uvh http://download.fedoraproject.org/pub/epel/5/i386/epel-release-5-4.noarch.rpm"
redhatEpel6="rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm"


slesCmdU="zypper -q -n refresh"
slesCmd1="zypper -n install -l patch ntp unzip curl libxml2-tools update-alternatives"
slesCmd2="zypper -n install -l git-core"
slesCmd4="zypper -n install -l tomcat"
slesCmd5="zypper -n install -l mysql"
tomcatSettingsFileS="/etc/default/tomcat6"
sles_install_nc="zypper -n install -l netcat"
sles_install_netstat="zypper -n install -l net-tools"
sles_install_ldaptools="zypper -n install -l openldap2-client"
slesEduroamPath="/etc/raddb"
slesRadiusGroup="radiusd"
slesMaven12="zypper ar http://download.opensuse.org/repositories/devel:/tools:/building/SLE_12/devel:tools:building.repo;zypper refresh -q -n --gpg-auto-import-keys refresh"

slesCmdEduroam="zypper -n install -l bind-utils ntp samba samba-winbind freeradius-server freeradius-server-krb5 freeradius-server-ldap freeradius-server-perl freeradius-server-python freeradius-server-utils freeradius-server-mysql make"
slesCmdFedSSO="zypper -n install -l java-1_7_0-openjdk-devel tomcat mysql"

# info for validation of required fields for deployer options
# one long list but broken apart into sections similar to the HTML installer page
# excluded ones: my_eduroamDomain (used on HTML page but nowhere else)
#				 installer_* are not needed either EXCEPT for: installer_section0_buildComponentList which is the list of features to activate
#
# SPECIAL NOTE: It would be prudent to keep these fields in sync with the required fields in the HTML page
#
# The variable names are specifically not Camel cased on the last element (eduroam, shibboleth)
# to allow them to be assembled as needed so we can just have a list for the next 'element' that may be used
# see the ValidateConfig() function where these will be processed

requiredNonEmptyFieldseduroam=" krb5_libdef_default_realm krb5_realms_def_dom krb5_domain_realm smb_workgroup smb_netbios_name smb_passwd_svr smb_realm"
requiredNonEmptyFieldseduroam="${requiredNonEmptyFieldseduroam} freeRADIUS_realm freeRADIUS_cdn_prod_passphrase freeRADIUS_pxycfg_realm"
requiredNonEmptyFieldseduroam="${requiredNonEmptyFieldseduroam} freeRADIUS_clcfg_ap1_ip freeRADIUS_clcfg_ap1_secret freeRADIUS_clcfg_ap2_ip freeRADIUS_clcfg_ap2_secret"
requiredNonEmptyFieldseduroam="${requiredNonEmptyFieldseduroam} freeRADIUS_ca_state freeRADIUS_ca_local freeRADIUS_ca_org_name freeRADIUS_ca_email freeRADIUS_ca_commonName" 
requiredNonEmptyFieldseduroam="${requiredNonEmptyFieldseduroam} freeRADIUS_svr_state freeRADIUS_svr_local freeRADIUS_svr_org_name freeRADIUS_svr_email freeRADIUS_svr_commonName"

requiredNonEmptyFieldsshibboleth=" appserv type idpurl ntpserver ldapserver ldapbinddn ldappass ldapbasedn subsearch fticks eptid google ninc freeRADIUS_realm freeRADIUS_svr_org_name freeRADIUS_svr_country consentEnabled ECPEnabled iprangesallowed"

requiredEnforceConnectivityFieldseduroam="smb_passwd_svr ldapserver"
requiredEnforceConnectivityFieldsshibboleth="ldapserver"
