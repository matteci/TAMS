#!/bin/bash -l
#
#SBATCH -J testTAMS              # the name of your job   
#SBATCH -p normal            # request the short partition, job takes less than 3 hours  
#SBATCH -t 12:00:00          # time in dd-hh:mm:ss you want to reserve for the job
#SBATCH -n 10               # the number of cores you want to use for the job, SLURM automatically determines how many nodes are needed
#SBATCH -o log_postpro.%j.o     # the name of the file where the standard output will be written to. %j will be the jobid determined by SLURM
#SBATCH -e log_postpro.%j.o     # the name of the file where potential errors will be written to. %j will be the jobid determined by SLURM

##### LOAD PYTHON VIRTUAL ENVIRONMENT WITH MODULES: numpy, math, netCDF4
#source $HOME/my_venv/bin/activate


source /opt/apps/miniconda3/etc/profile.d/conda.sh

# Activate the Conda environment
conda activate myenv

#env > env_output.txt

module purge 
#module load cdo
#module load netCDF/GCC

#module show cdo
 
#### NAMELIST ##############################################################
nameThisFile='Lorenz_TAMS_plasim'
expname="TAMS_VARNAME"
#
# Parameters controlling length of experiment<
newexperiment=2     # 1: nuovo 0: esperimento che ha già calcolato il set di base  othervalues: dovrebbe non ricreare le cartelle ma ricalcolare tutti gli anni di simulazioni (comunque sconsigliato perchè il noise non riparte!
resty=2482
initblock=1	   # block è periodo lungo come resampling. 
endblock=10	   # ultimo blocco: ti definisce lunghezza integrazione
force=0           # sovrascrittura delle cartelle di output
light=1           # light postprocessing as defined in postpro_light.sh

#Parameters controlling climate mean state
CO2=554 #at the moment not updated

# Parameters controlling resampling, observable and weights
varname='amoc'    #variabile usata per resampling
domain='DIAG'     # domain in PLASIM output of varname

resamplingname='TAMS_Matteo.py'   # file che fa il resampling
ntrajs=20
NMonths=12     # length resampling block
NDays=0      # length resampling block
LYear=360     # 
startID=l207-y${resty}_r2  # 0BCD (B: ocean state, C: atmospheric state, D: repeat)

# TAMS Parameters
nc=7  #number of LEVES -thus less than traj- discarded at each iteration. 

targetstate=18 #Sv

# Refine experiment name
expname=${expname/VARNAME/${varname}}

# Parameters controlling cores used by PLASIM in each run
nparallel=1 # cores usati da PLASIM. with nparallel=2 there are memory problems, now fixed at 8, try 4 one day.
#
# Directory names
scriptdir=`pwd`
homedir='/nethome/cini0001/PLASIM-TAMS'
modeldir=${homedir}/plasim/run # cartella con eseguibili di PLASIM compilato per processori con namelist etc
modelname=`printf 'most_plasim_t21_l10_p%d.x' ${nparallel}` # nome eseguibile
# 
# Parameters controlling dubug
debug=0
#
# Restart file info (if new experiment)
sourcerestdir=/nethome/cini0001/PLASIM-TAMS/restart/
plasimrestname=l207_REST.${resty}
lsgrestname=l207_LSGREST.${resty}
#
# EXPERIMENT SPECIFIC FLAGS
# Ocean Configuration
diffusion=Angeloni

##############################################################################

# prepare plasim_namelist
KR=1
sed  -e "s/LYear/${LYear}/" -e "s/NMonths/${NMonths}/" -e "s/NDays/${NDays}/" -e "s/kickres/${KR}/" \
     plasim_namelist0 > ${modeldir}/plasim_namelist

# prepare ocean namelist
cp ${modeldir}/input_${diffusion} ${modeldir}/input

# determine dt parameter for resamplying
TotDaysBlock=$((${NDays}+${NMonths}*30))
NBlocks=$((${endblock}-${initblock}+1))

# update expname to include parameter setting
expname=${expname}_ntraj${ntrajs}_nc${ns}_targetstate${targetstate}_LBlock${TotDaysBlock}_p${nparallel}_startID${startID}
echo ${homedir}/${expname}
if [[ -d ${homedir}/${expname} && ${force} -eq 1 && ${newexperiment} -eq 1 ]]; then
    rm -rf ${homedir}/${expname}
fi


#note that the number of tasks must be chosen so that SLURM_NTASKS/NPARALLEL is an integer
ntrajsperbatch=$((${SLURM_NTASKS}/${nparallel})) # quante traiettorie ogni batch (diverso da batch sul filename che si riferisce a pool condizioni iniziali)
nbatches=$((${ntrajs}/${ntrajsperbatch})) # numero volte che devi integrare per finare # members
ntrajrest=$((${ntrajs}-(${nbatches}*${ntrajsperbatch}))) # traiettorie in ultimo batch

if [ ${ntrajrest} -gt 0 ]; then nbatches=$(( ${nbatches}+1 )); fi
mem=0

## nomi di scripts dentro 
launchname=`printf 'run_large_dev_%s' ${expname}`   # launchname è se stesso (after reneame)
createinitname='create_initial_conditions_simple' # scripts che definisce condizioni iniziale dell'ensemble 
organizename='organize_output_tams' # organizza traiettorie al termine di ogni block
extractname='extract_score_tams' # estrae score



# define experiment folders 
expdir=`printf '%s/%s' ${homedir} ${expname}`
runexpdir=`printf '%s/run' ${expdir}`   # numero di cartelle per ogni run parallelo. Qui girano le traiettorie 
dataexpdir=`printf '%s/data' ${expdir}` # output del modello
restexpdir=`printf '%s/rest' ${expdir}` # restart stessi a fine run
initexpdir=`printf '%s/init' ${expdir}` # estart dopo resampling: resampling mischi i restart files
diagexpdir=`printf '%s/diag' ${expdir}` # diagnostiche di PLASIM
postexpdir=`printf '%s/post' ${expdir}` # all'inizio nulla 
resamplingexpdir=`printf '%s/resampling' ${expdir}` # informazioni su come è stato fatto il resampling: contiene file python con info
scriptsexpdir=`printf '%s/scripts' ${expdir}` # 
modelexpdir=`printf '%s/model' ${expdir}` #  directory d orifine del modello, che però viene fatto girre su runexpdir

#NOW  manage output files
block=8
endblock=10
while [ ${block} -le ${endblock} ]
do 
 

  blocklabel=`printf 'block_%04d' ${block}`
  blocknumber=`printf '%04d' ${block}`

## postprocess to netcdf ##
  mkdir -p ${expdir}/data/${blocklabel}/netcdf/
  for a in `ls ${expdir}/data/${blocklabel}/*.${blocknumber}`; do 
      fname=`echo $a | rev | cut -d / -f 1 | rev`
      ${homedir}/scripts/srv2nc -m -p ${a} ${expdir}/data/${blocklabel}/netcdf/${fname}.nc & 
  done
  wait

  ## tar files according to flag light
  if [ ${light} -eq 1 ]; then
       echo "ligh mode on"
     ${scriptdir}/postpro_light.sh ${expdir} ${expname} ${blocklabel} ${block} ${ntrajs}
  else
      echo "light mode off"
       tar -cf ${expdir}/diag/${expname}_diag_${blocklabel}.tar -C ${expdir}/diag/${blocklabel} .
       rm ${expdir}/diag/${blocklabel}/*
       tar -cf ${expdir}/resampling/${expname}_resampling_${blocklabel}.tar -C ${expdir}/resampling/${blocklabel} .
       rm ${expdir}/resampling/${blocklabel}/*
       tar -cf ${expdir}/init/${expname}_init_${blocklabel}.tar -C ${expdir}/init/${blocklabel} .
       rm ${expdir}/init/${blocklabel}/*
       tar -cf ${expdir}/rest/${expname}_rest_${blocklabel}.tar -C ${expdir}/rest/${blocklabel} .
       rm ${expdir}/rest/${blocklabel}/*
       tar -cf ${expdir}/data/${expname}_data_${blocklabel}.tar -C ${expdir}/data/${blocklabel}/netcdf/ .
       rm ${expdir}/data/${blocklabel}/*.${blocknumber}
       rm ${expdir}/data/${blocklabel}/netcdf/*
  fi


  
  blocknumber=`printf '%04d' ${block}`
  cd ${expdir}/post/ctrlobs
  if [ $domain == DIAG ]; then
      tar cf ${expname}_ctrlobs_${blocklabel}.tar ${expname}_ctrlobs.*.${blocknumber}.txt
      rm ${expname}_ctrlobs.*.${blocknumber}.txt
      tar cf ${expname}_score_${blocklabel}.tar ${expname}_score.*.${blocknumber}.txt
      rm ${expname}_score.*.${blocknumber}.txt
  else
      tar cf ${expname}_ctrlobs_${blocklabel}.tar ${expname}_ctrlobs.*.${blocknumber}.nc
      rm ${expname}_ctrlobs.*.${blocknumber}.nc
      tar cf ${expname}_score_${blocklabel}.tar ${expname}_score.*.${blocknumber}.nc
      rm ${expname}_score.*.${blocknumber}.nc
#MC I guess the following is not at all necessary
      tar cf ${expname}_burn_ctrlobs_log_${blocklabel}.tar ${expname}_burn_ctrlobs.*.${blocknumber}.log
      rm ${expname}_burn_ctrlobs.*.${blocknumber}.log
  fi


block=$((block + 1))

done
mv ${scriptdir}/log_him.%j.o ${expdir}/. ## COPIA FILE LOG DENTRO CARTELLA ESPERIMENTO
mv ${scriptdir}/log_him.%j.o ${expdir}/.
## EXPERIMENT COMPLETED




exit 0

