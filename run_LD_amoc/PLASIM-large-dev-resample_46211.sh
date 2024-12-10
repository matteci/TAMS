#!/bin/sh

#SBATCH -J PLASIM-large-dev-resample_%j
#SBATCH --time=00:10:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --output=PLASIM-large-dev-resample_%j.log
#SBATCH --error=PLASIM-large-dev-resample_%j.log 
#SBATCH --partition=batch

source $HOME/my_venv/bin/activate
#module load scipy
v
cd /nethome/cini0001/PLASIM-TAMS/PLASIM_LSG_CO2-master/AMOC_LD_amoc_pos_ntraj20_k0_LBlock360_p1_startIDl207-y2480_r2/resampling/
for a in `ls *.tar`; do
    tar -xvf $a
done

#cat *.tar | tar xvf

cd /nethome/cini0001/PLASIM-TAMS/run_LD_amoc/
echo '*******'
echo 'Begin reconstruct.py'
python -t reconstruct.py  /nethome/cini0001/PLASIM-TAMS/PLASIM_LSG_CO2-master/AMOC_LD_amoc_pos_ntraj20_k0_LBlock360_p1_startIDl207-y2480_r2 AMOC_LD_amoc_pos_ntraj20_k0_LBlock360_p1_startIDl207-y2480_r2 20 0 1 5

#echo '*******'
#echo 'Begin reconstruct_var_V2.py'
#python -t reconstruct_var_V2.py  /nethome/cini0001/PLASIM-TAMS/PLASIM_LSG_CO2-master/AMOC_LD_amoc_pos_ntraj20_k0_LBlock360_p1_startIDl207-y2480_r2 AMOC_LD_amoc_pos_ntraj20_k0_LBlock360_p1_startIDl207-y2480_r2 20 1 5

echo '*******'
rm /nethome/cini0001/PLASIM-TAMS/PLASIM_LSG_CO2-master/AMOC_LD_amoc_pos_ntraj20_k0_LBlock360_p1_startIDl207-y2480_r2/resampling/*_resampling.????.npz # tar files are kept
mv /nethome/cini0001/PLASIM-TAMS/run_LD_amoc/PLASIM-large-dev-resample_${SLURM_JOB_ID}.log /nethome/cini0001/PLASIM-TAMS/PLASIM_LSG_CO2-master/AMOC_LD_amoc_pos_ntraj20_k0_LBlock360_p1_startIDl207-y2480_r2/. ## COPIA FILE LOG DENTRO CARTELLA ESPERIMENTO
mv /nethome/cini0001/PLASIM-TAMS/run_LD_amoc/PLASIM-large-dev-resample_46211.sh /nethome/cini0001/PLASIM-TAMS/PLASIM_LSG_CO2-master/AMOC_LD_amoc_pos_ntraj20_k0_LBlock360_p1_startIDl207-y2480_r2/scripts/PLASIM-large-dev-resample_${SLURM_JOB_ID}.sh

exit 0
