using PuMaS, LinearAlgebra, Test, CSV

@testset "One compartment intravenous bolus study" begin
  #No. of subjects= 100, Dose = 100 or 250mg,DV=Plasma concentration, ug/ml
  #Time = hrs, CL = L/hr, V=L

  pkdata = CSV.read(example_nmtran_data("event_data/CS1_IV1EST_PAR"))
  pkdata[:dv] = pkdata[:CONC]
  pkdata.CMT = 1
  data = process_nmtran(pkdata,[:AGE, :WT, :SCR, :CLCR], [:dv],
                        id=:ID, time=:TIME, amt=:AMT, evid=:MDV, cmt=:CMT)


  @testset "proportional error model" begin
    mdl_proportional = @model begin
      @param begin
        θ ∈ VectorDomain(2, lower=[0.0,0.0], upper=[20.0,20.0])
        Ω ∈ PDiagDomain(2)
        σ_prop ∈ RealDomain(lower=0.0001)
      end

      @random begin
        η ~ MvNormal(Ω)
      end

      @pre begin
        CL = θ[1] * exp(η[1])
        V = θ[2] * exp(η[2])
      end

      @vars begin
        conc = Central / V
      end

      # Using ODE solver takes a while so disabling for now
      #@dynamics begin
      #    Central' =  - (CL/V)*Central
      #end

      @dynamics ImmediateAbsorptionModel

      @derived begin
        dv ~ @. Normal(conc, conc*sqrt(σ_prop))
      end
    end

    param_proportional = (
      θ = [0.6, 10.0],
      Ω = Diagonal([0.04, 0.01]),
      σ_prop = 0.1
    )

    @testset "FOCE estimation" begin
      result = fit(mdl_proportional, data, param_proportional, PuMaS.FOCE())
      param = result.param

      @test param.θ      ≈ [3.19e-01, 9.22e+00] rtol=1e-3
      @test param.Ω.diag ≈ [2.28e-01, 2.72e-01] rtol=1e-3
      @test param.σ_prop ≈ 9.41e-02 rtol=1e-3
    end

    @testset "FOCEI estimation" begin
      result = fit(mdl_proportional, data, param_proportional, PuMaS.FOCEI())
      param = result.param

      @test param.θ      ≈ [3.91e-01, 7.56e+00] rtol=1e-3
      @test param.Ω.diag ≈ [1.60e-01, 1.68e-01] rtol=3e-3
      @test param.σ_prop ≈ 1.01e-1 rtol=1e-3
    end
  end

  @testset "proportional+additive error model" begin
    mdl_proportional_additive = @model begin
      @param begin
       θ ∈ VectorDomain(2, lower=[0.0,0.0], upper=[20.0,20.0])
       Ω ∈ PDiagDomain(2)
       σ_add ∈ RealDomain(lower=0.0001)
       σ_prop ∈ RealDomain(lower=0.0001)
      end

      @random begin
       η ~ MvNormal(Ω)
      end

      @pre begin
       CL = θ[1] * exp(η[1])
       V = θ[2] * exp(η[2])
      end

      @vars begin
       conc = Central / V
      end

      # Using ODE solver takes a while so disabling for now
      #@dynamics begin
      #    Central' =  - (CL/V)*Central
      #end

      @dynamics ImmediateAbsorptionModel

      @derived begin
       dv ~ @. Normal(conc, sqrt(conc^2*σ_prop + σ_add))
      end
    end

    param_proportional_additive = (
      θ = [0.6, 10.0],
      Ω = Diagonal([0.04, 0.01]),
      σ_add = 2.0,
      σ_prop = 0.1
    )

    @testset "FOCE estimation" begin
      result = fit(mdl_proportional_additive, data, param_proportional_additive, PuMaS.FOCE())
      param = result.param

      @test param.θ      ≈ [4.12e-01, 7.20e+00] rtol=1e-3
      @test param.Ω.diag ≈ [1.73e-01, 2.02e-01] rtol=5e-3
      @test param.σ_add  ≈ 7.32e+00 rtol=1e-3
      @test param.σ_prop ≈ 2.41e-02 rtol=1e-3
    end

    @testset "FOCEI estimation" begin
      result = fit(mdl_proportional_additive, data, param_proportional_additive, PuMaS.FOCEI())
      param = result.param

      @test param.θ      ≈ [4.17e-01, 7.16e+00] rtol=1e-3
      @test param.Ω.diag ≈ [1.71e-01, 1.98e-01] rtol=5e-3
      @test param.σ_add  ≈ 8.57e+00 rtol=1e-3
      @test param.σ_prop ≈ 1.47e-02 rtol=3e-3
    end
  end
end