__precompile__(true)
module AttitudeBehaviorDynamicsModel

    using SharedArrays, LinearAlgebra, Statistics, FileIO, DelimitedFiles, JLD2, Graphs, Colors, GraphPlot, Distributions,GaussianMixtures

    include("structs.jl")
    export Population
    export Tracker
    export VisTracker
    export VisTrackerWLastAlign
    export GifTracker

    include("internal_functions.jl")
    #TODO update these
    export generatePop
    export generate_arrival_times
    export get_event_times
    export get_track_table
    export get_events_table
    export getAlignment
    export getParamString
    export getAttitudeUpdateProbs
    export getSocialInfluence
    export getλBAdirection
    export getBehaviorUpdateProbs
    export getHistoryDependence
    export getOutputClassification

    include("simulations.jl")
    export update!
    export track!
    export partialSocialUpdate!
    export attitudeUpdate!
    export behaviorUpdate!
    export trackVis!
    export hasFixed
    export trackFixation!
    export simulateInvasion
    export simulate
    export summarize

end
