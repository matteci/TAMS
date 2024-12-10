#!/bin/bash -l
#
#SBATCH -J testTAMS              # the name of your job   
#SBATCH -p normal            # request the short partition, job takes less than 3 hours  
#SBATCH -t 24:00:00          # time in dd-hh:mm:ss you want to reserve for the job
#SBATCH -n 64               # the number of cores you want to use for the job, SLURM automatically determines how many nodes are needed
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
newexperiment=0     # 1: nuovo 0: esperimento che ha già calcolato il set di base  othervalues: dovrebbe non ricreare le cartelle ma ricalcolare tutti gli anni di simulazioni (comunque sconsigliato perchè il noise non riparte!
resty=0990
initblock=7	   # block è periodo lungo come resampling. 
endblock=127	   # ultimo blocco: ti definisce lunghezza integrazione
rn=2   #numero di simulazione

#Parameters controlling climate mean state
CO2=500 #at the moment not updated

# Parameters controlling resampling, observable and weights
varname='amoc'    #variabile usata per resampling
domain='DIAG'     # domain in PLASIM output of varname

resamplingname='TAMS_Matteo.py'   # file che fa il resampling
ntrajs=256
NMonths=12     # length resampling block
NDays=0      # length resampling block
LYear=360     # 
startID=l207-y${resty}_r${rn}  # 0BCD (B: ocean state, C: atmospheric state, D: repeat)

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

#Parameters controlling directories and size
force=0           # sovrascrittura delle cartelle di output
light=1           # light postprocessing as defined in postpro_light.sh

#
# Restart file info (if new experiment)
#sourcerestdir=/nethome/cini0001/PLASIM-TAMS/restart/
#plasimrestname=l207_REST.${resty}
#lsgrestname=l207_LSGREST.${resty}
#
# EXPERIMENT SPECIFIC FLAGS
# Ocean Configuration
diffusion=Angeloni

##############################################################################

# prepare ocean namelist


# determine dt parameter for resamplying
TotDaysBlock=$((${NDays}+${NMonths}*30))
NBlocks=$((${endblock}-${initblock}+1))

# update expname to include parameter setting
expname=${expname}_ntraj${ntrajs}_LBlock${TotDaysBlock}_p${nparallel}_startID${startID}_${CO2}ppm
echo ${homedir}/${expname}


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

#NOW  manage output file
cd ${scriptsexpdir}

block=${initblock}
while [ ${block} -le ${endblock} ]
do 
 

  blocklabel=`printf 'block_%04d' ${block}`
  blocknumber=`printf '%04d' ${block}`

## postprocess to netcdf ##
    

  ## tar files according to flag light
    echo "light mode on"
 mkdir -p ${expdir}/data/${blocklabel}/netcdf/
 mv ${expdir}/data/${blocklabel}/*.nc ${expdir}/data/${blocklabel}/netcdf/
    ${scriptdir}/tamspostpro_light.sh ${expdir} ${expname} ${blocklabel} ${block} ${ntrajs}
 #rm ${expdir}/data/${blocklabel}/*.${blocknumber}  
 mv ${expdir}/data/${blocklabel}/netcdf/* ${expdir}/data/${blocklabel}/

  
  

block=$((block + 1))

done
#mv ${scriptdir}/log_him.%j.o ${expdir}/. ## COPIA FILE LOG DENTRO CARTELLA ESPERIMENTO

## EXPERIMENT COMPLETED




exit 0

