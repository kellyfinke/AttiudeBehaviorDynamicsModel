function update!(pop,event)
    # run the given event, which has a time, an indiviual (if an update event), and an event type (attitude update, behavior update, tracking)

    time, indv, eventType = event
    indv=Int(indv)

    #TODO remove social media update
    pop.time = time
    if eventType == 0.0
        track!(pop)
    elseif eventType == 1.0
        attitudeUpdate!(pop,indv)
    elseif eventType == 2.0
        behaviorUpdate!(pop,indv)
    else
        @warn("Event without update rule! $e")
    end
end

function track!(pop)
    # Save a snapshot of the current state of the population for later analysis

    (pop.trackerType=="visual")&&(trackVis!(pop))
    (pop.trackerType=="visualwlastalign")&&(trackViswlastalign!(pop))
    (pop.trackerType=="gif")&&(trackGif!(pop))
end

function attitudeUpdate!(pop,indv)
    # calculate probability of each new attitude
    probs = getAttitudeUpdateProbs(pop,indv)

    # assign new attitude to indv based on probability
    pop.attitudes[indv] = sample(pop.alternatives,probs)
end


function behaviorUpdate!(pop, indv)
    # calculate probability of each new behavior
    probs = getBehaviorUpdateProbs(pop,indv)

    # select new behavior based on probability
    newBehavior = sample(pop.alternatives,probs)

    # add new behavior to memory, remove oldest behavior
    pop.behaviors[indv,1:end-1] .= pop.behaviors[indv,2:end]
    pop.behaviors[indv,end] = newBehavior
end


function trackVis!(pop)
    # simple tracker for ploting mean attitiude and behavior timeseries 
    pop.tracker.attMean = cat(pop.tracker.attMean,mean(pop.attitudes),dims=1)
    pop.tracker.behavMean = cat(pop.tracker.behavMean,mean(mean(pop.behaviors)),dims=1)
    pop.tracker.times = cat(pop.tracker.times,pop.time,dims=1)
end

function trackViswlastalign!(pop)
    # tracker for ploting mean attitiude and behavior timeseries, as well as the mean most recent behavior and the mean alignment in the pop 
    pop.tracker.attMean = cat(pop.tracker.attMean,mean(pop.attitudes),dims=1)
    pop.tracker.behavMean = cat(pop.tracker.behavMean,mean(mean(pop.behaviors)),dims=1)
    pop.tracker.acLast = cat(pop.tracker.acLast,mean(pop.behaviors[:,end]),dims=1)
    pop.tracker.alignment = cat(pop.tracker.alignment,getAlignment(pop.attitudes,pop.behaviors),dims=1)
    pop.tracker.times = cat(pop.tracker.times,pop.time,dims=1)
end

function trackGif!(pop)
    # tracker that all attitudes and behaviors, which we sometimes use for plotting gifs
    # (this creates pretty large files so best to use with small population size, N)
    pop.tracker.attAll = cat(pop.tracker.attAll,pop.attitudes,dims=2)
    pop.tracker.behavAll = cat(pop.tracker.behavAll,pop.behaviors,dims=3)
    pop.tracker.times = cat(pop.tracker.times,pop.time,dims=1)
end

function hasFixed(pop)
    # check if the population has reached fixation (for use with invasion analyses, when error = 0)
    return abs(mean(pop.attitudes)) == 1 && abs(mean(pop.behaviors)) == 1 && mean(pop.behaviors)==mean(pop.attitudes)
end

function trackFixation!(pop)
    # save the final state of the population if it's reached fixation
    pop.tracker.fixTime = pop.time
    (pop.trackerType=="visual")&&(trackVis!(pop))
    (pop.trackerType=="visualwlastalign")&&(trackViswlastalign!(pop))
end

# simulation setup for invation analyses (all but one member of the population has "resident" attitude and behavior, one member has "mutant")
# the goal of an invasion analysis is to see if/how quickly a mutant can "invade" (take over) the population
function simulateInvasion(resident,mutant,mutantType,mutantIndex,repetitions,N,M,rates,λBAstrength,λABstrength,β,α,err,time,simulationName;
                trackerType="simple",networkType="wellmixed", 
                attProbsType="model13Version",λBAdirectionType="lastBehavior",socialInfluenceType="mean",
                behavProbsType="model13Version",historyDependenceType="mean",
                dimensions=[],
                startingPop=[],
                untilFixation=true,
                trackFreq=Base.Inf,
                verbose=false,
                savePop=false
                #outputFrames= 1000,
                )


                attitudes = Array{Float64}(undef,N)
                behaviors = Array{Float64}(undef,N,M)
                attitudes[:].= resident
                behaviors[:,:].=resident

                (lowercase(mutantType)=="attitude")&&(attitudes[mutantIndex].=mutant)
                (lowercase(mutantType)=="behaviorlast")&&(behaviors[mutantIndex,end].=mutant)
                (lowercase(mutantType)=="behaviorall")&&(behaviors[mutantIndex,:].=mutant)

                startingPop=generatePop(N,M,rates,λBAstrength,λABstrength,β,α,err,networkType,attProbsType,λBAdirectionType,socialInfluenceType,behavProbsType,historyDependenceType,trackerType=lowercase(trackerType),attitudes=attitudes,behaviors=behaviors;dimensions=dimensions)


                simulate(repetitions,N,M,rates,λBAstrength,λABstrength,β,α,err,timelimit,simulationName,
                                trackerType=trackerType,networkType=networkType, mutantType=mutantType,
                                attProbsType=attProbsType,λBAdirectionType=λBAdirectionType,socialInfluenceType=socialInfluenceType,
                                behavProbsType=behavProbsType, historyDependenceType=historyDependenceType,
                                startingPop=startingPop,
                                untilFixation=untilFixation,
                                trackFreq=trackFreq,
                                dimensions=[],
                                verbose=verbose,
                                savePop=savePop
                                )
end

# main function for running simulations. Repetitions determines the number of identical repetitions of the same simulation to run
function simulate(repetitions,N,M,rates,λBAstrength,λABstrength,β,α,err,timelimit,simulationName;
                trackerType="simple",networkType="wellmixed",
                attProbsType="model13Version",λBAdirectionType="lastBehavior",socialInfluenceType="mean",
                behavProbsType="model13Version",historyDependenceType="mean",
                dimensions=[],
                startingPop=[],
                untilFixation=true,
                trackFreq=Base.Inf,
                verbose=false,
                savePop=true,
                mutantType="noMutant"
                #outputFrames= 1000,
                )
    #  file path for results
    paramString = getParamString(N,M,rates,λBAstrength,λABstrength,β,α,err,networkType,trackerType,attProbsType,λBAdirectionType,socialInfluenceType,behavProbsType,historyDependenceType,timelimit,mutantType=mutantType)

    simulationFullName = "$simulationName/$paramString"
    path = "../simulations/$simulationFullName/"
    !ispath(path) && savePop && mkpath(path)

    # create empty arrays for summary data
    sum_attMeans= SharedArray{Float64,1}(repetitions)
    sum_behavMeans= SharedArray{Float64,1}(repetitions)
    sum_acLasts= SharedArray{Float64,1}(repetitions)
    sum_alignments = SharedArray{Float64,1}(repetitions)
    sum_times = SharedArray{Float64,1}(repetitions)
    sum_fixTimes = SharedArray{Float64,1}(repetitions)

    # loop through all repetitions and run the simulation!
    iter=1:repetitions
    (verbose)&&(iter=ProgressBar(iter))
    for rr in iter
        # Create or load population
        jld_path = path*"all_reps.jld2"
        if isfile(jld_path)
            f = jldopen(jld_path, "r") #TODO make this a try/catch?
            has_rep = haskey(f, "pop_$rr")
            close(f)
        else
            has_rep = false
            loadFailed = true
        end

        if has_rep
            # if the repetition already exists, load it. If it finished running, we will skip this rep, if it has not reached timelimit, we will pick up where we left off
            # (this is great if the cluster cuts off before the simulations finish)
            try
                f = jldopen(jld_path, "r")
                has_rep = haskey(f, "pop_$rr")
                if has_rep
                    pop = f["pop_$rr"]
                    startT = pop.time
                    loadFailed = false
                else
                    loadFailed = true
                end
                close(f)
            catch error
                @warn "Failed to load rep $rr, deleting corrupted entry..." exception=(error, catch_backtrace())
                # Attempt to delete corrupted entry
                try
                    jldopen(jld_path, "r+") do file
                        delete!(file, "pop_$rr")
                    end
                catch delete_err
                    @warn "Failed to delete corrupted rep $rr" exception=(delete_err, catch_backtrace())
                end
                loadFailed = true
            end
        end

        if !has_rep || loadFailed
            # If no population is given, generate one from the parameters
            if typeof(startingPop) == Population
                pop = copy(startingPop)
                startT=pop.time

                pop.M = M
                pop.rates = rates
                pop.λBAstrength = λBAstrength
                pop.λABstrength = λABstrength
                pop.β = β
                pop.α = α
                pop.err = err
                pop.networkType = networkType
                pop.attProbsType=attProbsType
                pop.λBAdirectionType=λBAdirectionType
                pop.socialInfluenceType=socialInfluenceType
                pop.behavProbsType=behavProbsType
                pop.historyDependenceType=historyDependenceType
            else
                pop = generatePop(N,M,rates,λBAstrength,λABstrength,β,α,err,networkType,attProbsType,λBAdirectionType,socialInfluenceType,behavProbsType,historyDependenceType,lowercase(trackerType);dimensions=dimensions)
                startT=0
            end
        end

        # Generate events queue
        rateGroups = [1 N;1 N] #note, rateGroups allows only a subset of the population to experience a certain update type. Not currently used (all individuals, 1-N, perform both types of updates).
        events = get_events_table(startT,timelimit,rates,rateGroups,trackFreq)

        # go through all events or until fixation
        for event in eachrow(events)
            if untilFixation && hasFixed(pop)
                trackFixation!(pop)
                break
            end

            update!(pop,event)

        end

        sum_attMeans[rr] = mean(pop.attitudes)
        sum_behavMeans[rr] = mean(mean(pop.behaviors))
        sum_acLasts[rr] = mean(pop.behaviors[:,1])


	if trackerType == "visualwlastalign"
            sum_alignments[rr] = mean(pop.tracker.alignment)
        else
            sum_alignments[rr] = getAlignment(pop.attitudes,pop.behaviors)
        end

        sum_times[rr] = pop.time
        sum_fixTimes[rr] = pop.tracker.fixTime

        if savePop
            jldopen(path * "all_reps.jld2", "a+") do file
                key = "pop_$rr"

                # --- overwrite behaviour ---
                if haskey(file, key)
                    delete!(file, key)      # remove the old dataset
                end
                file[key] = pop             # write the fresh population
            end
        end
        
    end
    outputMat = hcat([sum_attMeans,sum_behavMeans,sum_acLasts,sum_alignments,sum_times,sum_fixTimes]...)

    path = "../data/$simulationName"
    !ispath(path) && mkpath(path)
    writedlm(path*"/"*paramString*"_summary.csv",outputMat,',')
    #summarize(simulationFullName, repetitions,verbose) #turned this off to save space, but can uncomment to also save a summary file of results!
end


function summarize(simulationFullName,repetitions,verbose)

    # Path for results
    path = "../simulations/$simulationFullName/"

    attMeans= SharedArray{Float64,1}(repetitions)
    behavMeans= SharedArray{Float64,1}(repetitions)
    acLasts= SharedArray{Float64,1}(repetitions)
    alignments = SharedArray{Float64,1}(repetitions)
    times = SharedArray{Float64,1}(repetitions)

    fixTimes = SharedArray{Float64,1}(repetitions)


    iter=1:repetitions
    (verbose)&&(iter=ProgressBar(iter))&&(print("Summarizing..."))
    for rr in iter
        pop_file = path*"pop_$rr.jld2"
        pop = load(pop_file,"pop")

        #TODO for now, just getting final value. should anything else matter?
        attMeans[rr] = mean(pop.attitudes)
        behavMeans[rr] = mean(mean(pop.behaviors))
        acLasts[rr] = mean(pop.behaviors[:,end])
        alignments[rr] = getAlignment(pop.attitudes,pop.behaviors)

        #generations and fix generations will be different if pop hasn't fixed
        times[rr] = pop.time
        fixTimes[rr] = pop.tracker.fixTime
    end
    outputMat = hcat([attMeans,behavMeans,acLasts,alignments,times,fixTimes]...)

    path = "../data/$simulationFullName"
    !ispath(path) && mkpath(path)
    writedlm(path*"_summary.csv",outputMat,',')
end
