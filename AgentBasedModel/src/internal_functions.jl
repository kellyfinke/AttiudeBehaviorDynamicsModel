
function generatePop(N,M,rates,λBAstrength,λABstrength,β,α,err,networkType,attProbsType,λBAdirectionType,socialInfluenceType,behavProbsType,historyDependenceType,trackerType;
                    dimensions=[],       
                    attitudes=[], #Can pass in nonrandom attitude and behavior matrices (e.g. for an invasion)
                    behaviors=[])
    # generate the population struct given the input parameters

    # Currently this should not be modified, but future work could allow for more than 2 alternatives
    # (doing so would require updating the probability equations accordingly)
    alternatives = [-1,+1]

    # generate network based on networkType
    # Note: lattice networks require dimensions parameter!
    (lowercase(networkType)=="lattice_aperiodic")&&(dimensions!=[])&&(network= Graphs.SimpleGraphs.grid(dimensions,periodic=false))
    ((lowercase(networkType)=="lattice")||(lowercase(networkType)=="lattice_periodic"))&&(dimensions!=[])&&(network= Graphs.SimpleGraphs.grid(dimensions,periodic=true))
    (lowercase(networkType)=="wellmixed")&&(network=Graphs.SimpleGraph(1)) #avoid saving large network file if the network is wellmixed -- NOT THE ACTUAL NETWORK (see getSocialInfluence below)
    (lowercase(networkType)=="barbell")&&(network=barbell_graph(Int(ceil(N/2)),Int(floor(N/2))))
    (lowercase(networkType)=="smallworld")&&(network=watts_strogatz(N, 4, 0.3))
    ((lowercase(networkType)=="random")||(lowercase(networkType)=="erdos_renyi"))&&(network=erdos_renyi(N, N*4))

    # Fill the population with attitudes and behaviors
    # If none given, distribute randomly
    (isempty(attitudes))&&(attitudes=rand(alternatives,N))
    (isempty(behaviors))&&(behaviors=rand([alternatives[1],alternatives[end]],N,M))

    #create Tracker based on trackerType
    (lowercase(trackerType)=="simple")&&(tracker=Tracker(Base.Inf))
    (lowercase(trackerType)=="visual")&&(tracker=VisTracker(Array{Float64,1}(undef,0),Array{Float64,1}(undef,0),Array{Float64,1}(undef,0),Base.Inf))
    (lowercase(trackerType)=="visualwlastalign")&&(tracker=VisTrackerWLastAlign(Array{Float64,1}(undef,0),Array{Float64,1}(undef,0),Array{Float64,1}(undef,0),Array{Float64,1}(undef,0),Array{Float64,1}(undef,0),Base.Inf))
    (lowercase(trackerType)=="gif")&&(tracker=GifTracker(Array{Float64,2}(undef,N,0),Array{Float64,3}(undef,N,M,0),Array{Float64,1}(undef,0),Base.Inf))

    pop = Population(N,hcat(dimensions),M,rates,hcat(alternatives),λBAstrength,λABstrength,β,α,err,0,networkType,attProbsType,λBAdirectionType,socialInfluenceType,behavProbsType,historyDependenceType,attitudes,behaviors,network,trackerType,tracker)

    #Do initial track
    (lowercase(trackerType)=="visual")&&(trackVis!(pop))
    (lowercase(trackerType)=="visualwlastalign")&&(trackViswlastalign!(pop))
    (lowercase(trackerType)=="update")&&(nextUpdateStep!(pop))
    (lowercase(trackerType)=="gif")&&(trackGif!(pop))

    return pop
end

function generate_arrival_times(startT,timelimit,λ)
    #used for generating events queue

    arrival_times = Float64[]
    t = startT
    while t < timelimit
        # generate inter-arrival time from exponential distribution with parameter λ
        interarrival_time = rand(Exponential(1/λ))
        # update time
        t += interarrival_time
        # add inter-arrival time to list
        push!(arrival_times, t)
    end
    # remove the last inter-arrival time if it exceeds the total simulation time
    if length(arrival_times)>=1 && arrival_times[end] > timelimit
        pop!(arrival_times)
    end
    return arrival_times
end

function get_event_times(startT,timelimit,λ,rateGroup)
    #used for generating events queue

    times = [ (generate_arrival_times(startT,timelimit,λ)) for _ in rateGroup[1]:rateGroup[2] ]
    people = [ repeat([indv],length(times[ii])) for (ii,indv) in enumerate(rateGroup[1]:rateGroup[2]) ]
    order = sortperm(vcat(times...))
    table = hcat(vcat(times...)[order],vcat(people...)[order])

    return table
end

function get_track_table(startT,timelimit,trackFreq)
    # generate tracking event timings (since tracking is defined by a specific frequency)

    (trackFreq>timelimit)&&(trackFreq=timelimit+1) #if infinite trackFreq

    #start time is closest multuple of trackFreq >= start time
    firstTrack = ceil(startT/trackFreq)*trackFreq

    times = collect(firstTrack:trackFreq:timelimit)
    people = zeros(length(times))
    event = zeros(length(times))
    table = hcat(times,people,event)

    return table
end

function get_events_table(startT,timelimit,rates,rateGroups,trackFreq)
    # this creates the events queue which gives the order and timing of each update and tracking event

    events = [get_track_table(startT,timelimit,trackFreq)]
    for e in eachindex(rates)
        event = get_event_times(startT,timelimit,rates[e],rateGroups[e,:])
        event = hcat(event,repeat([e],size(event,1)))
        push!(events, event)
    end
    events = vcat(events...)
    events = events[sortperm(events[:,1]),:]
end

function getAttitudeUpdateProbs(pop,indv)
    # calculate the probability of selecting attitude A- vs A+
    # returns [prob of selecting A-, prob of selecting A+]

    λBA=pop.λBAstrength*getλBAdirection(pop,indv)
    S=getSocialInfluence(pop,indv) 

    if pop.attProbsType == "model13Version" #this is the version used in the paper!
        # first, determine if acting according to bias,
        # if not, decision is based on weight based on linkage and social influence
        # has a (1-λAB)(1-I) chance of acting randomly
        # also error

        if (abs(λBA) + abs(S)) == 0 #avoid divide by zero
            weights = [0.5,0.5]
        else
            weights = 0.5 .+ 0.5 .* ((λBA + S)/(pop.λBAstrength + abs(S))) .* pop.alternatives
        end
        randomProb = (1-pop.λBAstrength)*(1-abs(S))
        attProbs = abs(pop.α) * (sign(pop.α) .== pop.alternatives) .+ (1-abs(pop.α))*((randomProb+(1-randomProb)*pop.err).* [0.5,0.5] + (1-randomProb)*(1-pop.err) .* weights)
        return attProbs

    elseif pop.attProbsType == "model14WeirdVersion" # just another update calcuation, for fun
        # first, determine if acting according to bias,
        # if not, decision is based on weight based on linkage and social influence
        # has a (1-λAB)(1-I) chance of acting randomly
        # also error

        if (abs(λBA) + abs(S)) == 0 #avoid divide by zero
            weights = [0.5,0.5]
        else
            weights = 0.5 .+ 0.5 .* ((λBA + S)/(abs(λBA) + abs(S))) .* pop.alternatives
        end
        randomProb = (1-abs(λBA))*(1-abs(S))
        attProbs = abs(pop.α) * (sign(pop.α) .== pop.alternatives) .+ (1-abs(pop.α))*((randomProb+(1-randomProb)*pop.err).* [0.5,0.5] + (1-randomProb)*(1-pop.err) .* weights)
        return attProbs
    else
        type = pop.attProbsType
        availOps = ["model13Version","model14WeirdVersion"]
        @warn("Undefined attitude probability calculation type attProbType=$type, available opions are $availOps.")
    end
end

function getSocialInfluence(pop,indv)
    # get the value of social influence, S

    if lowercase(pop.networkType) == "wellmixed"
        # everyone (except self) is a neighbour
        # separate this out so we don't have to save a massive social network

        if pop.socialInfluenceType == "mean"
            # mean without self; avoids allocating a vector
            return (sum(pop.attitudes) - pop.attitudes[indv]) / max(pop.N - 1, 1)
        elseif pop.socialInfluenceType == "mode"
            return sign((sum(pop.attitudes) - pop.attitudes[indv]) / max(pop.N - 1, 1))
        else
            type = pop.socialInfluenceType
            availOps = ["mean","mode"]
            @warn("Undefined social update type socialInfluenceType=$type, available opions are $availOps. $e")
        end
    else
        neighborAtts = pop.attitudes[all_neighbors(pop.network, indv)]
        if pop.socialInfluenceType == "mean"
            return mean(neighborAtts)
        elseif pop.socialInfluenceType == "mode"
            return sign(mean(neighborAtts))
        else
            type = pop.socialInfluenceType
            availOps = ["mean","mode"]
            @warn("Undefined social update type socialInfluenceType=$type, available opions are $availOps. $e")
        end
    end
end

function getλBAdirection(pop,indv)
    # if using lastBehavior or modeBehavior, this will just return +1 or -1 
    # if using meanBehavior, this will return a value from -1 to +1
    # check out note on this in the supplemental materials! 

    if pop.λBAdirectionType == "meanBehavior"
        return mean(pop.behaviors[indv,:])
    elseif pop.λBAdirectionType == "modeBehavior"
        return sign(mean(pop.behaviors[indv,:]))
    elseif pop.λBAdirectionType == "lastBehavior"
        return pop.behaviors[indv,end]
    else
        type = pop.λBAdirectionType
        availOps = ["meanBehavior","modeBehavior","lastBehavior"]
        @warn("Undefined λBAdirectionType=$type, available opions are $availOps.")
    end
end

function getBehaviorUpdateProbs(pop,indv)
    # Calculate the probability of choosing behavior B- or B+
    # returns [prob of selecting B-, prob of selecting B+]

    H = getHistoryDependence(pop,indv)
    λAB=pop.λABstrength*pop.attitudes[indv]

    if pop.behavProbsType == "model13Version" #version used in the paper
        # first, determine if acting according to bias,
        # if not, decision is based on weight based on linkage and habit
        # version 1 has a (1-λAB)(1-I) chance of acting randomly

        if (abs(λAB) + abs(H)) == 0 #avoid divide by zero
            weights = [0.5,0.5]
        else
            weights = 0.5 .+ 0.5 .* ((λAB + H )/(abs(λAB) + abs(H))) .* pop.alternatives
        end

        randomProb = (1-abs(λAB))*(1-abs(H))
        behavProbs = abs(pop.β) * (sign(pop.β) .== pop.alternatives) .+ (1-abs(pop.β))*((randomProb+(1-randomProb)*pop.err) .* [0.5,0.5] + (1-randomProb)*(1-pop.err) .* weights)
        return behavProbs
    else # you can write your own version if you want :)
        type = pop.behavProbsType
        availOps = ["model13Version"]
        @warn("Undefined behavior probability calculation type behavProbsType=$type, available opions are $availOps.")
    end
    return behavProbs
end

function getHistoryDependence(pop,indv)
    # between -1 and 1 where 0 is completely random previos behaviors (50-50)
    # and -1 is 100% habit of negative behavior, +1 is 100% habit of positive behavior

    if pop.historyDependenceType == "linear" || pop.historyDependenceType == "mean" #this is the version used in the paper
        return mean(pop.behaviors[indv,:])

    elseif  pop.historyDependenceType == "sigmoid"  #cool bonus version
        #TODO make 3.8 a parameter
        # right now 3.8 is used to get to a 95% Inertia at 100% perfect habit
        return 2/(1+exp(-3.8*(mean(pop.behaviors[indv,:]))))-1

    elseif  pop.historyDependenceType == "miller"
        # just in case anyone wants to implement habit formation as described in Miller et al. :)
        @warn("I havent implemented this yet :o")
    else
        type = pop.historyDependenceType
        availOps = ["linear","mean","sigmoid","miller"]
        @warn("Undefined habit strength type historyDependenceType=$type, available opions are $availOps.")
    end

end

function getAlignment(attitudes,behaviors)
    # return the average alignment between individuals' attitude and behavior
    # to evaluate the average attitude behavior gap
    return (2-abs(mean(attitudes.-mean(behaviors))))/2
end

function getParamString(N,M,rates,λBAstrength,λABstrength,β,α,err,networkType,trackerType,attProbsType,λBAdirectionType,socialInfluenceType,behavProbsType,historyDependenceType,timelimit;mutantType="noMutant")
    # used to save unique filenames for simulations

    return "$N,$M,$rates,$λBAstrength,$λABstrength,$β,$α,$err,$networkType,$trackerType,$mutantType,$attProbsType,$λBAdirectionType,$socialInfluenceType,$behavProbsType,$historyDependenceType,$timelimit"
end

# sample attitude or behavior from probabilities 
sample(items, weights) = items[findfirst(cumsum([weights...]) .> rand())]


