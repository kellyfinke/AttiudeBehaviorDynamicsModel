mutable struct Population
    # Population size
    N::Int64
    # 2d dimensions of population (only needed if using lattice-shaped social network), default []
    dimensions::Array{Int64,2}
    # Behavior memory queue length
    M::Int64
    # update rates [attitude update, behavior update]
    rates::Array{Float64,1}
    # Possible beahvior/attitude alternatives (NOTE! currently, the code is only set up for alternatives=[-1,1])
    alternatives::Array{Int64,2}
    # strength of Attitude-Behavior Linkage, from Behavior to Attitude
    λBAstrength::Float64
    # strength of Attitude-Behavior Linkage, from Attitude to Behavior
    λABstrength::Float64
    # Behavior Incentive 
    β::Float64
    # Strength of Attitude Bias
    α::Float64
    # random update error
    err::Float64
    #simulation time steps completed so far
    time::Float64
    # population structure (options: lattice_aperiodic, lattice, wellmixed, barbell, smallworld, random)
    networkType::String
    # method for caluclating new attitude probabilities (currently only one option, "model13Version")
    attProbsType::String
    # when determing direction of λAB, what behavior should you look at ("meanBehavior","modeBehavior","lastBehavior")
    λBAdirectionType::String
    # method for calculating S ("mean","mode")
    socialInfluenceType::String
    # method for calculating new behavior probablities (currently only one option, "model13Version")
    behavProbsType::String
    # method for calculating H ("linear","mean","mode","sigmoid") (note: linear=mean)
    historyDependenceType::String
    # per individual attitudes
    attitudes::Array{Int64,1}
    # per indivdual memory of M behaviors
    behaviors::Array{Int64,2}
    # "sparse" matrix of network connections
    network::SimpleGraph{Int64}
    # a string telling the type of tracker used for this simulation
    trackerType::String
    # struct to track metrics of this pop
    tracker
end
    
mutable struct Tracker
    fixTime::Float64
end

mutable struct VisTracker
    attMean::Array{Float64,1}
    behavMean::Array{Float64,1}
    times::Array{Float64,1}
    fixTime::Float64
end

mutable struct VisTrackerWLastAlign
    attMean::Array{Float64,1}
    behavMean::Array{Float64,1}
    acLast::Array{Float64,1}

    alignment::Array{Float64,1}
    times::Array{Float64,1}

    fixTime::Float64
end

mutable struct GifTracker
    # tracker used to generate a gif of population change over time
    # recommend use of lattice network structure (to see spatial change)
    # and small population size!
    attAll::Array{Float64,2}
    behavAll::Array{Float64,3}
    times::Array{Float64,1}

    fixTime::Float64
end

Base.copy(p::Population) = Population(copy(p.N),copy(p.dimensions),copy(p.M),copy(p.rates),copy(p.alternatives),copy(p.λBAstrength),copy(p.λABstrength),copy(p.β),copy(p.α),copy(p.err),copy(p.time),p.networkType,p.attProbsType,p.λBAdirectionType,p.socialInfluenceType,p.behavProbsType,p.historyDependenceType,copy(p.attitudes),copy(p.behaviors),copy(p.network),p.trackerType,copy(p.tracker))
Base.copy(t::Tracker) = Tracker(copy(t.fixTime))
Base.copy(v::VisTracker) = VisTracker(copy(v.attMean),copy(v.behavMean),copy(v.times),copy(v.fixTime))
Base.copy(v::VisTrackerWLastAlign) = VisTracker(copy(v.attMean),copy(v.behavMean),copy(v.acLast),copy(v.alignment),copy(v.times),copy(v.fixTime))
Base.copy(g::GifTracker) = GifTracker(copy(g.attAll),copy(g.behavAll),copy(g.times),copy(g.fixTime))
