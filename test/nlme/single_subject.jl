using Test
using Pumas
using Random

@testset "Single subject" begin
  data = read_pumas(example_data("sim_data_model1"))

  mdsl1 = @model begin
    @param begin
      θ ∈ VectorDomain(1, init=[0.5])
      Σ ∈ ConstDomain(0.1)
    end

    @pre begin
      CL = θ[1]
      V  = 1.0
    end

    @vars begin
      conc = Central / V
    end

    @dynamics Central1

    @derived begin
      dv ~ @. Normal(conc,conc*sqrt(Σ)+eps())
    end
  end

  param = init_param(mdsl1)

  for approx in (Pumas.FO, Pumas.FOI, Pumas.FOCE, Pumas.FOCEI, Pumas.LaplaceI, Pumas.LLQuad)
    @test_throws ArgumentError fit(mdsl1, data[1], param, approx())
  end
end

@testset "Readme roundtrip" begin
  Random.seed!(123)

  model = @model begin
    @param  begin
      tvcl ∈ RealDomain(lower=0)
      tvv ∈ RealDomain(lower=0)
      pmoncl ∈ RealDomain(lower = -0.99)
      σ_prop ∈ RealDomain(lower=0)
    end

    @covariates wt isPM

    @pre begin
      CL = tvcl * (1 + pmoncl*isPM) * (wt/70)^0.75
      V  = tvv * (wt/70)
    end

    @dynamics Central1
    #@dynamics begin
    #    Central' =  - (CL/V)*Central
    #end

    @derived begin
      cp = @. 1000*(Central / V)
      dv ~ @. Normal(cp, sqrt(cp^2*σ_prop))
    end
  end

  ev = DosageRegimen(100, time=0, addl=4, ii=24)

  param = (
    tvcl = 4.0,
    tvv  = 70,
    pmoncl = -0.7,
    σ_prop = 0.04
  )

  choose_covariates() = (isPM = rand([1, 0]), wt = rand(55:80))

  pop_with_covariates = Population(map(i -> Subject(id=i, evs=ev, cvs=choose_covariates()), 1:1000))

  obs = simobs(model, pop_with_covariates, param, obstimes=0:1:120)

  simdf = DataFrame(obs)
  simdf.cmt .= 1

  data = read_pumas(simdf, time=:time, cvs=[:isPM, :wt])

  res = fit(model, data[1], param)
  trf = Pumas.totransform(model.param)
  fits = [fit(model, dat, param) for dat in data]
  fitone = fit(model, first(data), param)

@test sprint((io, t) -> show(io, MIME"text/plain"(), t), fitone) ==
"""FittedPumasModel

Successful minimization:                true

Likelihood approximation:  Pumas.NaivePooled
Deviance:                          1624.7916
Total number of observation records:     121
Number of active observation records:    121
Number of subjects:                        1

---------------------
           Estimate
---------------------
tvcl        3.9888
tvv        71.687
pmoncl     -0.7008
σ_prop      0.052676
---------------------
"""

  fitnp = fit(model, data, param, Pumas.NaivePooled())

  @test sprint((io, t) -> show(io, MIME"text/plain"(), t), infer(fitnp)) ==
"""FittedPumasModelInference

Successful minimization:                true

Likelihood approximation:  Pumas.NaivePooled
Deviance:                        1.4996119e6
Total number of observation records:  121000
Number of active observation records: 121000
Number of subjects:                     1000

--------------------------------------------------------------------
          Estimate           SE                      95.0% C.I.
--------------------------------------------------------------------
tvcl       3.9995          0.0031928         [ 3.9933  ;  4.0058  ]
tvv       69.907           0.093962          [69.723   ; 70.092   ]
pmoncl    -0.69962         0.00059607        [-0.70079 ; -0.69845 ]
σ_prop     0.040164        0.00017112        [ 0.039828;  0.040499]
--------------------------------------------------------------------
"""

  inspect_np = DataFrame(inspect(fitnp))
  @test mean(inspect_np.dv_iwres) < 1e-6

  fit2s = fit(model, data, param, Pumas.TwoStage())

  @test sprint((io, t) -> show(io, MIME"text/plain"(), t), fit2s) ==
"""Vector{<:FittedPumasModel} with 1000 entries

Parameter statistics
-------------------------------------
          Mean               Std
-------------------------------------
tvcl       3.9988          0.083047
tvv       70.001           2.9683
pmoncl    -0.70006         0.0045627
σ_prop     0.039554        0.0053568
-------------------------------------
"""

end


@testset "with random" begin
  data = read_pumas(example_data("sim_data_model1"))

  mdsl1 = @model begin
      @param begin
          θ ∈ VectorDomain(1, init=[0.5], lower = [0.0], upper=[20.0])
          Ω ∈ PDiagDomain(init=[0.04])
          Σ ∈ ConstDomain(0.1)
      end

      @random begin
          η ~ MvNormal(Ω)
      end

      @pre begin
          CL = θ[1] * exp(η[1])
          V  = 1.0
      end

      @vars begin
          conc = Central / V
      end

      @dynamics Central1

      @derived begin
          dv ~ @. Normal(conc,conc*sqrt(Σ)+eps())
      end
  end
  mdsl1full = @model begin
      @param begin
          θ ∈ VectorDomain(1, init=[0.5], lower = [0.0], upper=[20.0])
          Ω ∈ PSDDomain(init=[0.04])
          Σ ∈ ConstDomain(0.1)
      end

      @random begin
          η ~ MvNormal(Ω)
      end

      @pre begin
          CL = θ[1] * exp(η[1])
          V  = 1.0
      end

      @vars begin
          conc = Central / V
      end

      @dynamics Central1

      @derived begin
          dv ~ @. Normal(conc,conc*sqrt(Σ)+eps())
      end
  end
  mdsl1_noeta = @model begin
      @param begin
          θ ∈ VectorDomain(1, init=[0.5])
          Σ ∈ ConstDomain(0.1)
      end

      @pre begin
          CL = θ[1]
          V  = 1.0
      end

      @vars begin
          conc = Central / V
      end

      @dynamics Central1

      @derived begin
          dv ~ @. Normal(conc,conc*sqrt(Σ)+eps())
      end
  end


  param_noeta = init_param(mdsl1_noeta)
  fitone_noeta = fit(mdsl1_noeta, first(data), param_noeta)

  @test sprint((io, t) -> show(io, MIME"text/plain"(), t), fitone_noeta) ==
"""FittedPumasModel

Successful minimization:                true

Likelihood approximation:  Pumas.NaivePooled
Deviance:                          4.4609099
Total number of observation records:       2
Number of active observation records:      2
Number of subjects:                        1

----------------
       Estimate
----------------
θ₁      0.13038
Σ       0.1
----------------
"""
  infer_noeta = infer(fitone_noeta)
  @test sprint((io, t) -> show(io, MIME"text/plain"(), t), infer_noeta) ==
"""FittedPumasModelInference

Successful minimization:                true

Likelihood approximation:  Pumas.NaivePooled
Deviance:                          4.4609099
Total number of observation records:       2
Number of active observation records:      2
Number of subjects:                        1

---------------------------------------------------------
      Estimate           SE                  95.0% C.I.
---------------------------------------------------------
θ₁     0.13038         1.0297e-5       [0.13036; 0.1304]
Σ      0.1             NaN             [ NaN   ;  NaN    ]
---------------------------------------------------------
"""

  param = init_param(mdsl1)
  fitone_constantcoef = fit(mdsl1, first(data), param; constantcoef=(Ω=[0.0],))
    @test sprint((io, t) -> show(io, MIME"text/plain"(), t), fitone_constantcoef) ==
"""FittedPumasModel

Successful minimization:                true

Likelihood approximation:  Pumas.NaivePooled
Deviance:                            4.46091
Total number of observation records:       2
Number of active observation records:      2
Number of subjects:                        1

----------------
       Estimate
----------------
θ₁      0.1305
Ω₁      0.0
Σ       0.1
----------------
"""

  infer_constantcoef = infer(fitone_constantcoef)
  @test sprint((io, t) -> show(io, MIME"text/plain"(), t), infer_constantcoef) ==
"""FittedPumasModelInference

Successful minimization:                true

Likelihood approximation:  Pumas.NaivePooled
Deviance:                            4.46091
Total number of observation records:       2
Number of active observation records:      2
Number of subjects:                        1

----------------------------------------------------------
      Estimate           SE                   95.0% C.I.
----------------------------------------------------------
θ₁     0.1305          0.00010387       [0.13029; 0.1307]
Ω₁     0.0             NaN              [ NaN   ;  NaN    ]
Σ      0.1             NaN              [ NaN   ;  NaN    ]
----------------------------------------------------------
"""

  fitone_omegas = fit(mdsl1, first(data), param; omegas=(:Ω,))
  @test sprint((io, t) -> show(io, MIME"text/plain"(), t), fitone_omegas) ==
"""FittedPumasModel

Successful minimization:                true

Likelihood approximation:  Pumas.NaivePooled
Deviance:                            4.46091
Total number of observation records:       2
Number of active observation records:      2
Number of subjects:                        1

------------------
         Estimate
------------------
θ₁        0.1305
Ω₁,₁      0.0
Σ         0.1
------------------
"""
  infer_omegas = infer(fitone_omegas)
  @test sprint((io, t) -> show(io, MIME"text/plain"(), t), infer_omegas) ==
"""FittedPumasModelInference

Successful minimization:                true

Likelihood approximation:  Pumas.NaivePooled
Deviance:                            4.46091
Total number of observation records:       2
Number of active observation records:      2
Number of subjects:                        1

------------------------------------------------------------
        Estimate           SE                   95.0% C.I.
------------------------------------------------------------
θ₁       0.1305          0.00010387       [0.13029; 0.1307]
Ω₁,₁     0.0             NaN              [ NaN   ;  NaN    ]
Σ        0.1             NaN              [ NaN   ;  NaN    ]
------------------------------------------------------------
"""

  param = init_param(mdsl1full)
  fitone_constantcoef = fit(mdsl1full, first(data), param; constantcoef=(Ω=[0.0],))
  @test sprint((io, t) -> show(io, MIME"text/plain"(), t), fitone_constantcoef) ==
"""FittedPumasModel

Successful minimization:                true

Likelihood approximation:  Pumas.NaivePooled
Deviance:                            4.46091
Total number of observation records:       2
Number of active observation records:      2
Number of subjects:                        1

----------------
       Estimate
----------------
θ₁      0.1305
Ω₁      0.0
Σ       0.1
----------------
"""
  infer_constantcoef = infer(fitone_constantcoef)
  @test sprint((io, t) -> show(io, MIME"text/plain"(), t), infer_constantcoef) ==
"""FittedPumasModelInference

Successful minimization:                true

Likelihood approximation:  Pumas.NaivePooled
Deviance:                            4.46091
Total number of observation records:       2
Number of active observation records:      2
Number of subjects:                        1

----------------------------------------------------------
      Estimate           SE                   95.0% C.I.
----------------------------------------------------------
θ₁     0.1305          0.00010387       [0.13029; 0.1307]
Ω₁     0.0             NaN              [ NaN   ;  NaN    ]
Σ      0.1             NaN              [ NaN   ;  NaN    ]
----------------------------------------------------------
"""

  fitone_omegas = fit(mdsl1full, first(data), param; omegas=(:Ω,))
  @test sprint((io, t) -> show(io, MIME"text/plain"(), t), fitone_omegas) ==
"""FittedPumasModel

Successful minimization:                true

Likelihood approximation:  Pumas.NaivePooled
Deviance:                            4.46091
Total number of observation records:       2
Number of active observation records:      2
Number of subjects:                        1

----------------
       Estimate
----------------
θ₁      0.1305
Ω₁      0.0
Σ       0.1
----------------
"""
  infer_omegas = infer(fitone_omegas)
  @test sprint((io, t) -> show(io, MIME"text/plain"(), t), infer_omegas) ==
"""FittedPumasModelInference

Successful minimization:                true

Likelihood approximation:  Pumas.NaivePooled
Deviance:                            4.46091
Total number of observation records:       2
Number of active observation records:      2
Number of subjects:                        1

----------------------------------------------------------
      Estimate           SE                   95.0% C.I.
----------------------------------------------------------
θ₁     0.1305          0.00010387       [0.13029; 0.1307]
Ω₁     0.0             NaN              [ NaN   ;  NaN    ]
Σ      0.1             NaN              [ NaN   ;  NaN    ]
----------------------------------------------------------
"""
end
