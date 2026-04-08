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
simulationName="sampleSimulations"

# you probably don't want to change these unless you're making your own versions of the model (if so, cool!)
attProbsType="model13Version"     # How to calculate attitude update probabilities 
behavProbsType="model13Version"   # How to calculate behavior update probabilities 
λBAdirectionType="lastBehavior"   # how to calculate the direction of λ (see supplemental material for notes on this)
socialInfluenceType="mean"        # how to calculate S
historyDependenceType="mean"      # how to calculate H


# to reproduce figures from the paper, set whichSim to one of the options below. To set your own
# parameter sweeps, set whichSim = "freestyle" and edit the values in the if whichSim == "freestyle"
# section below accordingly.


for whichSim in ["beta vs alpha low res"]
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
    
    elseif whichSim == "Null + alpha with lambda 0.75"
        αrange = range(-0.2,0.2,step=0.005)
        βrange = 0.0
        λrange = [0.75]
        repetitions=50
            
    elseif whichSim == "beta vs lambda low res"
        # Fig. 3B-C (αrange = [0.0])
        # Fig. 5B-E (αrange = [-0.1],αrange = [0.0], αrange = [0.1], αrange = [0.2])
        αrange = [-0.5]
        βrange = range(-0.3,0.3,step=0.02)
        λrange = range(0.0,1.0,step=0.02)
        repetitions=25
    
    elseif whichSim == "alpha vs lambda low res"
        # Fig. S10B-C
        αrange = range(-0.2,0.2,step=0.02)
        βrange = [0.0]
        λrange = range(0.0,1.0,step=0.02)
        repetitions=25
    
    elseif whichSim == "beta vs alpha low res"
        # Fig. 5F-G (λrange = [0.1], λrange = [0.9])
        αrange = range(-0.5,0.5,step=0.05)
        βrange = range(-0.5,0.5,step=0.05)
        λrange = [1.0]
        repetitions=25
    
    elseif whichSim == "beta vs lambda high res"
        # Fig. 3B-C (αrange = [0.0])
        # Fig. 5B-E (αrange = [-0.1],αrange = [0.0], αrange = [0.1], αrange = [0.2])
        αrange = [0.0]
        βrange = range(-0.3,0.3,step=0.001)
        λrange = range(0.0,1.0,step=0.005)
        repetitions=50
    
    elseif whichSim == "beta vs alpha high res"
        # Fig. 5F-G (λrange = [0.1], λrange = [0.9])
        αrange = range(-0.5,0.5,step=0.01)
        βrange = range(-0.5,0.5,step=0.01)
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
    #     ββ = βrange[idx]
    #     bb = 1
    #     # (and delete "(bb,ββ) in enumerate(βrange)" from the for loop below)
    #
    # NOTE that care must be taken when re-assembling these matrices for plotting 
    # since parallizing across parameter values will result in several small compressed 
    # simulation file which will need to be pieced together into a single matrix for plotting
    #
    # On a personal computer or single core, the full parameter sweep can be run
    # by looping over all indices (see below).
    #
    # WARNING: High-resolution parameter sweeps can be computationally expensive
    # and may take several hours to complete on a single core.
    #
    # For quick testing, consider reducing:
    # - number of parameter values
    # - number of repetitions per parameter set
    # - simulation length
    
    # initialize arrays
    behavMeansAll = zeros(length(αrange),length(βrange),length(λrange),2501,repetitions,2)
    attMeansAll = zeros(length(αrange),length(βrange),length(λrange),2501,repetitions,2)
    
    for (ss,startingConditions) in enumerate(["allnegative","allpositive"]), (aa,αα) in enumerate(αrange), (ll,λλ) in enumerate(λrange), (bb,ββ) in enumerate(βrange)
    
        if startingConditions == "allnegative"
            simulationNameFull = "$(simulationName)_allNegative"
        elseif startingConditions == "allpositive"
            simulationNameFull = "$(simulationName)_allPositive"
        end
    
        paramStr=getParamString(N,M,rates,λλ,λλ,ββ,αα,err,networkType,trackerType,attProbsType,λBAdirectionType,socialInfluenceType,behavProbsType,historyDependenceType,timelimit)
        jld_path = "../simulations/$simulationNameFull/$paramStr/all_reps.jld2"
        
        # save each repetition
        for rr = range(1,repetitions,step=1)
    
            retrySim =false      
            pop = nothing
            
            try
                f = jldopen(jld_path, "r")
                if haskey(f, "pop_$rr")
                    pop = f["pop_$rr"]
                else
                    println("\nMissing rep $rr at $jld_path.")
                    retrySim = true
                end
                close(f)
            catch e
                println("\nCorrupted rep $rr at $jld_path. Error: $e")
                rm(jld_path; force=true)
                retrySim = true
            end
            
            if retrySim || pop === nothing
                error("should re-run: $jld_path  repetition: pop_$rr")
            end
            
            behavMeansAll[aa,bb,ll,:,rr,ss] = pop.tracker.behavMean[1:2501]
            attMeansAll[aa,bb,ll,:,rr,ss] = pop.tracker.attMean[1:2501]
        end
    end
    
    titleStr = "../simulations/compressedSims/$simulationName/behavMeansAll α = $αrange , β = $βrange , λ = $λrange .jld"
    save(titleStr,"behavMeansAll", behavMeansAll)
    titleStr = "../simulations/compressedSims/$simulationName/attMeansAll α = $αrange , β = $βrange , λ = $λrange .jld"
    save(titleStr,"attMeansAll", attMeansAll)
    
    println("saved α = $αrange , β = $βrange , λ = $λrange ")
    
    print("done $simulationName")
end
