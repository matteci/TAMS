#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Feb 27 2024

@author: valerian

Modified on Wed Oct 9 2024 
@author: matteo  (MC)
"""

import numpy as np
import sys
from shutil import copy
import os
import math
from netCDF4 import Dataset

# read input
script=sys.argv[0]
expdir=sys.argv[1]
expname=sys.argv[2]
ntrajs=int(sys.argv[3])
varname=sys.argv[4]
nc=float(sys.argv[5])
endblock=float(sys.argv[6])
kt=float(sys.argv[7])
wp=float(sys.argv[8])


# define folders as in main script (many are not actually needed)
runexpdir=expdir+'/run'
dataexpdir=expdir+'/data'
restexpdir=expdir+'/rest'
initexpdir=expdir+'/init'
diagexpdir=expdir+'/diag'
postexpdir=expdir+'/post'
resamplingexpdir=expdir+'/resampling'
scriptsexpdir=expdir+'/scripts'
modelexpdir=expdir+'/model'
burnerexpdir=expdir+'/burner'


        
# Initialization of the trajectories and scores
score=np.empty(ntrajs,endblock)
for block in range(endblock):
	traj=0
	for traj in range(ntrajs):
    		datafilename=expname+'_ctrlobs.'+str(traj+1).zfill(4)+'.'+str(block+1).zfill(4)+'.txt'
    		dataset=postexpdir+'/ctrlobs/'+datafilename
    		with open(dataset) as f:
        		score[traj,block] = f.readline()
        		#print(obsmean[traj,block])


    
# Compute the maximum score for each trajectory
Q = np.nanmax(score,axis=1) #qui da capire come funzioni questo score, dovrebbe essere funzione di tempo delle traiettorie e traiettoria (i,t)
print("Q:",Q)
# Loop until the number of unique values of Q is less than the number of discarded levels

# Find the threshold value: the nc-th largest value of Q
threshold = np.unique(Q)[nc-1] #Because Python counts from 0
idx, other_idx = np.flatnonzero(Q<=threshold), np.flatnonzero(Q>threshold)
Q_min = Q[idx]

#Update weights
wp *= (1-len(idx)/ntraj)
# Create new trajectories
# restart is the first timestep where the score of the chosen trajectory is above the threshold of the discarded one
new_ind =np.random.choice(other_idx, size=len(idx))
restart = np.nanargmax(score[new_ind]>=Q_min[:,np.newaxis], axis=1) #first occurence of max (i.e. True)


# Update the trajectories and scores
for i in range(len(idx)):
	t, r, l = idx[i], restart[i]
	for b in range(r):
                blockdir = f"block_{b:04d}"

		dataname = f"{expname}_data.{t:04d}.{b+1:04d}"
		icename = f"{expname}_ice.{t:04d}.{b+1:04d}"
		oceanname = f"{expname}_ocean.{t:04d}.{b+1:04d}"
		lsgname = f"{expname}_lsg.{t:04d}.{b+1:04d}"
		diagname = f"{expname}_diag.{t:04d}.{b+1:04d}"
		restname = f"{expname}_rest.{t:04d}.{b+1:04d}"
		lsgrestname = f"{expname}_lsgrest.{t:04d}.{b+1:04d}"

                newdataname = f"{expname}_data.{new_ind[i]:04d}.{b+1:04d}"
                newicename = f"{expname}_ice.{new_ind[i]:04d}.{b+1:04d}"
                newoceanname = f"{expname}_ocean.{new_ind[i]:04d}.{b+1:04d}"
                newlsgname = f"{expname}_lsg.{new_ind[i]:04d}.{b+1:04d}"
                newdiagname = f"{expname}_diag.{new_ind[i]:04d}.{b+1:04d}"
                newrestname = f"{expname}_rest.{new_ind[i]:04d}.{b+1:04d}"
                newlsgrestname = f"{expname}_lsgrest.{new_ind[i]:04d}.{b+1:04d}"
                #here copies restart files
		initfilename=expname+'_init.'+str(t).zfill(4)+'.'+str(b+1).zfill(4)
    		restfilename=expname+'_rest.'+str(new_ind[i]).zfill(4)+'.'+str(b+1).zfill(4)
    		copy(restexpdir+'/block_'+str(b+1).zfill(4)+'/'+restfilename,initexpdir+'/block_'+str(b+1).zfill(4)+'/'+initfilename)

		lsginitfilename=expname+'_lsginit.'+str(t).zfill(4)+'.'+str(b+1).zfill(4)
    		lsgrestfilename=expname+'_lsgrest.'+str(new_ind[i]).zfill(4)+'.'+str(b+1).zfill(4)
    		copy(restexpdir+'/block_'+str(b+1).zfill(4)+'/'+lsgrestfilename,initexpdir+'/block_'+str(b+1).zfill(4)+'/'+lsginitfilename)
                #here copies outputfiles
                os.rename(f"{dataexpdir}/{blockdir}/{newdataname}", f"{dataexpdir}/{blockdir}/{dataname}")
		os.rename(f"{dataexpdir}/{blockdir}/{newicename}", f"{dataexpdir}/{blockdir}/{icename}")
		os.rename(f"{dataexpdir}/{blockdir}/{newoceanname}", f"{dataexpdir}/{blockdir}/{oceanname}")
		os.rename(f"{dataexpdir}/{blockdir}/{newlsgname}", f"{dataexpdir}/{blockdir}/{lsgname}")
		os.rename(f"{diagexpdir}/{blockdir}/{newdiagname}", f"{diagexpdir}/{blockdir}/{diagname}")
		os.rename(f"{restexpdir}/{blockdir}/{newrestname}", f"{restexpdir}/{blockdir}/{restname}")
		os.rename(f"{restexpdir}/{blockdir}/{newlsgrestname}", f"{restexpdir}/{blockdir}/{lsgrestname}")
	
	for b in range(r,endblock+1):
		initfilename=expname+'_init.'+str(t).zfill(4)+'.'+str(b+1).zfill(4)
		lsginitfilename=expname+'_lsginit.'+str(t).zfill(4)+'.'+str(b+1).zfill(4)
		blockdir = f"block_{b:04d}"
                dataname = f"{expname}_data.{t:04d}.{b+1:04d}"
                icename = f"{expname}_ice.{t:04d}.{b+1:04d}"
                oceanname = f"{expname}_ocean.{t:04d}.{b+1:04d}"
                lsgname = f"{expname}_lsg.{t:04d}.{b+1:04d}"
                diagname = f"{expname}_diag.{t:04d}.{b+1:04d}"
                restname = f"{expname}_rest.{t:04d}.{b+1:04d}"
                lsgrestname = f"{expname}_lsgrest.{t:04d}.{b+1:04d}"
	
		os.remove(f"{dataexpdir}/{blockdir}/{dataname}")
		os.remove(f"{dataexpdir}/{blockdir}/{icename}")  
		os.remove(f"{dataexpdir}/{blockdir}/{oceanname}")  	
		os.remove(f"{dataexpdir}/{blockdir}/{lsgname}")
		os.remove(f"{diagexpdir}/{blockdir}/{diagname}") 
		os.remove(f"{restexpdir}/{blockdir}/{restname}") 
		os.remove(f"{restexpdir}/{blockdir}/{lsgrestname}")
		os.remove(f"{initexpdir}/{blockdir}/{initfilename}") 
		os.remove(f"{initexpdir}/{blockdir}/{lsginitfilename}")   
		
	initfilename=expname+'_init.'+str(t).zfill(4)+'.'+str(r+1).zfill(4)
        restfilename=expname+'_rest.'+str(new_ind[i]).zfill(4)+'.'+str(r).zfill(4)
        copy(restexpdir+'/block_'+str(r).zfill(4)+'/'+restfilename,initexpdir+'/block_'+str(r+1).zfill(4)+'/'+initfilename)

        lsginitfilename=expname+'_lsginit.'+str(t).zfill(4)+'.'+str(r+1).zfill(4)
        lsgrestfilename=expname+'_lsgrest.'+str(new_ind[i]).zfill(4)+'.'+str(r).zfill(4)
        copy(restexpdir+'/block_'+str(r).zfill(4)+'/'+lsgrestfilename,initexpdir+'/block_'+str(r+1).zfill(4)+'/'+lsginitfilename)
	copy(restexpdir+'/block_'+str(r).zfill(4)+'/kleiswi',initexpdir+'/block_'+str(r+1).zfill(4)+'/kleiswi')
        copy(restexpdir+'/block_'+str(r).zfill(4)+'/mat77',initexpdir+'/block_'+str(r+1).zfill(4)+'/mat77')
	
	
		



# Convert the array to a space-separated string
oldind_str = ' '.join(map(str, idx))
restart_str = ' '.join(map(str, restart))
Nf=np.count_nonzero(Q>=1)
levels=len(np.unique(Q))

np.savez(resamplingexpdir+'/block_'+str(block).zfill(4)+'/'+expname+'_resampling.'+str(block).zfill(4),\
         ntrajs=ntrajs,nc=nc,obsmean=obsmean,score=score,oldind_str=oldinf_str,restart_str=restart_str,levels=levels,wp=wp,Nf=Nf)

print(f"oldind_ARRAY {oldind_str}")
print(f"restart_ARRAY {restart_str}")
print(f"Levels {levels}")
print(f"Levels {wp}")
print(f"Successful trajectories {Nf}")

return 0




