#!/bin/bash

export WORKDIR=$PWD
source $WORKDIR/quartus.sh
alias cdw='cd $WORKDIR'

if [ -z "$CENTAUR_HOME" ]; then
   export CENTAUR_HOME=$WORKDIR/..
   echo "CENTAUR_HOME varialbe was set"
fi

if [ -z "$DOPPIO_HOME" ]; then
   	echo "Set DOPPIO_HOME env variable to the directory of harp-applications"
fi


#Tell Git to stop tracking changes on ome2_ivt.qsf
git update-index --assume-unchanged par/ome2_ivt.qsf
