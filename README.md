General Information
===================================================
Centaur is a framwork for hybrid databases on the Intel HARP machine v1.
This git only contains the core components of Centaur. The database part of Centaur is in the "doppiodb" git repository. 
The core components of Centaur can be used also for developing non-database applications. 
Following we will describe how to use Centaur with a Database and without a database.

Pre-requisites
====================================

Centaur is developed for the first version of Intel's HARP machine. to use Centaur you need to provide the folowing:

In ~/workspace/Centaur/quartus/ run the commands

	mkdir qpi
	cp ~/path-to-qpi-qxp-intel-files/ome_bot-SPL.qxp qpi/ome_bot-SPL.qxp
	cp ~/path-to-qpi-qxp-intel-files/ome_top.sv qpi/ome_top.sv

Install Intel AAL framework before installing Centaur.


Using Centaur with DoppioDB
====================================

Clone Centaur and DoppioDB repositories to your workspace directory:

	git clone https://github.com/fpgasystems/Centaur.git
	git clone https://github.com/fpgasystems/doppiodb.git

**Installation**

set home directory to Centaur:

	export CENTAUR_HOME=~/workspace/Centaur

In ~/workspace/doppiodb/fpga run **make**. This will compile the core and database components of Centaur. 

Then install MonetDB. In ~/workspace/doppiodb run the following commands:

	./boostrap
	./configure --prefix=$HOME/MonetDB
	make
	make install

Your installation can be found in $HOME/MonetDB

**Run Quartus**

To run quartus and get a bitstream run the following

	cd ~/workspace/Centaur/quartus/
	export DOPPIODB_HOME=~/workspace/doppiodb
	sh setup.sh
	quartus par/ome2_ivt.qpf


Using Centaur without a database
==============================================

Clone Centaur repository to your workspace directory:

	git clone https://github.com/fpgasystems/Centaur.git

**Installation**

set home directory to Centaur:

	export CENTAUR_HOME=~/workspace/Centaur

set up the Centaur to standalone

	cd Centaur
	bash standalone.sh 

In ~/workspace/Centaur/app
add your application to the app.cpp file

run **make** to build your application. 
Your application executable "app" is in ~/workspace/Centaur/app.

**Run Quartus**

To run quartus and get a bitstream run the following

	cd ~/workspace/Centaur/quartus/
	sh setup.sh
	quartus par/ome2_ivt.qpf










