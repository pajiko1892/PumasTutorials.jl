using PuMaS
using LinearAlgebra

choose_covariates() = (isPM = rand([1, 0]),
                       Wt = rand(55:80))

function generate_population(events,nsubs=4)
  pop = Population(map(i -> Subject(id=i,evs=events,cvs=choose_covariates()),1:nsubs))
  return pop
end

ev = DosageRegimen(100, cmt = 2)
ev2 =  generate_population(ev)

m_diffeq = @model begin
  @param   begin
    θ ∈ VectorDomain(5, lower=zeros(5), init=ones(5))
    Ω ∈ PSDDomain(2)
    σ_prop ∈ RealDomain(init=0.1)
  end

  @random begin
    η ~ MvNormal(Ω)
  end

  @pre begin
    Ka = θ[1]
    CL = θ[2]*exp(η[1])
    V  = θ[3]*exp(η[2])
    lags = [0,θ[4]]
    bioav = [1,θ[5]]
  end

  @covariates isPM Wt

  @dynamics begin
    Depot'   = -Ka*Depot
    Central' =  Ka*Depot - (CL/V)*Central
  end

  @derived begin
    cp = @. 1000*(Central / V)
    nca := @nca cp
    auc =  NCA.auc(nca)
    thalf =  NCA.thalf(nca)
    cmax = NCA.cmax(nca)
  end
end

p = (  θ = [1.5,  #Ka
            1.1,  #CL
            20.0,  #V
            0, # lags2
            1 #Bioav
           ],
     Ω = PDMat(diagm(0 => [0.04,0.04])),
     σ_prop = 0.00
    )


sim = @test_nowarn simobs(m_diffeq, ev2, p; abstol=1e-14, reltol=1e-14, parallel_type=PuMaS.Serial)
for i in eachindex(sim.sims)
  @test NCA.auc(sim[i].observed.cp, sim[i].times) === sim[i].observed.auc
  @test NCA.thalf(sim[i].observed.cp, sim[i].times) === sim[i].observed.thalf
  @test NCA.cmax(sim[i].observed.cp, sim[i].times) === sim[i].observed.cmax
end

pop = Population(map(i->sim.sims[i].subject, eachindex(sim.sims)))
@test_nowarn NCAPopulation(pop, name=:dv)
@test_nowarn NCASubject(pop[1], name=:dv)
@test NCADose(ev2.subjects[1].events[1]) === NCADose(0.0, 100.0, 0.0, 0.0, NCA.IVBolus)
