#!/bin/sh
set -xv

source $HOME/my_venv/bin/activate
module load scipy

aexpname=Arctic_LD_icev_abs_ntraj96_k10_LBlock10_LRun180_p1_startID0001
#expname=Arctic_control360_ntraj500_k0_LBlock180_LRun180_p1_startID0001
here=`pwd`
##
aexpdir=(/gpfs/work/IscrB_INCIPIT/gzappa/PLASIM-large-dev/${aexpname})

for expdir in ${aexpdir[@]}; do
    expname=`echo $expdir | rev |  cut -d / -f 1 | rev`
    ntrajs=$(echo $expname | grep -o -P '(?<=ntraj)[0-9]+')
    NDays=$(echo $expname | grep -o -P '(?<=LBlock)[0-9]+')
    TotDays=$(echo $expname | grep -o -P '(?<=LRun)[0-9]+')
    endblock=`echo "${TotDays}/${NDays}" | bc`
    ##

    cd ${expdir}/resampling/
    for a in `ls *.tar`; do
	tar -xvf $a
    done
    
    cd $here
    python -t reconstruct.py ${expdir} ${expname} ${ntrajs} ${NDays} 1 ${endblock}
    #python -t reconstruct_var_V2.py ${expdir} ${expname} ${ntrajs} 1 ${endblock}
done

exit 0
