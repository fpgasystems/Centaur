#!/bin/bash

export WORKDIR=$PWD

if [ -z "$CENTAUR_HOME" ]; then
   export CENTAUR_HOME=$WORKDIR
   echo "CENTAUR_HOME varialbe was set"
fi

AFU_QSF_FILE="$CENTAUR_HOME/quartus/par/qsf_afu_PAR_files.qsf"
ENV_SETTINGS_QSF_FILE="$CENTAUR_HOME/quartus/par/qsf_env_settings.qsf"
QUARTUS_SETUP_FILE="$CENTAUR_HOME/quartus/setup.sh"

# clean afu qsf file from doppiodb operators
echo "set_global_assignment -name SEARCH_PATH \$APP_OPS" > $AFU_QSF_FILE

# clean environments settings  file
echo "set MY_WORKDIR $::env(WORKDIR)
set REL_RTL_SRC \"/qpi\"
set QPI_RTL_SRC \$MY_WORKDIR\$REL_RTL_SRC
set CENTAUR_SRC \$::env(CENTAUR_HOME)/rtl
set APP_OPS \$::env(CENTAUR_HOME)/app/rtl
puts \" Variable defined QPI_RTL_SRC: \$QPI_RTL_SRC\"
puts \" Variable defined CENTAUR_RTL_SRC: \$CENTAUR_SRC\"
puts \" Variable defined APP_OPS_SRC: \$APP_OPS\" 
" > $ENV_SETTINGS_QSF_FILE


echo "#!/bin/bash

export WORKDIR=\$PWD
source \$WORKDIR/quartus.sh
alias cdw='cd \$WORKDIR'

if [ -z \"\$CENTAUR_HOME\" ]; then
   export CENTAUR_HOME=\$WORKDIR/..
   echo \"CENTAUR_HOME varialbe was set\"
fi

#Tell Git to stop tracking changes on ome2_ivt.qsf
git update-index --assume-unchanged par/ome2_ivt.qsf" > $QUARTUS_SETUP_FILE


