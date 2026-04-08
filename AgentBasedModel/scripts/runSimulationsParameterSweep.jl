using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using AttitudeBehaviorDynamicsModel
using DelimitedFiles, FileIO, JLD2
using Statistics, Distributions

# Define your parameters here 
# Population Size
N = 100

# Behavior Memory Length (for calculating H)
M = 20

# error rate
err = 0.01

# simulation timelimit
timelimit = 50000

# social network type
networkType = "wellmixed"

# type of tracker to save simulation outputs (visual recommended to reproduce plots of the paper)
trackerType ="visual" 

# Attitude update and Behavior update rates
rates = [0.1,0.1]

# the folder where the simulations will be saved
simulationName="parameterSweeps"

#how many repetitions of each simulation do you want
repetitions=25

# you probably don't want to change these unless you're making your own versions of the model (if so, cool!)
attProbsType="model13Version"     # How to calculate attitude update probabilities 
behavProbsType="model13Version"   # How to calculate behavior update probabilities 
λBAdirectionType="lastBehavior"   # how to calculate the direction of λ (see supplemental material for notes on this)
socialInfluenceType="mean"        # how to calculate S
historyDependenceType="mean"      # how to calculate H


# to reproduce figures from the paper, set whichSim to one of the options below. To set your own
# parameter sweeps, set whichSim = "freestyle" and edit the values in the if whichSim == "freestyle"
# section below accordingly.

whichSim = "beta vs lambda low res"

# parameter ranges for the plots in the paper (all other parameters set to default values)
if whichSim == "freestyle"
    αrange = [0.0]
    βrange = [0.0]
    λrange = [0.0]

elseif whichSim == "Null + beta"
    # Fig. 2Aiii
    αrange = [0.0]
    βrange = range(-0.2,0.2,step=0.005)
    λrange = [0.0]
    repetitions=50

elseif whichSim == "Null + alpha"
    # Fig. 2Biii
    αrange = range(-0.2,0.2,step=0.005)
    βrange = [0.0]
    λrange = [0.0]
    repetitions=50

elseif whichSim == "Null + lambda"
    # Fig. 2Ciii
    αrange = [0.0]
    βrange = [0.0]
    λrange = range(0.0,1.0,step=0.01)
    repetitions=50

elseif whichSim == "Null + beta with lambda 0.75"
    # Fig. 3A
    αrange = [0.0]
    βrange = range(-0.2,0.2,step=0.005)
    λrange = [0.75]
    repetitions=50
    
elseif whichSim == "beta vs lambda low res"
    αrange = [0.0]
    βrange = range(-0.5,0.5,step=0.05)
    λrange = range(0.0,1.0,step=0.04)

elseif whichSim == "alpha vs lambda low res"
    αrange = range(-0.2,0.0,step=0.01)
    βrange = [0.0]
    λrange = range(0.0,1.0,step=0.04)

elseif whichSim == "beta vs alpha low res"
    αrange = range(-0.5,0.5,step=0.05)
    βrange = range(-0.5,0.5,step=0.05)
    λrange = [1.0]

elseif whichSim == "beta vs lambda high res"
    # Fig. 3B-C (αrange = [0.0])
    # Fig. 5B-E (αrange = [-0.1],αrange = [0.0], αrange = [0.1], αrange = [0.2])
    αrange = [0.0]
    βrange = range(-0.2,0.2,step=0.001)
    λrange = range(0.0,1.0,step=0.005)
    repetitions=50

elseif whichSim == "beta vs alpha high res"
    # Fig. 5F-G (λrange = [0.1], λrange = [0.9])
    αrange = range(-0.5,0.5,step=0.01)
    βrange = range(-0.4,0.4,step=0.01)
    λrange = [0.1]
    repetitions=50

elseif whichSim == "alpha vs lambda high res"
    # Fig. S10B-C
    αrange = range(-0.2,0.2,step=0.005)
    βrange = [0.0]
    λrange = range(0.0,1.0,step=0.02)
    repetitions=50

else
    error("need to specify whichSim to one of the options, or define your own")
end

#Generate list of parameter values by index
indices = []
for aa in αrange, bb in βrange, ll in λrange, startingConditions in  ["allnegative","allpositive"]
    push!(indices, (aa,bb,ll,startingConditions))
end

# --- Parallelization note ---
# These simulations can be parallelized across parameter values.
#
# On a computing cluster (e.g., using Slurm job arrays), each task can process
# a subset of parameter indices. For example:
#
#     idx = parse(Int, ENV["SLURM_ARRAY_TASK_ID"])
#     paramVals = indices[idx]
#
# On a personal computer or single core, the full parameter sweep can be run
# by looping over all indices (see below).
#
# WARNING: High-resolution parameter sweeps can be computationally expensive
# and may take several days to complete on a single core.
#
# For quick testing, consider reducing:
# - number of parameter values
# - number of repetitions per parameter set
# - simulation length

for paramVals in indices
    
    αα = paramVals[1]
    ββ = paramVals[2]
    λλ = paramVals[3]
    startingConditions = paramVals[4]
    
    # initialize arrays
    attitudes = Array{Float64}(undef,N)
    behaviors = Array{Float64}(undef,N,M)

    if startingConditions == "allnegative"
        #100% negative attitudes and behavior memories
        simulationNameFull = "$(simulationName)_allNegative"
        attitudes[:]  .= -1
        behaviors[:,:] .= -1

    elseif startingConditions == "allpositive"
        #100% positive attitudes and behavior memories
        simulationNameFull = "$(simulationName)_allPositive"
        attitudes[:]  .= 1
        behaviors[:,:] .= 1
    end
    
    startingPop=generatePop(N,M,rates,λλ,λλ,ββ,αα,err,networkType,attProbsType,λBAdirectionType,socialInfluenceType,behavProbsType,historyDependenceType,lowercase(trackerType),attitudes=attitudes,behaviors=behaviors)

    println("Starting α=$αα, β=$ββ, rates=$rates, λ=$λλ M=$M, aPT=$attProbsType, λDT=$λBAdirectionType, bPT=$behavProbsType, hDT=$historyDependenceType ....")
    @time simulate(repetitions,N,M,rates,λλ,λλ,ββ,αα,err,timelimit,simulationNameFull,startingPop=startingPop,attProbsType=attProbsType,λBAdirectionType=λBAdirectionType,socialInfluenceType=socialInfluenceType,behavProbsType=behavProbsType,historyDependenceType=historyDependenceType,trackFreq=Int(ceil(timelimit/2500)),trackerType=trackerType,networkType=networkType,untilFixation=false,savePop=true)
    println("...Done!")
end

print("done $simulationName")
