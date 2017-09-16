using PKPDSimulator


# Gut dosing model:
using ParameterizedFunctions
f = @ode_def_nohes GutDose begin
  dGut = -Ka*Gut
  dCent = Ka*Gut - (CL/V)*Cent
end Ka=>1.5 CL=>1.0 V=>30.0 LAGT=>0, MODE=>0, DUR2=>2, RAT2=>10, BIOAV=>1


function set_parameters!(p,u0,θ,η,zi)
  F_Cent =  BIOAV
  ALAG_CENT = LAGT
  if MODE==1
    R_CENT = RAT2
  if MODE==2
    D_CENT = DUR2
  Ka = θ[1]
  CL = θ[2]
  V  = θ[3]
  p[1] = Ka; p[2] = CL; p[3] = V
end


function getsol(model,tstart=0,tend=72,num_dv=1)
    tspan = (tsart,tend)
    num_dependent = num_dv
    sol  = simulate(f=model,tspan,num_dependent,set_parameters!,θ,ω,z)
    # todo: implement output function to derive concentrations at everytime point
    # by dividing the sol by the volume V
end

# ev1 - gut dose - use ev1.csv in PKPDSimulator/examples/event_data/
# amt=100: 100 mg dose into gut compartment
# cmt=1: in the system of diffeq's, gut compartment is the first compartment
# addl=3: 4 doses total, 1 dose at time zero + 3 additional doses (addl=3)
# ii=12: each additional dose is given with a frequency of ii=12 hours
# evid = 1: indicates a dosing event
# mdv = 1: indicates that observations are not avaialable at this dosing record


θ = [ 
     1.5,  #Ka
     1.0,  #CL
     30.0, #V
     0,    #LAGT
     0,    #MODE
     2,    #DUR2
     10,   #RAT2
     1     #BIOAV
]

# corresponding mrgsolve and NONMEM solution in data1.csv in PKPDSimulator/examples/event_data/
sol = getsol(model=f,num_dv=2) # get both gut and central amounts and concentrations amt/V


# ev2 - infusion into the central compartment - use ev2.csv in PKPDSimulator/examples/event_data/
# amt=100: 100 mg infusion into central compartment

# new
# cmt=2: in the system of diffeq's, central compartment is the second compartment

# new
# rate=10: the dose is given at a rate of amt/time (mg/hr), i.e, 10mg/hr. In this example the 100mg amount
# is given over a duration (DUR) of 10 hours

# addl=3: 4 doses total, 1 dose at time zero + 3 additional doses (addl=3)
# ii=12: each additional dose is given with a frequency of ii=12 hours
# evid = 1: indicates a dosing event
# mdv = 1: indicates that observations are not avaialable at this dosing record


θ = [ 
    1.5,  #Ka
    1.0,  #CL
    30.0, #V
    0,    #LAGT
    0,    #MODE
    2,    #DUR2
    10,   #RAT2
    1     #BIOAV
]

# corresponding mrgsolve and NONMEM solution in data2.csv in PKPDSimulator/examples/event_data/
sol = getsol(model=f,num_dv=1) # get central amounts  and concentrations amt/V


# ev3 - infusion into the central compartment with lag time 
# - use ev3.csv in PKPDSimulator/examples/event_data/
# amt=100: 100 mg infusion into central compartment
# cmt=2: in the system of diffeq's, central compartment is the second compartment
# rate=10: the dose is given at a rate of amt/time (mg/hr), i.e, 10mg/hr. In this example the 100mg amount
# is given over a duration (DUR) of 10 hours

# new
# LAGT=5: there is a lag of 5 hours after dose administration when amounts from the event
# are populated into the central compartment. Requires developing a new internal variable called 
# ALAG_<comp name> or ALAG_<comp_num> that takes a time value by which the entry of dose into that compartment
# is delayed

# addl=3: 4 doses total, 1 dose at time zero + 3 additional doses (addl=3)
# ii=12: each additional dose is given with a frequency of ii=12 hours
# evid = 1: indicates a dosing event
# mdv = 1: indicates that observations are not avaialable at this dosing record


θ = [ 
    1.5,  #Ka
    1.0,  #CL
    30.0, #V
    5,    #LAGT
    0,    #MODE
    2,    #DUR2
    10,   #RAT2
    1     #BIOAV
]

# corresponding mrgsolve and NONMEM solution in data3.csv in PKPDSimulator/examples/event_data/
sol = getsol(model=f,num_dv=1) # get central amounts  and concentrations amt/V


# ev4 - infusion into the central compartment with lag time and bioavailability 
# - use ev4.csv in PKPDSimulator/examples/event_data/
# amt=100: 100 mg infusion into central compartment
# cmt=2: in the system of diffeq's, central compartment is the second compartment
# rate=10: the dose is given at a rate of amt/time (mg/hr), i.e, 10mg/hr. In this example the 100mg amount
# is given over a duration (DUR) of 10 hours
# LAGT=5: there is a lag of 5 hours after dose administration when amounts from the event
# are populated into the central compartment. Requires developing a new internal variable called 
# ALAG_<comp name> or ALAG_<comp_num> that takes a value that delays the entry of dose into that compartment

#new
# BIOAV=0.412: required developing a new internal variable called F_<comp name> or F_<comp num>,
# where F is the fraction of amount that is delivered into the compartment. e.g. in this case, 
# only 41.2 % of the 100 mg dose is administered at the 10mg/hr rate will enter the system.
# F_<comp> is one of the most commonly estimated parameters in NLME

# addl=3: 4 doses total, 1 dose at time zero + 3 additional doses (addl=3)
# ii=12: each additional dose is given with a frequency of ii=12 hours
# evid = 1: indicates a dosing event
# mdv = 1: indicates that observations are not avaialable at this dosing record


θ = [ 
    1.5,  #Ka
    1.0,  #CL
    30.0, #V
    5,    #LAGT
    0,    #MODE
    2,    #DUR2
    10,   #RAT2
    0.412 #BIOAV
]

# corresponding mrgsolve and NONMEM solution in data4.csv in PKPDSimulator/examples/event_data/
sol = getsol(model=f,num_dv=1) # get central amounts  and concentrations amt/V


# ev5 - infusion into the central compartment at steady state (ss) 
# - use ev5.csv in PKPDSimulator/examples/event_data/
# amt=100: 100 mg infusion into central compartment
# cmt=2: in the system of diffeq's, central compartment is the second compartment
# rate=10: the dose is given at a rate of amt/time (mg/hr), i.e, 10mg/hr. In this example the 100mg amount
# is given over a duration (DUR) of 10 hours
# BIOAV=0.412: required developing a new internal variable called F_<comp name> or F_<comp num>,
# where F is the fraction of amount that is delivered into the compartment. e.g. in this case, 
# only 41.2 % of the 100 mg dose is administered at the 10mg/hr rate will enter the system.
# F_<comp> is one of the most commonly estimated parameters in NLME

#new
#ss=1:  indicates that the dose is a steady state dose, and that the compartment amounts are to be reset 
#to the steady-state amounts resulting from the given dose. Compartment amounts resulting from prior 
#dose event records are "zeroed out," and infusions in progress or pending additional doses are cancelled

# addl=3: 4 doses total, 1 dose at time zero + 3 additional doses (addl=3)
# ii=12: each additional dose is given with a frequency of ii=12 hours
# evid = 1: indicates a dosing event
# mdv = 1: indicates that observations are not avaialable at this dosing record


θ = [ 
    1.5,  #Ka
    1.0,  #CL
    30.0, #V
    0,    #LAGT
    0,    #MODE
    2,    #DUR2
    10,   #RAT2
    0.412,#BIOAV
    1     #ss
]

# corresponding mrgsolve and NONMEM solution in data5.csv in PKPDSimulator/examples/event_data/
sol = getsol(model=f,num_dv=1) # get central amounts  and concentrations amt/V

# ev6 - infusion into the central compartment at steady state (ss), where frequency of events (ii) is less 
# than the infusion duration (DUR)
# - use ev6.csv in PKPDSimulator/examples/event_data/
# amt=100: 100 mg infusion into central compartment
# cmt=2: in the system of diffeq's, central compartment is the second compartment
# rate=10: the dose is given at a rate of amt/time (mg/hr), i.e, 10mg/hr. In this example the 100mg amount
# is given over a duration (DUR) of 10 hours

#new
# BIOAV=0.812: required developing a new internal variable called F_<comp name> or F_<comp num>,
# where F is the fraction of amount that is delivered into the compartment. e.g. in this case, 
# only 81.2 % of the 100 mg dose is administered at the 10mg/hr rate will enter the system.
# F_<comp> is one of the most commonly estimated parameters in NLME

#ss=1:  indicates that the dose is a steady state dose, and that the compartment amounts are to be reset 
#to the steady-state amounts resulting from the given dose. Compartment amounts resulting from prior 
#dose event records are "zeroed out," and infusions in progress or pending additional doses are cancelled
# addl=3: 4 doses total, 1 dose at time zero + 3 additional doses (addl=3)

#new
# ii=6: each additional dose is given with a frequency of ii=6 hours

# evid = 1: indicates a dosing event
# mdv = 1: indicates that observations are not avaialable at this dosing record


θ = [ 
    1.5,  #Ka
    1.0,  #CL
    30.0, #V
    0,    #LAGT
    0,    #MODE
    2,    #DUR2
    10,   #RAT2
    0.812,#BIOAV
    1     #ss
]

# corresponding mrgsolve and NONMEM solution in data6.csv in PKPDSimulator/examples/event_data/
sol = getsol(model=f,num_dv=1) # get central amounts  and concentrations amt/V


# ev7 - infusion into the central compartment at steady state (ss), where frequency of events (ii) is less 
# than the infusion duration (DUR)
# - use ev7.csv in PKPDSimulator/examples/event_data/
# amt=100: 100 mg infusion into central compartment
# cmt=2: in the system of diffeq's, central compartment is the second compartment
# rate=10: the dose is given at a rate of amt/time (mg/hr), i.e, 10mg/hr. In this example the 100mg amount
# is given over a duration (DUR) of 10 hours

#new
# BIOAV=1: required developing a new internal variable called F_<comp name> or F_<comp num>,
# where F is the fraction of amount that is delivered into the compartment. e.g. in this case, 
# only 81.2 % of the 100 mg dose is administered at the 10mg/hr rate will enter the system.
# F_<comp> is one of the most commonly estimated parameters in NLME

#ss=1:  indicates that the dose is a steady state dose, and that the compartment amounts are to be reset 
#to the steady-state amounts resulting from the given dose. Compartment amounts resulting from prior 
#dose event records are "zeroed out," and infusions in progress or pending additional doses are cancelled
# addl=3: 4 doses total, 1 dose at time zero + 3 additional doses (addl=3)

#new
# ii=6: each additional dose is given with a frequency of ii=6 hours

# evid = 1: indicates a dosing event
# mdv = 1: indicates that observations are not avaialable at this dosing record


θ = [ 
    1.5,  #Ka
    1.0,  #CL
    30.0, #V
    0,    #LAGT
    0,    #MODE
    2,    #DUR2
    10,   #RAT2
    1,    #BIOAV
    1     #ss
]

# corresponding mrgsolve and NONMEM solution in data7.csv in PKPDSimulator/examples/event_data/
sol = getsol(model=f,num_dv=1) # get central amounts  and concentrations amt/V

# ev8 - infusion into the central compartment at steady state (ss), where frequency of events (ii) is a 
# multiple of infusion duration (DUR)
# - use ev8.csv in PKPDSimulator/examples/event_data/
# amt=100: 100 mg infusion into central compartment
# cmt=2: in the system of diffeq's, central compartment is the second compartment

#new
# rate=8.33333: the dose is given at a rate of amt/time (mg/hr), i.e, 8.333333mg/hr. In this example the 100mg amount
# is given over a duration (DUR) of 12 hours


# BIOAV=1: required developing a new internal variable called F_<comp name> or F_<comp num>,
# where F is the fraction of amount that is delivered into the compartment. e.g. in this case, 
# only 81.2 % of the 100 mg dose is administered at the 10mg/hr rate will enter the system.
# F_<comp> is one of the most commonly estimated parameters in NLME

#ss=1:  indicates that the dose is a steady state dose, and that the compartment amounts are to be reset 
#to the steady-state amounts resulting from the given dose. Compartment amounts resulting from prior 
#dose event records are "zeroed out," and infusions in progress or pending additional doses are cancelled
# addl=3: 4 doses total, 1 dose at time zero + 3 additional doses (addl=3)

#new
# ii=6: each additional dose is given with a frequency of ii=6 hours

# evid = 1: indicates a dosing event
# mdv = 1: indicates that observations are not avaialable at this dosing record


θ = [ 
    1.5,  #Ka
    1.0,  #CL
    30.0, #V
    0,    #LAGT
    0,    #MODE
    2,    #DUR2
    10,   #RAT2
    1,    #BIOAV
    1     #ss
]

# corresponding mrgsolve and NONMEM solution in data8.csv in PKPDSimulator/examples/event_data/
sol = getsol(model=f,num_dv=1) # get central amounts  and concentrations amt/V


# ev9 - infusion into the central compartment at steady state (ss), where frequency of events (ii) is  
# exactly equal to infusion duration (DUR)
# - use ev9.csv in PKPDSimulator/examples/event_data/
# amt=100: 100 mg infusion into central compartment
# cmt=2: in the system of diffeq's, central compartment is the second compartment

#new
# rate=10: the dose is given at a rate of amt/time (mg/hr), i.e, 10mg/hr. In this example the 100mg amount
# is given over a duration (DUR) of 10 hours

#new
# BIOAV=0.412: required developing a new internal variable called F_<comp name> or F_<comp num>,
# where F is the fraction of amount that is delivered into the compartment. e.g. in this case, 
# only 81.2 % of the 100 mg dose is administered at the 10mg/hr rate will enter the system.
# F_<comp> is one of the most commonly estimated parameters in NLME

#ss=1:  indicates that the dose is a steady state dose, and that the compartment amounts are to be reset 
#to the steady-state amounts resulting from the given dose. Compartment amounts resulting from prior 
#dose event records are "zeroed out," and infusions in progress or pending additional doses are cancelled
# addl=3: 4 doses total, 1 dose at time zero + 3 additional doses (addl=3)

#new
# ii=10: each additional dose is given with a frequency of ii=10 hours

# evid = 1: indicates a dosing event
# mdv = 1: indicates that observations are not avaialable at this dosing record


θ = [ 
    1.5,  #Ka
    1.0,  #CL
    30.0, #V
    0,    #LAGT
    0,    #MODE
    2,    #DUR2
    10,   #RAT2
    0.412,#BIOAV
    1     #ss
]

# corresponding mrgsolve and NONMEM solution in data9.csv in PKPDSimulator/examples/event_data/
sol = getsol(model=f,num_dv=1) # get central amounts  and concentrations amt/V

# ev10 - infusion into the central compartment at steady state (ss), where frequency of events (ii) is  
# exactly equal to infusion duration (DUR)
# - use ev10.csv in PKPDSimulator/examples/event_data/
# amt=100: 100 mg infusion into central compartment
# cmt=2: in the system of diffeq's, central compartment is the second compartment
# rate=10: the dose is given at a rate of amt/time (mg/hr), i.e, 10mg/hr. In this example the 100mg amount
# is given over a duration (DUR) of 10 hours

#new
# BIOAV=1: required developing a new internal variable called F_<comp name> or F_<comp num>,
# where F is the fraction of amount that is delivered into the compartment. e.g. in this case, 
# only 81.2 % of the 100 mg dose is administered at the 10mg/hr rate will enter the system.
# F_<comp> is one of the most commonly estimated parameters in NLME

#ss=1:  indicates that the dose is a steady state dose, and that the compartment amounts are to be reset 
#to the steady-state amounts resulting from the given dose. Compartment amounts resulting from prior 
#dose event records are "zeroed out," and infusions in progress or pending additional doses are cancelled
# addl=3: 4 doses total, 1 dose at time zero + 3 additional doses (addl=3)
# ii=10: each additional dose is given with a frequency of ii=10 hours

# evid = 1: indicates a dosing event
# mdv = 1: indicates that observations are not avaialable at this dosing record


θ = [ 
    1.5,  #Ka
    1.0,  #CL
    30.0, #V
    0,    #LAGT
    0,    #MODE
    2,    #DUR2
    10,   #RAT2
    1,    #BIOAV
    1     #ss
]

# corresponding mrgsolve and NONMEM solution in data10.csv in PKPDSimulator/examples/event_data/
sol = getsol(model=f,num_dv=1) # get central amounts  and concentrations amt/V