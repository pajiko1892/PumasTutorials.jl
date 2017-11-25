function simulate(_prob::ODEProblem,set_parameters,θ,ω,data::Population,
                  output_reduction = (sol,p,datai) -> (sol,false),
                  ϵ = nothing, error_model = nothing,
                  alg = Tsit5();parallel_type=:threads,kwargs...)

  N = length(data)
  η = generate_η(ω,N)

  p1 = set_parameters(θ,η[1],data[1].z)
  wrapped_f = DiffEqWrapper(_prob,p1)
  prob = ODEProblem(wrapped_f,_prob.u0,_prob.tspan,callback=ith_patient_cb(data[1]))
  tstops = [prob.tspan[1];get_all_event_times(data)] # uses tstops on all, could be by individual

  prob_func = function (prob,i,repeat)
    # From problem_new_parameters but no callbacks
    f = DiffEqWrapper(prob.f,set_parameters(θ,η[i],data[i].z))
    uEltype = eltype(θ)
    u0 = [uEltype(prob.u0[i]) for i in 1:length(prob.u0)]
    tspan = (uEltype(prob.tspan[1]),uEltype(prob.tspan[2]))
    ODEProblem(f,u0,tspan,callback=ith_patient_cb(data[i]))
  end
  output_func = function (sol,i)
    output_reduction(sol,sol.prob.f.params,data[i])
  end
  monte_prob = MonteCarloProblem(prob,prob_func=prob_func,output_func=output_func)
  sol = solve(monte_prob,alg;num_monte=N,save_start=false,
              tstops=tstops,parallel_type=parallel_type,kwargs...)
  if error_model != nothing
    err_sol = [error_model(soli,η,rand(ϵ,length(soli))) for soli in sol]
  else
    err_sol = sol
  end
  err_sol
end

function simulate(_prob::ODEProblem,set_parameters,θ,ηi,datai::Person,
                  output_reduction = (sol,p,datai) -> (sol,false),
                  ϵ = nothing, error_model = nothing,
                  alg = Tsit5();kwargs...)
  tstops = [_prob.tspan[1];datai.event_times]
  # From problem_new_parameters but no callbacks
  true_f = DiffEqWrapper(_prob,set_parameters(θ,ηi,datai.z))
  prob = ODEProblem(true_f,_prob.u0,_prob.tspan,callback=ith_patient_cb(datai))
  sol = solve(prob,alg;save_start=false,tstops=tstops,kwargs...)
  soli = first(output_reduction(sol,sol.prob.f.params,datai))
  if error_model != nothing
    _ϵ = rand(ϵ,length(soli))
    err_sol = error_model(soli,ηi,_ϵ)
  else
    err_sol = soli
  end
  err_sol
end

function ith_patient_cb(datai)
    d_n = datai.events
    target_time = datai.event_times
    condition = (t,u,integrator) -> t ∈ target_time
    counter = 1
    function affect!(integrator)
      cur_ev = datai.events[counter]
      if cur_ev.evid == 1 || cur_ev.evid == -1
        if cur_ev.rate == 0
          integrator.u[cur_ev.cmt] = cur_ev.amt
        else
          integrator.f.rates_on[] += cur_ev.evid > 0
          integrator.f.rates[cur_ev.cmt] += cur_ev.rate
        end
      end
      counter += 1
    end
    DiscreteCallback(condition, affect!, initialize = patient_cb_initialize!)
end

function patient_cb_initialize!(cb,t,u,integrator)
  if cb.condition(t,u,integrator)
    cb.affect!(integrator)
  end
end

function get_all_event_times(data)
  total_times = copy(data[1].event_times)
  for i in 2:length(data)
    for t in data[i].event_times
      t ∉ total_times && push!(total_times,t)
    end
  end
  total_times
end

struct DiffEqWrapper{F,P,rateType} <: Function
  f::F
  params::P
  rates_on::Ref{Int}
  rates::Vector{rateType}
end
function (f::DiffEqWrapper)(t,u)
  out = f.f(t,u,f.params)
  if f.rates_on[] > 0
    return out + rates
  else
    return out
  end
end
function (f::DiffEqWrapper)(t,u,du)
  f.f(t,u,f.params,du)
  f.rates_on[] > 0 && (du .+= f.rates)
end
DiffEqWrapper(prob,p) = DiffEqWrapper(prob.f,p,Ref(0),zeros(prob.u0))
DiffEqWrapper(f::DiffEqWrapper,p) = DiffEqWrapper(f.f,p,Ref(0),f.rates)
