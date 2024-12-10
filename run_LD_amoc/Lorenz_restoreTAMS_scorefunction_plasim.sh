#!/bin/bash -l
#
#SBATCH -J restoreTAMS              # the name of your job   
#SBATCH -p normal            # request the short partition, job takes less than 3 hours  
#SBATCH -t 01-00:00:00          # time in dd-hh:mm:ss you want to reserve for the job
#SBATCH -n 26               # the number of cores you want to use for the job, SLURM automatically determines how many nodes are needed
#SBATCH -o log_restams.%j.o     # the name of the file where the standard output will be written to. %j will be the jobid determined by SLURM
#SBATCH -e log_restams.%j.o     # the name of the file where potential errors will be written to. %j will be the jobid determined by SLURM

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
resty=0350
initblock=1        # block è periodo lungo come resampling. 
endblock=150        # ultimo blocco: ti definisce lunghezza integrazione
rn=2              # simulation number

# Parameters controlling resampling, observable and weights
varname='amoc'    #variabile usata per resampling
domain='DIAG'     # domain in PLASIM output of varname

resamplingname='TAMS_Matteo.py'   # file che fa il resampling
ntrajs=256
NMonths=12     # length resampling block
NDays=0      # length resampling block
LYear=360     # 
startID=l207-y${resty}_r${rn}  # 0BCD (B: ocean state, C: atmospheric state, D: repeat)

#CO2
co2=600 #not really updated here, just an indication

# TAMS Parameters
nc=26  #number of LEVES -thus less than traj- discarded at each iteration. 
targetstate=9.4 #Sv
Ktmax=20 #number of max iteration before stopping. This is due only to sbatch capcity. NB: next time you re-run you have to change starting prob!
wp=0.10824027340530842 #starting prob
ktinit=17 #starting iteration of Tams, first iter =0
# Refine experiment name
expname=${expname/VARNAME/${varname}}

# Parameters controlling cores used by PLASIM in each run
nparallel=1 # cores usati da PLASIM. with nparallel=2 there are memory problems, now fixed at 8, try 4 one day.
#
# Directory names
scriptdir=`pwd`
scriptdir=`pwd`
homedir='/nethome/cini0001/PLASIM-TAMS/scorefunction'
modeldir=/nethome/cini0001/PLASIM-TAMS/plasim/run # cartella con eseguibili di PLASIM compilato per processori con namelist etc
modelname=`printf 'most_plasim_t21_l10_p%d.x' ${nparallel}` # nome eseguibile
# 
# Parameters controlling dubug
debug=0

#Parameters controlling directory and size
force=0           # sovrascrittura delle cartelle di output
light=1           # light postprocessing as defined in postpro_light.sh


# Restart file info (if new experiment)
sourcerestdir=/nethome/cini0001/PLASIM-TAMS/restart/
plasimrestname=l207_REST.${resty}
lsgrestname=l207_LSGREST.${resty}
#
# EXPERIMENT SPECIFIC FLAGS
# Ocean Configuration
diffusion=Angeloni

##############################################################################

echo "tasks"
echo ${SLURM_NTASKS}
echo "mem-per-cpu"
echo ${SLURM_MEM_PER_CPU}

###### INITIALISATION ############
# prepare plasim_namelist
KR=1
sed  -e "s/LYear/${LYear}/" -e "s/NMonths/${NMonths}/" -e "s/NDays/${NDays}/" -e "s/kickres/${KR}/" \
     plasim_namelist0 > ${modeldir}/plasim_namelist

sed  -e "s/co2/${co2}/" \
     radmod_namelist0 > ${modeldir}/radmod_namelist
# prepare ocean namelist
cp ${modeldir}/input_${diffusion} ${modeldir}/input

# determine dt parameter for resamplying
TotDaysBlock=$((${NDays}+${NMonths}*30))
NBlocks=$((${endblock}-${initblock}+1))

# update expname to include parameter setting
expname=${expname}_ntraj${ntrajs}_LBlock${TotDaysBlock}_p${nparallel}_startID${startID}_${co2}ppm
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


# if this is a brand new simulation, create folders
if [ ${newexperiment} -eq 1 ] 
then
  # start creating folder structure
  echo "$(date +"%Y-%m-%d %T") started creating folders"
  # create mother folders
  mkdir -p ${expdir}
  mkdir -p ${runexpdir}
  mkdir -p ${dataexpdir}
  mkdir -p ${restexpdir}
  mkdir -p ${initexpdir}
  mkdir -p ${diagexpdir}
  mkdir -p ${postexpdir}
  mkdir -p ${postexpdir}/ctrlobs
  mkdir -p ${postexpdir}/utils
  mkdir -p ${resamplingexpdir}
  mkdir -p ${scriptsexpdir}
  mkdir -p ${modelexpdir}
#  mkdir -p ${burnerexpdir}
  # copy stuff in experiment folder
  cp ${scriptdir}/${nameThisFile}.sh ${scriptsexpdir}/${launchname}
  cp ${scriptdir}/${createinitname} ${scriptsexpdir}/${createinitname}
  cp ${scriptdir}/${organizename} ${scriptsexpdir}/${organizename}
  cp ${scriptdir}/${extractname} ${scriptsexpdir}/${extractname}
  cp ${scriptdir}/${resamplingname} ${scriptsexpdir}/${resamplingname}
  find ${modeldir} -maxdepth 1 -type f | xargs -I {} cp {} ${modelexpdir}/.  #alternative way to copy only files arguments. If it doesen't work go back to previous line, the following
  # cp ${modeldir}/* ${modelexpdir}/.
  
 # cp ${homedir}/data/${maskname} ${postexpdir}/utils/${maskname}     # mask
 # cp ${homedir}/data/${gpareaname} ${postexpdir}/utils/${gpareaname} # aree
  # handle burner stuff
#  cp ${burnerdir}/${burnername} ${burnerexpdir}/${burnername}
#  cp ${namelistfolder}/${namelistname} ${burnerexpdir}/${namelistname}
  # create run folders for each trajectory per batch
  traj=1
  while [ ${traj} -le ${ntrajs} ]
  do
    runtrajdir=`printf 'run_%04d' ${traj}` 
    mkdir -p ${runexpdir}/${runtrajdir}
    find ${modeldir} -maxdepth 1 -type f | xargs -I {} cp {} ${runexpdir}/${runtrajdir}/. #alternative way to copy only files arguments. If it doesen't work go back to previous line, the following
    #cp ${modeldir}/* ${runexpdir}/${runtrajdir}/.
    traj=`expr ${traj} + 1`
  done
else
# copy stuff in experiment folder
  cp ${scriptdir}/${nameThisFile}.sh ${scriptsexpdir}/${launchname}
  cp ${scriptdir}/${createinitname} ${scriptsexpdir}/${createinitname}
  cp ${scriptdir}/${organizename} ${scriptsexpdir}/${organizename}
  cp ${scriptdir}/${extractname} ${scriptsexpdir}/${extractname}
  cp ${scriptdir}/${resamplingname} ${scriptsexpdir}/${resamplingname}
fi

# create folders for all blocks, plus the one after the last one (to store the init files)
if [ ${newexperiment} -eq 1 ] 
then 
  block=${initblock}
else
  block=`expr ${initblock} + 1`
fi
nextendblock=`expr ${endblock} + 1`
while [ ${block} -le ${nextendblock} ]
do
  # create folders for current block
  blockdir=`printf 'block_%04d' ${block}`
  mkdir -p ${dataexpdir}/${blockdir}
  mkdir -p ${initexpdir}/${blockdir}
  mkdir -p ${restexpdir}/${blockdir}
  mkdir -p ${diagexpdir}/${blockdir}
  mkdir -p ${resamplingexpdir}/${blockdir}
  block=`expr ${block} + 1`
done
echo "$(date +"%Y-%m-%d %T") finished creating folders"
# finished creating folder structure

# move to the scripts folders
cd ${scriptsexpdir}

# ### FIX INITIAL CONDITION ### 
 # if this is a brand new simulation, copy the initial conditions for the first block (here include some spinup if needed)
if [ ${newexperiment} -eq 1 ]
then
    batch=1
    trajinit=1
    trajend=${ntrajs}
    ./${createinitname} ${sourcerestdir} ${plasimrestname} ${lsgrestname} ${expdir} ${expname} ${trajinit} ${trajend} ${initblock}
fi
####### END INITIALISATION #############################

####### RUN SIMULATIONS: STARTING SET  ###############################
#  This if one wants to skip inital phase
if [ ${newexperiment} -eq 0 ]; then
    # Jump to specific label
    echo "Skipped starting set, jumped to TAMS core!"


else
####################################
# start loop on time blocks

block=${initblock}
while [ ${block} -le ${endblock} ]
do
  blockdir=`printf 'block_%04d' ${block}`
  echo "$(date +"%Y-%m-%d %T") started running block ${block}"

  # start loop on batches of trajectories
  batch=1
  while [ ${batch} -le ${nbatches} ]  
  do
    # run the trajectories in the current batch
    echo "$(date +"%Y-%m-%d %T") started running batch ${batch} of block ${block}"
    traj=`expr ${batch} - 1`; traj=`expr ${traj} \* ${ntrajsperbatch}`; traj=`expr ${traj} + 1`
    if [ ${batch} -lt ${nbatches}  ]
    then
      endtraj=`expr ${batch} \* ${ntrajsperbatch}`
    else
      endtraj=${ntrajs}
    fi
    while [ ${traj} -le ${endtraj} ]
    do  
      initname=`printf '%s_init.%04d.%04d' ${expname} ${traj} ${block}` # file init per traiettoria che fai girare
      lsginitname=`printf '%s_lsginit.%04d.%04d' ${expname} ${traj} ${block}` # file init per traiettoria che fai girare
      trajrun=`expr ${batch} - 1`; trajrun=`expr ${trajrun} \* ${ntrajsperbatch}`; trajrun=`expr ${traj} - ${trajrun}`; #MC this is the trajectory number in each batch
      runtrajdir=`printf 'run_%04d' ${trajrun}`
      cp ${initexpdir}/${blockdir}/${initname} ${runexpdir}/${runtrajdir}/plasim_restart # impostalo come restart
      cp ${initexpdir}/${blockdir}/${lsginitname} ${runexpdir}/${runtrajdir}/kleiin1     # impostalo come restart
      cd ${runexpdir}/${runtrajdir}
#      srun --mpi=pmi2 -K1 --resv-ports --exclusive --nodes=1 --ntasks=${nparallel} --mem=${mem} ${modelname} & # fai partire modello
      ./${modelname} & # fai partire modello

      if [ ${debug} -eq 1 ]; then echo "$(date +"%Y-%m-%d %T") started traj ${traj}"; fi
      traj=`expr ${traj} + 1`
    done
    wait
    echo "$(date +"%Y-%m-%d %T") finished running batch ${batch} of block ${block}"
    # all the runs in the current batch are completed 
    cd ${scriptsexpdir}

    # organize the output
    echo "$(date +"%Y-%m-%d %T") started organizing output for batch ${batch} of block ${block}"
    traj=`expr ${batch} - 1`; traj=`expr ${traj} \* ${ntrajsperbatch}`; traj=`expr ${traj} + 1`
    if [ ${batch} -lt ${nbatches}  ]
    then
      endtraj=`expr ${batch} \* ${ntrajsperbatch}`
    else
      endtraj=${ntrajs}
    fi
    while [ ${traj} -le ${endtraj} ]
    do
      trajrun=`expr ${batch} - 1`; trajrun=`expr ${trajrun} \* ${ntrajsperbatch}`; trajrun=`expr ${traj} - ${trajrun}`;
      ./${organizename} ${expdir} ${expname} ${trajrun} ${traj} ${block} & 
      #      srun --mpi=pmi2 -K1 --resv-ports --exclusive --nodes=1 --ntasks=1 --mem=${mem} ./${organizename} ${expdir} ${expname} ${trajrun} ${traj} ${block} & # sottomette per organizzare output dei runs
      if [ ${debug} -eq 1 ]; then echo "$(date +"%Y-%m-%d %T") started organizing output of traj ${traj} of block ${block}"; fi
      traj=`expr $traj + 1`
    done
    wait
    echo "$(date +"%Y-%m-%d %T") finished organizing output for batch ${batch} of block ${block}"
    # the output of the current batch is organized

    # extract the observable used in the definition of the weights of the current batch
    echo "$(date +"%Y-%m-%d %T") started extracting control observable for batch ${batch} of block ${block}"
    traj=`expr ${batch} - 1`; traj=`expr ${traj} \* ${ntrajsperbatch}`; traj=`expr ${traj} + 1`
    if [ ${batch} -lt ${nbatches}  ]
    then
      endtraj=`expr ${batch} \* ${ntrajsperbatch}`
    else
      endtraj=${ntrajs}
    fi
    while [ ${traj} -le ${endtraj} ]
    do
	./${extractname} ${expdir} ${expname} ${traj} ${block} ${varname} ${domain} ${targetstate} & # sottomette estrazione variabile 
	#srun --mpi=pmi2 -K1 --resv-ports --exclusive --nodes=1 --ntasks=1 --mem=${mem} ./${extractname} ${expdir} ${expname} ${traj} ${block} & # sottomette estrazione variabile da osservare
      if [ ${debug} -eq 1 ]; then echo "$(date +"%Y-%m-%d %T") started extracting control observable of traj ${traj} of block ${block}"; fi
      traj=`expr $traj + 1`
    done
    wait
    echo "$(date +"%Y-%m-%d %T") finished extracting control observable for batch ${batch} of block ${block}"
    # the observable used in the definition of the weights of the current batch is extracted
    batch=`expr $batch + 1`
  done
  # end loop on batches of trajectories
  #turning off noise
  if [[ ${block} -eq 1 ]]; then
      for f in `ls ${expdir}/run/run_*/plasim_namelist`; do
          sed  -e "s/LYear/${LYear}/" -e "s/NMonths/${NMonths}/" -e "s/NDays/${NDays}/" -e "s/kickres/0/" \
               ${scriptdir}/plasim_namelist0 > ${f}
      done
  fi

  block=`expr $block + 1`
done
fi
#######FINE CALCOLO Iniziale########







#Intialization TAMS
output=$(cat log.o)

 # Extract the lines with the identifiers 
 oldind_output=$(echo "$output" | grep "oldind_ARRAY")
 restart_output=$(echo "$output" | grep "restart_ARRAY")
 levels_output=$(echo "$output" | grep "Levels")
 wp_output=$(echo "$output" | grep "Probability")
 Nf_output=$(echo "$output" | grep "Successful_traj")

 # Read the arrays into variables, ignoring the identifier part
 oldind_array=($(echo "$oldind_output" | cut -d' ' -f2-))
 restart_array=($(echo "$restart_output" | cut -d' ' -f2-))
 levels=$(echo "$levels_output" | cut -d' ' -f2-)
 wp=$(echo "$wp_output" | cut -d' ' -f2-)
 Nf=$(echo "$Nf_output"| cut -d' ' -f2-)

 # Now you can use the new values in your shell script
 #echo "Oldind array: ${oldind_array[@]}"
 #echo "Restart time array: ${restart_array[@]}"
 #echo "Levels: ${levels}"
 #echo "Probs: ${wp}"
 echo "Nf: ${Nf}"
 kt=`expr $kt + 1`
echo "##################################   ITERATION NUMBER ${kt}  #####################################"
 # Loop through each index of the arrays
for f in `ls ${expdir}/run/run_*/plasim_namelist`; do
          sed  -e "s/LYear/${LYear}/" -e "s/NMonths/${NMonths}/" -e "s/NDays/${NDays}/" -e "s/kickres/1/" \
               ${scriptdir}/plasim_namelist0 > ${f}
  done

 for i in "${!oldind_array[@]}"; do
  oldind="${oldind_array[i]}"
  restart="${restart_array[i]}"
  block=`expr $restart + 1`
  echo "$(date +"%Y-%m-%d %T") running ${oldind} traj from ${restart}"
  (
  while [ ${block} -le ${endblock} ]
  do
   blockdir=`printf 'block_%04d' ${block}`
   #echo "$(date +"%Y-%m-%d %T") started running block ${block} of traj ${oldind}"
   #MC important: here we consider 1 batch sufficient!
   # run the trajectories in the current batch
     traj=${oldind}
       initname=`printf '%s_init.%04d.%04d' ${expname} ${traj} ${block}` # file init per traiettoria che fai girare
       lsginitname=`printf '%s_lsginit.%04d.%04d' ${expname} ${traj} ${block}` # file init per traiettoria che fai girare

       

       runtrajdir=`printf 'run_%04d' ${traj}`
       cp ${initexpdir}/${blockdir}/${initname} ${runexpdir}/${runtrajdir}/plasim_restart # impostalo come restart
       cp ${initexpdir}/${blockdir}/${lsginitname} ${runexpdir}/${runtrajdir}/kleiin1     # impostalo come restart

       cd ${runexpdir}/${runtrajdir}
#      srun --mpi=pmi2 -K1 --resv-ports --exclusive --nodes=1 --ntasks=${nparallel} --mem=${mem} ${modelname} & # fai partire modello
       ./${modelname} &   # fai partire modello

      
       
     
     wait
    
     # all the runs in the current batch are completed 
     cd ${scriptsexpdir}

     # organize the output
     
      ./${organizename} ${expdir} ${expname} ${traj} ${traj} ${block} & 
      #      srun --mpi=pmi2 -K1 --resv-ports --exclusive --nodes=1 --ntasks=1 --mem=${mem} ./${organizename} ${expdir} ${expname} ${trajrun} ${traj} ${block} & # sottomette per organizzare output dei runs
      if [ ${debug} -eq 1 ]; then echo "$(date +"%Y-%m-%d %T") started organizing output of traj ${traj} of block ${block}"; fi
      
    
    wait
    
    # the output of the current batch is organized

    # extract the observable used in the definition of the weights of the current batch
    #echo "$(date +"%Y-%m-%d %T") started extracting control observable for traj ${traj} of block ${block}"
    
      	./${extractname} ${expdir} ${expname} ${traj} ${block} ${varname} ${domain} ${targetstate} & # sottomette estrazione variabile 
        #srun --mpi=pmi2 -K1 --resv-ports --exclusive --nodes=1 --ntasks=1 --mem=${mem} ./${extractname} ${expdir} ${expname} ${traj} ${block} & # sottomette estrazione variabile da osservare
      if [ ${debug} -eq 1 ]; then echo "$(date +"%Y-%m-%d %T") started extracting control observable of traj ${traj} of block ${block}"; fi
      
    
    wait
    
    # the observable used in the definition of the weights of the current batch is extracted
    
  
  if [[ ${block} -eq $(expr $restart + 1) ]]; then
    
          sed  -e "s/LYear/${LYear}/" -e "s/NMonths/${NMonths}/" -e "s/NDays/${NDays}/" -e "s/kickres/0/" \
               ${scriptdir}/plasim_namelist0 > ${expdir}/run/${runtrajdir}/plasim_namelist
      echo "$(date +"%Y-%m-%d %T") finished running block ${block} of traj ${oldind}"
  fi
  
  

  block=`expr $block + 1`
  done
 ) &

done
wait

minrest=${restart_array[0]}

for i in "${restart_array[@]}"; do
    if [[ $i -lt $minrest ]]; then
        minrest=$i
    fi
done

echo "The minimum restartvalue is $minrest"

block=`expr $minrest + 1`
while [ ${block} -le ${endblock} ]
do
  blocklabel=`printf 'block_%04d' ${block}`
  blocknumber=`printf '%04d' ${block}`

## postprocess to netcdf ##
if compgen -G "${expdir}/data/${blocklabel}/*.${blocknumber}" > /dev/null; then  
  for a in `ls ${expdir}/data/${blocklabel}/*.${blocknumber}`; do 
      fname=`echo $a | rev | cut -d / -f 1 | rev`
      (${homedir}/scripts/srv2nc -m -p ${a} ${expdir}/data/${blocklabel}/netcdf/${fname}.nc 2>>warnings.log) &
  done
  wait

  ## tar files according to flag light
    echo "light mode on"
    ${scriptdir}/tamspostpro_light_score.sh ${expdir} ${expname} ${blocklabel} ${block} ${ntrajs}
wait
 rm ${expdir}/data/${blocklabel}/*.${blocknumber}  
 mv ${expdir}/data/${blocklabel}/netcdf/* ${expdir}/data/${blocklabel}/
else
        echo "No files found in ${expdir}/data/${blocklabel} matching *.${blocknumber}, skipping."
    fi
block=`expr $block + 1`

done
wait    
done




wp=$(echo "$wp * $Nf / $ntrajs" | bc -l)

 echo "Transition prob: ${wp}"



#SIMUAZIONE FINITA



mv ${scriptdir}/log_tams.${SLURM_JOB_ID}.o ${expdir}/. ## COPIA FILE LOG DENTRO CARTELLA ESPERIMENTO

## EXPERIMENT COMPLETED




exit 0
