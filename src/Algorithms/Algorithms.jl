module Algorithms

using ..MMA, ..Functions, Optim, Parameters
using TimerOutputs, Setfield, StaticArrays
using Parameters: @unpack, @pack!
using ..GPUUtils, ..Utilities, JuAFEM
using LinearAlgebra

export  MMAOptimizer,
        SIMP,
        ExponentialContinuation,
        ContinuationSIMP,
        AdaptiveSIMP,
        MMAOptionsGen,
        CSIMPOptions,
        BESO,
        GESO,
        Continuation,
        PowerContinuation

const to = TimerOutput()

abstract type TopOptAlgorithm end

# Solid isotropic material with penalisation
include(joinpath("SIMP", "SIMP.jl"))

# Bidirectional evolutionary strctural optimisation
include("beso.jl")

# Genetic evolutionary structural optimisation
include("geso.jl")

end
