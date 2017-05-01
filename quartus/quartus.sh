#!/bin/bash


if [ -z "$QUARTUS_HOME" ]; then
    echo "Install Quartus software (13.1) and set QUARTUS_HOME (e.g. in your bashrc)."
    exit 1
fi    

# Quartus system direcory
export QUARTUS_ROOTDIR=$QUARTUS_HOME/quartus
export QUARTUS_ROOTDIR_OVERRIDE=$QUARTUS_HOME/quartus

# Turn on Quartus 64-bit processing.
export QUARTUS_64BIT=1            

# Add Quartus bin to PATH variable
export PATH=$PATH:$QUARTUS_ROOTDIR/bin

# Setup Quartus license server
if [ -z "$LM_LICENSE_FILE" ]; then
    export LM_LICENSE_FILE=""
fi    

# *** EDIT: Specify your license server or file ***
export LM_LICENSE_FILE=${WORKDIR}/license.dat:$LM_LICENSE_FILE
#export LM_LICENSE_FILE='1800@my_license_server.com':$LM_LICENSE_FILE
