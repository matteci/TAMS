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
nc=int(sys.argv[5])
endblock=int(sys.argv[6])
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
ctrlobsdir=postexpdir+'/ctrlobs'

        
# Initialization of the trajectories and scores
score=np.empty((ntrajs,endblock))
for block in range(endblock):
    for traj in range(ntrajs):
        datafilename=expname+'_score.'+str(traj+1).zfill(4)+'.'+str(block+1).zfill(4)+'.txt'
        dataset=postexpdir+'/ctrlobs/'+datafilename
        with open(dataset) as f:
            score[traj,block] = f.readline()
        		#print(obsmean[traj,block])


    
# Compute the maximum score for each trajectory
Q = np.nanmax(score,axis=1) #qui da capire come funzioni questo score, dovrebbe essere funzione di tempo delle traiettorie e traiettoria (i,t)
print("Q:", Q, flush=True)
# Loop until the number of unique values of Q is less than the number of discarded levels
if(len(np.unique(Q)) > nc):
# Find the threshold value: the nc-th largest value of Q
 threshold = np.unique(Q)[nc-1] #Because Python counts from 0
 idx, other_idx = np.flatnonzero(Q<=threshold), np.flatnonzero(Q>threshold)
 Q_min = Q[idx]

#Update weights
 wp *= (1-len(idx)/ntrajs)
# Create new trajectories
# restart is the first timestep where the score of the chosen trajectory is above the threshold of the discarded one
 new_ind =np.random.choice(other_idx, size=len(idx))
 restart = np.nanargmax(score[new_ind]>=Q_min[:,np.newaxis], axis=1) #first occurence of max (i.e. True)

 print("idx:", idx+1, flush=True)
 print("new_ind:", new_ind+1, flush=True)
 print("restart:", restart+1, flush=True)

# Update the trajectories and scores
 for i in range(len(idx)):
     t, r = idx[i]+1, restart[i]+1
    #print("idx:", idx+1, flush=True)
    #print("new_ind:", new_ind+1, flush=True)
    #print("restart:", restart+1, flush=True)
    #Here copy files
     for b in range(r):
         blockdir = f"block_{b+1:04d}"
         dataname = f"{expname}_data.{t:04d}.{b+1:04d}"
         icename = f"{expname}_ice.{t:04d}.{b+1:04d}"
         oceanname = f"{expname}_ocean.{t:04d}.{b+1:04d}"
         lsgname = f"{expname}_lsg.{t:04d}.{b+1:04d}"
         diagname = f"{expname}_diag.{t:04d}.{b+1:04d}"
         restname = f"{expname}_rest.{t:04d}.{b+1:04d}"
         lsgrestname = f"{expname}_lsgrest.{t:04d}.{b+1:04d}"
         initname = f"{expname}_init.{t:04d}.{b+1:04d}"
         lsginitname = f"{expname}_lsginit.{t:04d}.{b+1:04d}"
         ctrlobsname = f"{expname}_ctrlobs.{t:04d}.{b+1:04d}.txt"
         scorename = f"{expname}_score.{t:04d}.{b+1:04d}.txt"


         newdataname = f"{expname}_data.{new_ind[i]+1:04d}.{b+1:04d}"
         newicename = f"{expname}_ice.{new_ind[i]+1:04d}.{b+1:04d}"
         newoceanname = f"{expname}_ocean.{new_ind[i]+1:04d}.{b+1:04d}"
         newlsgname = f"{expname}_lsg.{new_ind[i]+1:04d}.{b+1:04d}"
         newdiagname = f"{expname}_diag.{new_ind[i]+1:04d}.{b+1:04d}"
         newrestname = f"{expname}_rest.{new_ind[i]+1:04d}.{b+1:04d}"
         newlsgrestname = f"{expname}_lsgrest.{new_ind[i]+1:04d}.{b+1:04d}"
         newinitname = f"{expname}_init.{new_ind[i]+1:04d}.{b+1:04d}"
         newlsginitname = f"{expname}_lsginit.{new_ind[i]+1:04d}.{b+1:04d}"
         newctrlobsname = f"{expname}_ctrlobs.{new_ind[i]+1:04d}.{b+1:04d}.txt"
         newscorename = f"{expname}_score.{new_ind[i]+1:04d}.{b+1:04d}.txt"

        
        
        
        
         copy(f"{dataexpdir}/{blockdir}/{newdataname}", f"{dataexpdir}/{blockdir}/{dataname}")
         copy(f"{dataexpdir}/{blockdir}/{newicename}", f"{dataexpdir}/{blockdir}/{icename}")
         copy(f"{dataexpdir}/{blockdir}/{newoceanname}", f"{dataexpdir}/{blockdir}/{oceanname}")
         copy(f"{dataexpdir}/{blockdir}/{newlsgname}", f"{dataexpdir}/{blockdir}/{lsgname}")
         copy(f"{diagexpdir}/{blockdir}/{newdiagname}", f"{diagexpdir}/{blockdir}/{diagname}")
         copy(f"{restexpdir}/{blockdir}/{newrestname}", f"{restexpdir}/{blockdir}/{restname}")
         copy(f"{restexpdir}/{blockdir}/{newlsgrestname}", f"{restexpdir}/{blockdir}/{lsgrestname}")
         copy(f"{initexpdir}/{blockdir}/{newinitname}", f"{initexpdir}/{blockdir}/{initname}")
         copy(f"{initexpdir}/{blockdir}/{newlsginitname}", f"{initexpdir}/{blockdir}/{lsginitname}")
         copy(f"{ctrlobsdir}/{newctrlobsname}", f"{ctrlobsdir}/{ctrlobsname}")  #these two needed only here bc extract_score overwrite files
         copy(f"{ctrlobsdir}/{newscorename}", f"{ctrlobsdir}/{scorename}")




     for b in range(r,endblock):
         initfilename=expname+'_init.'+str(t).zfill(4)+'.'+str(b+1).zfill(4)
         lsginitfilename=expname+'_lsginit.'+str(t).zfill(4)+'.'+str(b+1).zfill(4)
         blockdir = f"block_{b+1:04d}"
         dataname = f"{expname}_data.{t:04d}.{b+1:04d}"
         icename = f"{expname}_ice.{t:04d}.{b+1:04d}"
         oceanname = f"{expname}_ocean.{t:04d}.{b+1:04d}"
         lsgname = f"{expname}_lsg.{t:04d}.{b+1:04d}"
         diagname = f"{expname}_diag.{t:04d}.{b+1:04d}"
         restname = f"{expname}_rest.{t:04d}.{b+1:04d}"
         lsgrestname = f"{expname}_lsgrest.{t:04d}.{b+1:04d}"
         files_to_remove = [
             f"{dataexpdir}/{blockdir}/{dataname}",
             f"{dataexpdir}/{blockdir}/{icename}",
             f"{dataexpdir}/{blockdir}/{oceanname}",
             f"{dataexpdir}/{blockdir}/{lsgname}",
             f"{diagexpdir}/{blockdir}/{diagname}",
             f"{restexpdir}/{blockdir}/{restname}",
             f"{restexpdir}/{blockdir}/{lsgrestname}",
             f"{initexpdir}/{blockdir}/{initfilename}",
             f"{initexpdir}/{blockdir}/{lsginitfilename}"
             ]
         print(f"Removing file like: .{t:04d}.{b+1:04d} ", flush=True)
         for file_path in files_to_remove:
             if os.path.exists(file_path):
                 os.remove(file_path)
                #print(f"Removed file: {file_path}", flush=True)
            #else:
                #print(f"File not found: {file_path}", flush=True)
        
       # os.remove(f"{dataexpdir}/{blockdir}/{dataname}")
       # os.remove(f"{dataexpdir}/{blockdir}/{icename}")  
       # os.remove(f"{dataexpdir}/{blockdir}/{oceanname}")  	
       # os.remove(f"{dataexpdir}/{blockdir}/{lsgname}")
       # os.remove(f"{diagexpdir}/{blockdir}/{diagname}") 
       # os.remove(f"{restexpdir}/{blockdir}/{restname}") 
       # os.remove(f"{restexpdir}/{blockdir}/{lsgrestname}")
       # os.remove(f"{initexpdir}/{blockdir}/{initfilename}") 
       # os.remove(f"{initexpdir}/{blockdir}/{lsginitfilename}")   
	
    #here copy rest of newind into init of t at time reset
     initfilename=expname+'_init.'+str(t).zfill(4)+'.'+str(r+1).zfill(4)
     restfilename=expname+'_rest.'+str(new_ind[i]+1).zfill(4)+'.'+str(r).zfill(4)
     copy(restexpdir+'/block_'+str(r).zfill(4)+'/'+restfilename,initexpdir+'/block_'+str(r+1).zfill(4)+'/'+initfilename)

     lsginitfilename=expname+'_lsginit.'+str(t).zfill(4)+'.'+str(r+1).zfill(4)
     lsgrestfilename=expname+'_lsgrest.'+str(new_ind[i]+1).zfill(4)+'.'+str(r).zfill(4)
     copy(restexpdir+'/block_'+str(r).zfill(4)+'/'+lsgrestfilename,initexpdir+'/block_'+str(r+1).zfill(4)+'/'+lsginitfilename)
     copy(restexpdir+'/block_'+str(r).zfill(4)+'/kleiswi',initexpdir+'/block_'+str(r+1).zfill(4)+'/kleiswi')
     copy(restexpdir+'/block_'+str(r).zfill(4)+'/mat77',initexpdir+'/block_'+str(r+1).zfill(4)+'/mat77')
	
	
		



# Convert the array to a space-separated string
 idx=idx+1
 restart=restart+1
 oldind_str = ' '.join(map(str, idx))
 restart_str = ' '.join(map(str, restart))
 Nf=np.count_nonzero(Q>=1)
 levels=len(np.unique(Q))

 np.savez(resamplingexpdir+'/kt_'+str(kt).zfill(4),\
         ntrajs=ntrajs,nc=nc,score=score,oldind_str=idx,new_ind=new_ind,restart_str=restart,levels=levels,wp=wp,Nf=Nf)

 print(f"oldind_ARRAY {oldind_str}")
 print(f"restart_ARRAY {restart_str}")
 print(f"Levels {levels}")
 print(f"Probability {wp}")
 print(f"Successful_traj {Nf}")
else:
    levels=len(np.unique(Q))
    Nf=np.count_nonzero(Q>=1)
    print(f"Levels {levels}")
    print(f"Probability {wp}")
    print(f"Successful_traj {Nf}")
    
    




