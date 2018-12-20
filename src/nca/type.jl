using Unitful

"""
  NCADose

`NCADose` takes the following arguments
- `time`: time of the dose
- `formulation`: Type of formulation, `NCA.IV` or `NCA.EV`
- `amt`: The amount of dosage
"""
struct NCADose{T,A}
  time::T
  formulation::Formulation
  amt::A
end

# NCADose should behave like a scalar in broadcast
Broadcast.broadcastable(x::NCADose) = Ref(x)

# any changes in here must be reflected to ./simple.jl, too
mutable struct NCASubject{C,T,AUC,AUMC,D,Z,F,N,I,P}
  id::Int
  conc::C
  time::T
  maxidx::I
  lastidx::I
  dose::D
  lambdaz::Z
  llq::N
  r2::F
  intercept::F
  points::P
  auc_last::AUC
  aumc_last::AUMC
end

function NCASubject(conc′, time′; id=1, dose::T=nothing, llq=nothing, clean=true, lambdaz=nothing, kwargs...) where T
  conc, time = clean ? cleanblq(conc′, time′; llq=llq, kwargs...) : (conc′, time′)
  unitconc = oneunit(eltype(conc))
  unittime = oneunit(eltype(time))
  llq === nothing && (llq = zero(unitconc))
  auc_proto = -unitconc * unittime
  aumc_proto = auc_proto * unittime
  intercept = r2_proto = unittime/unitconc
  _lambdaz = inv(unittime)
  lambdaz_proto = lambdaz === nothing ? _lambdaz : lambdaz
  multidose = T <: AbstractArray
  if multidose
    n = length(dose)
    ct = let time=time, dose=dose
      map(eachindex(dose)) do i
        idxs = ithdoseidxs(time, dose, i)
        conc[idxs], time[idxs].-time[idxs[1]]
      end
    end
    conc = map(x->x[1], ct)
    time = map(x->x[2], ct)
    maxidx  = map(c->conc_maximum(c, eachindex(c))[2], conc)
    lastidx = @. ctlast_idx(conc, time; llq=llq, check=false)
    return NCASubject{typeof(conc), typeof(time),
                      Vector{typeof(auc_proto)}, Vector{typeof(aumc_proto)},
                      typeof(dose), Vector{typeof(lambdaz_proto)},
                      Vector{typeof(r2_proto)}, typeof(llq), typeof(lastidx), Vector{Int}}(id,
                        conc, time, maxidx, lastidx, dose, fill(lambdaz_proto, n), llq,
                        fill(r2_proto, n), fill(intercept, n), fill(0, n),
                        fill(auc_proto, n), fill(aumc_proto, n))
  end
  _, maxidx = conc_maximum(conc, eachindex(conc))
  lastidx = ctlast_idx(conc, time; llq=llq, check=false)
  NCASubject{typeof(conc), typeof(time),
          typeof(auc_proto), typeof(aumc_proto),
          typeof(dose), typeof(lambdaz_proto),
          typeof(r2_proto), typeof(llq), typeof(lastidx), Int}(id,
            conc, time, maxidx, lastidx, dose, lambdaz_proto, llq,
            r2_proto,  intercept, 0,
            auc_proto, aumc_proto)
end

showunits(nca::NCASubject, args...) = showunits(stdout, nca, args...)
function showunits(io::IO, ::NCASubject{C,T,AUC,AUMC,D,Z,F,N,I,P}, indent=0) where {C,T,AUC,AUMC,D,Z,F,N,I,P}
  pad   = " "^indent
  if D <: NCADose
    doseT = D.parameters[2]
  elseif D <: AbstractArray
    doseT = eltype(D).parameters[2]
  else
    doseT = D
  end
  multidose = D <: AbstractArray
  _C = multidose ? eltype(C) : C
  _T = multidose ? eltype(T) : T
  _AUC = multidose ? eltype(AUC) : AUC
  _AUMC = multidose ? eltype(AUMC) : AUMC
  _Z = multidose ? eltype(Z) : Z
  if eltype(_C) <: Quantity
    conct = string(unit(eltype(_C)))
    timet = string(unit(eltype(_T)))
    AUCt  = string(unit(_AUC))
    AUMCt = string(unit(_AUMC))
    Zt    = string(unit(_Z))
    Dt    = D === Nothing ? D : string(unit(doseT))
  else
    conct = nameof(eltype(_C))
    timet = nameof(eltype(_T))
    AUCt  = _AUC
    AUMCt = _AUMC
    Zt    = _Z
    Dt    = doseT
  end
  println(io, "$(pad)concentration: $conct")
  println(io, "$(pad)time:          $timet")
  println(io, "$(pad)auc:           $AUCt")
  println(io, "$(pad)aumc:          $AUMCt")
  println(io, "$(pad)λz:            $Zt")
  print(  io, "$(pad)dose:          $Dt")
end

function Base.show(io::IO, n::NCASubject)
  println(io, "NCASubject:")
  println(io, "  ID: $(n.id)")
  showunits(io, n, 4)
end

struct NCAPopulation{T<:NCASubject} <: AbstractVector{T}
  subjects::Vector{T}
end

Base.size(n::NCAPopulation) = size(n.subjects)
Base.getindex(n::NCAPopulation, I...) = getindex(n.subjects, I...)
Base.setindex!(n::NCAPopulation, X, I...) = setindex!(n.subjects, X, I...)

# Summary and report
struct NCAReport{S,V}
  settings::S
  values::V
end

function NCAReport(nca::NCASubject{C,T,AUC,AUMC,D,Z,F,N,I,P}; kwargs...) where {C,T,AUC,AUMC,D,Z,F,N,I,P}
  D === Nothing && @warn "`dose` is not provided. No dependent quantities will be calculated"
  # TODO: Summarize settings
  settings = nothing

  # Calculate summary values
  clast′ = clast(nca; kwargs...)
  tlast′ = tlast(nca; kwargs...)
  tmax′  = tmax(nca; kwargs...)
  cmax′  = cmax(nca; kwargs...)
  λz     = lambdaz(nca; recompute=false, kwargs...)[1]
  thalf′ = thalf(nca; kwargs...)
  auc′   = auc(nca; kwargs...)
  aucp   = auc_extrap_percent(nca; kwargs...)
  aumc′  = aumc(nca; kwargs...)
  aumcp  = aumc_extrap_percent(nca; kwargs...)
  values = (clast=clast′, tlast=tlast′, tmax=tmax′, cmax=cmax′,
   lambdaz=λz, thalf=thalf′, auc=auc′, auc_extrap_percent=aucp,
   aumc=aumc′, aumc_extrap_percent=aumcp)

  NCAReport(settings, values)
end

Base.summary(::NCAReport) = "NCAReport"
function Base.show(io::IO, ::MIME"text/plain", report::NCAReport)
  println(io, "# Noncompartmental Analysis Report")
  println(io, "PuMaS version " * string(Pkg.installed()["PuMaS"]))
  println(io, "Julia version " * string(VERSION))
  println(io, "")
  println(io, "Date and Time: " * Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))
  println(io, "")

  println(io, "## Calculation Setting")
  # TODO
  println(io, "")

  println(io, "## Calculated Values")
  println(io, "|         Name         |    Value   |")
  println(io, "|----------------------|------------|")
  for entry in pairs(report.values)
    @printf(io, "| %-20s | %10f |\n", entry[1], entry[2])
  end
end