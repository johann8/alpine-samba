#!/bin/bash

set -e

BASIC_OU="Standort Berlin"

appProvision () {
   # set administrator password
   # samba-tool user setpassword administrator --newpassword=MySuperPassword22

   # create OUs
   # samba-tool ou list
   samba-tool ou create "OU=${BASIC_OU}"
   samba-tool ou create OU="Users,OU=${BASIC_OU}"
   samba-tool ou create OU="Groups,OU=${BASIC_OU}"
   samba-tool ou create OU="Computers,OU=${BASIC_OU}"
   samba-tool ou create OU="Server,OU=${BASIC_OU}"

   # create group
   # samba-tool group list
   samba-tool group add service --groupou="OU=Groups,OU=${BASIC_OU}"

   # create user
   # samba-tool user list
   # samba-tool user show suser
   # DOMAIN=brg.lan
   samba-tool user create tuser1 Test3456 --userou="OU=Users,OU=${BASIC_OU}" --use-username-as-cn --given-name Test --surname User1 --mail-address t.user1@{DOMAIN}
   samba-tool user create suser Test3456 --userou="OU=Users,OU=${BASIC_OU}" --use-username-as-cn --given-name Service --surname User --mail-address s.user@{DOMAIN}

   # add user into group
   # samba-tool group listmembers service
   samba-tool group addmembers "service" suser
}


# Start profision if PROFISION_DC=true
if [[ "${PROFISION_DC}" = true ]]; then
   # Start profision dc
   echo "Starting DC profision...            "
   appProvision   
fi
