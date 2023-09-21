#!/bin/bash

set -e

DOMAIN=${DOMAIN:-SAMDOM.LOCAL}
DOMAINPASS=${DOMAINPASS:-youshouldsetapassword}
LDAP_ALLOW_INSECURE=${LDAP_ALLOW_INSECURE:-false}
NOCOMPLEXITY=${NOCOMPLEXITY:-false}
SAMBA_HOST_IP=${SUBNET}.${IPV4_ADDRESS}
SETUP_LOCK_FILE="/var/lib/samba/private/.setup.lock.do.not.remove"


LDOMAIN=${DOMAIN,,}
UDOMAIN=${DOMAIN^^}
URDOMAIN=${UDOMAIN%%.*}

SUPERVISOR_PATH="/etc/supervisor.d"

welcome() {
   echo "+----------------------------------------------------------+"
   echo "|                                                          |"
   echo "|              Welcome to Samba AD DC Docker!              |"
   echo "|                                                          |"
   echo "+----------------------------------------------------------+"
}

appSetup () {
    welcome

    #echo -n "Initializing samba database...          "
    #SAMBA_ADMIN_PASSWORD=${SAMBA_ADMIN_PASSWORD:-$(pwgen -cny 10 1)}
    #echo "[DONE]"

#    # if kerberos server used
#    echo -n "Initializing KDC DB master key...     "
#    export KERBEROS_PASSWORD=${KERBEROS_PASSWORD:-$(pwgen -cny 10 1)}
#    echo "[DONE]"

    echo ""
    echo "Samba administrator password:         ${DOMAINPASS}"

#    # if kerberos server used
#    echo "Kerberos KDC database master key:     $KERBEROS_PASSWORD"
    echo ""

    # Provision Samba
    rm -f /etc/samba/smb.conf
    rm -rf /var/lib/samba/*
    samba-tool domain provision \
      --use-rfc2307 \
      --domain=${URDOMAIN} \
      --realm=${UDOMAIN} \
      --server-role=dc\
      --dns-backend=SAMBA_INTERNAL \
      --adminpass=${DOMAINPASS}

    # disable password complexity
    if [[ ${NOCOMPLEXITY,,} == "true" ]]; then
       samba-tool domain passwordsettings set --complexity=off
       samba-tool domain passwordsettings set --history-length=0
       samba-tool domain passwordsettings set --min-pwd-length=8
       samba-tool domain passwordsettings set --min-pwd-age=0
       samba-tool domain passwordsettings set --max-pwd-age=0
    fi

    echo ""
    echo -n "Creating new smb.conf...              "
    sed -i "/\[global\]/a \
    \\\tidmap_ldb:use rfc2307 = yes\\n\
    wins support = yes\\n\
    template shell = /bin/bash\\n\
    winbind nss info = rfc2307\\n\
    idmap config ${URDOMAIN}: range = 10000-20000\\n\
    idmap config ${URDOMAIN}: backend = ad\
    " /etc/samba/smb.conf
     echo "[DONE]"

    if [[ ${INSECURELDAP,,} == "true" ]]; then
       sed -i "/\[global\]/a \
       \\\tldap server require strong auth = no\
       " /etc/samba/smb.conf
    fi

    echo -n "Moving krb5.conf...                   "
    cat /var/lib/samba/private/krb5.conf > /etc/krb5.conf
    echo "[DONE]"

#    # if kerberos server used
     # Create Kerberos database
#    echo -n "Creating KDC database...              "
#    ( expect kdb5_util_create.expect )
#    echo "[DONE]"

    # Export kerberos keytab for use with sssd
    #if [ "${OMIT_EXPORT_KEY_TAB}" != "true" ]; then
    #    samba-tool domain exportkeytab /etc/krb5.keytab --principal ${HOSTNAME}\$
    #fi

    # add script provision_dc.sh
    . /docker-entrypoint-init.d/provision_dc.sh

    touch "${SETUP_LOCK_FILE}"
}

appStart () {
    if [ ! -f "${SETUP_LOCK_FILE}" ]; then
      appSetup
    fi

    echo ""
    welcome
    echo ""
    echo -n "Moving krb5.conf...                   "
    cat /var/lib/samba/private/krb5.conf > /etc/krb5.conf
    echo "[DONE]"

    # Set up supervisor
    echo -n "Creating supervisor path...           "
    mkdir ${SUPERVISOR_PATH}
    echo "[DONE]"
    echo -n "Creating supervisor ini...            "
    (
    echo "[supervisord]" > ${SUPERVISOR_PATH}/supervisord.ini
    echo "nodaemon=true" >> ${SUPERVISOR_PATH}/supervisord.ini
    echo "" >> ${SUPERVISOR_PATH}/supervisord.ini
    echo "[program:samba]" >> ${SUPERVISOR_PATH}/supervisord.ini
    echo "command=/usr/sbin/samba -i" >> ${SUPERVISOR_PATH}/supervisord.ini
    echo "" >> ${SUPERVISOR_PATH}/supervisord.ini
    echo "[program:syslog]" >> ${SUPERVISOR_PATH}/supervisord.ini
    echo "command=/usr/sbin/rsyslogd -n" >> ${SUPERVISOR_PATH}/supervisord.ini

#    # if kerberos server used
#    echo "" >> ${SUPERVISOR_PATH}/supervisord.ini
#    echo "[program:kerberos]" >> ${SUPERVISOR_PATH}/supervisord.ini
#    echo "command=/usr/sbin/krb5kdc -n" >> ${SUPERVISOR_PATH}/supervisord.ini
    )
    echo "[DONE]"

    # 
    if [[ ${DNS_FORWARDER} ]]; then
       echo -n "Setting dns forward IP...             "
       sed -i -e "/dns forwarder/c\    dns forwarder = ${DNS_FORWARDER}" /etc/samba/smb.conf
       echo "[DONE]"
    fi

    # Start supervisor
    echo "Starting supervisor...      "
    /usr/bin/supervisord -c /etc/supervisor.d/supervisord.ini
}

appHelp () {
	echo "Available options:"
	echo " app:start          - Starts all services needed for Samba AD DC"
	echo " app:setup          - First time setup."
	echo " app:setup_start    - First time setup and start."
	echo " app:help           - Displays the help"
	echo " [command]          - Execute the specified linux command eg. /bin/bash."
}

# Set timezone variable
if ! [ -z ${TZ} ]; then

  # delete file timezone if exist
  if [ -f /etc/timezone ] ; then
    rm /etc/timezone
  fi

  # delete file localtime if exist and create new one
  if [ -f /etc/localtime ] ; then
    rm /etc/localtime
    echo -n "Setting timezone...                   "
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone
    echo "[DONE]"
  else
    echo -n "Setting timezone...                   "
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone
    echo "[DONE]"
  fi
fi

case "$1" in
	app:start)
		appStart
		;;
	app:setup)
		appSetup
		;;
	app:setup_start)
		appSetup
		appStart
		;;
	app:help)
		appHelp
		;;
	*)
		if [ -x $1 ]; then
			$1
		else
			prog=$(which $1)
			if [ -n "${prog}" ] ; then
				shift 1
				$prog $@
			else
				appHelp
			fi
		fi
		;;
esac

exit 0
