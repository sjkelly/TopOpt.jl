macro params(struct_expr)
    header = struct_expr.args[2]
    fields = @view struct_expr.args[3].args[2:2:end]
    params = []
    for i in 1:length(fields)
        x = fields[i]
        T = gensym()
        if x isa Symbol
            push!(params, T)
            fields[i] = :($x::$T)
        elseif x.head == :(::)
            abstr = x.args[2]
            var = x.args[1]
            push!(params, :($T <: $abstr))
            fields[i] = :($var::$T)
        end
    end
    if header isa Symbol && length(params) > 0
        struct_expr.args[2] = :($header{$(params...)})
    elseif header.head == :curly
        append!(struct_expr.args[2].args, params)
    elseif header.head == :<:
        if struct_expr.args[2].args[1] isa Symbol
            name = struct_expr.args[2].args[1]
            struct_expr.args[2].args[1] = :($name{$(params...)})
        elseif header.head == :<: && struct_expr.args[2].args[1] isa Expr
            append!(struct_expr.args[2].args[1].args, params)
        else
            error("Unidentified type definition.")
        end
    else
        error("Unidentified type definition.")
    end
    esc(struct_expr)
end

@define_cu(IterativeSolvers.CGStateVariables, :u, :r, :c)

struct RaggedArray{TO, TV}
    offsets::TO
    values::TV
end
whichdevice(ra::RaggedArray) = whichdevice(ra.offsets)

function RaggedArray(vv::Vector{Vector{T}}) where T
    offsets = [1; 1 .+ accumulate(+, collect(length(v) for v in vv))]
    values = Vector{T}(undef, offsets[end]-1)
    for (i, v) in enumerate(vv)
        r = offsets[i]:offsets[i+1]-1
        values[r] .= v
    end
    RaggedArray(offsets, values)
end
@define_cu(RaggedArray, :offsets, :values)

function Base.getindex(ra::RaggedArray, i)
    @assert 1 <= i < length(ra.offsets)
    r = ra.offsets[i]:ra.offsets[i+1]-1
    @assert 1 <= r[1] && r[end] <= length(ra.values)
    return @view ra.values[r]
end
function Base.getindex(ra::RaggedArray, i, j)
    @assert 1 <= j < length(ra.offsets)
    r = ra.offsets[j]:ra.offsets[j+1]-1
    @assert 1 <= i <= length(r)
    return ra.values[r[i]]
end
function Base.setindex!(ra::RaggedArray, v, i, j)
    @assert 1 <= j < length(ra.offsets)
    r = ra.offsets[j]:ra.offsets[j+1]-1
    @assert 1 <= i <= length(r)
    ra.values[r[i]] = v
end

function find_varind(black, white, ::Type{TI}=Int) where TI
    nel = length(black)
    nel == length(white) || throw("Black and white vectors should be of the same length")
    varind = zeros(TI, nel)
    k = 1
    for i in 1:nel
        if !black[i] && !white[i]
            varind[i] = k
            k += 1
        end
    end
    return varind
end

function find_black_and_white(dh)
    black = falses(getncells(dh.grid))
    white = falses(getncells(dh.grid))
    if haskey(dh.grid.cellsets, "black")
        for c in grid.cellsets["black"]
            black[c] = true
        end
    end
    if haskey(dh.grid.cellsets, "white")
        for c in grid.cellsets["white"]
            white[c] = true
        end
    end
    
    return black, white
end

YoungsModulus(p) = getE(p)
PoissonRatio(p) = getν(p)

function compliance(Ke, u, dofs)
    comp = zero(eltype(u))
    for i in 1:length(dofs)
        for j in 1:length(dofs)
            comp += u[dofs[i]]*Ke[i,j]*u[dofs[j]]
        end
    end
    comp
end

function meandiag(K::AbstractMatrix)
    z = zero(eltype(K))
    for i in 1:size(K, 1)
        z += abs(K[i, i])
    end
    return z / size(K, 1)
end

density(var, xmin) = var*(1-xmin) + xmin

macro debug(expr)
    return quote
        if DEBUG[]
            $(esc(expr))
        end
    end
end
