# Copyright (c) 2016-2017 The Switch Authors. All rights reserved.
# Licensed under the Apache License, Version 2.0, which is in the LICENSE file.

"""
This module defines CSP+TES technologies. It builds on top of generic
generators, adding components for deciding how much to build, when to 
charge and discharge, energy accounting, etc.
"""

from pyomo.environ import *
import os, collections
from switch_model.financials import capital_recovery_factor as crf

dependencies = 'switch_model.timescales', 'switch_model.balancing.load_zones',\
    'switch_model.financials', 'switch_model.energy_sources.properties', \
    'switch_model.generators.core.build', 'switch_model.generators.core.dispatch'

def define_components(mod):
    """
    
    STORAGE_GENS is the subset of projects that can provide energy storage.

    STORAGE_GEN_BLD_YRS is the subset of GEN_BLD_YRS, restricted
    to storage projects.

    gen_storage_efficiency[STORAGE_GENS] describes the round trip
    efficiency of a storage technology. A storage technology that is 75
    percent efficient would have a storage_efficiency of .75. If 1 MWh
    was stored in such a storage project, 750 kWh would be available for
    extraction later. Internal leakage or energy dissipation of storage
    technologies is assumed to be neglible, which is consistent with
    short-duration storage technologies currently on the market which
    tend to consume stored power within 1 day. If a given storage
    technology has significant internal discharge when it stores power
    for extended time perios, then those behaviors will need to be
    modeled in more detail.

    gen_store_to_release_ratio[STORAGE_GENS] describes the maximum rate
    that energy can be stored, expressed as a ratio of discharge power
    capacity. This is an optional parameter and will default to 1. If a
    storage project has 1 MW of dischage capacity and a max_store_rate
    of 1.2, then it can consume up to 1.2 MW of power while charging.

    gen_storage_energy_overnight_cost[(g, bld_yr) in
    STORAGE_GEN_BLD_YRS] is the overnight capital cost per MWh of
    energy capacity for building the given storage technology installed in the
    given investment period. This is only defined for storage technologies.
    Note that this describes the energy component and the overnight_cost
    describes the power component.
    
    BuildStorageEnergy[(g, bld_yr) in STORAGE_GEN_BLD_YRS]
    is a decision of how much energy capacity to build onto a storage
    project. This is analogous to BuildGen, but for energy rather than power.
    
    StorageEnergyInstallCosts[PERIODS] is an expression of the
    annual costs incurred by the BuildStorageEnergy decision.
    
    StorageEnergyCapacity[g, period] is an expression describing the
    cumulative available energy capacity of BuildStorageEnergy. This is
    analogous to GenCapacity.
    
    STORAGE_GEN_TPS is the subset of GEN_TPS,
    restricted to storage projects.

    ChargeStorage[(g, t) in STORAGE_GEN_TPS] is a dispatch
    decision of how much to charge a storage project in each timepoint.
    
    StorageNetCharge[LOAD_ZONE, TIMEPOINT] is an expression describing the
    aggregate impact of ChargeStorage in each load zone and timepoint.
    
    Charge_Storage_Upper_Limit[(g, t) in STORAGE_GEN_TPS]
    constrains ChargeStorage to available power capacity (accounting for
    gen_store_to_release_ratio)
    
    StateOfCharge[(g, t) in STORAGE_GEN_TPS] is a variable
    for tracking state of charge. This value stores the state of charge at
    the end of each timepoint for each storage project.
    
    Track_State_Of_Charge[(g, t) in STORAGE_GEN_TPS] constrains
    StateOfCharge based on the StateOfCharge in the previous timepoint,
    ChargeStorage and DispatchGen.
    
    State_Of_Charge_Upper_Limit[(g, t) in STORAGE_GEN_TPS]
    constrains StateOfCharge based on installed energy capacity.

    """
    mod.CSP_GENS = Set(within=mod.GENERATION_PROJECTS)

### PARAMETERS    
#   efficiency in the heat exchager between the solar field (sf) and the thermal
#   energy storage (tes) (parabolic trough CSP technology) 
    mod.csp_sf_tes_efficiency = Param(
        mod.CSP_GENS,
        within=PercentFraction,
        default=1.0)

#   efficiency in the (tes) associated to heat losses 
    mod.csp_tes_efficiency = Param(
        mod.CSP_GENS,
        within=PercentFraction)

#   efficiency in the heat exchager between the tes and the circuit before the
#   power block (pb) (parabolic trough CSP technology) 
    mod.csp_tes_pb_efficiency = Param(
        mod.CSP_GENS,
        within=PercentFraction,
        default=1.0)    

#   efficiency in the heat exchager between the molten salts/oil circuit and the pb
    mod.csp_sf_tes_pb_efficiency = Param(
        mod.CSP_GENS,
        within=PercentFraction)

#   efficiency of the pb
    mod.csp_pb_efficiency = Param(
        mod.CSP_GENS,
        within=PercentFraction)

#   cumulative charge upper and lower bounds (in thermal mwh)
    mod.csp_tes_capacity_upper_mwht = Param(
        mod.CSP_GENS,
        within=NonNegativeReals)
#    mod.csp_tes_capacity_lower_mwht = Param(
#        mod.CSP_GENS, mod.TIMEPOINTS,
#        within=NonNegativeReals)

    mod.CSP_GEN_TPS = Set(
        dimen=2,
        initialize=lambda m: (
            (g, tp) 
                for g in m.CSP_GENS
                    for tp in m.TPS_FOR_GEN[g]))
    
    mod.CSP_GEN_TS = Set(
            dimen=2,
            initialize=lambda m: (
                (g, tp) for g in m.CSP_GENS for tp in m.TS_FOR_GEN[g]
            ),
        )

#   thermal power delivered by solar field (in thermal mw)
    mod.csp_sf_power_output_mwt = Param(
        mod.CSP_GEN_TPS,
        within=NonNegativeReals)
    mod.min_data_check('csp_sf_power_output_mwt')


### VARIABLES

#       Thermal power balance equation
    mod.ExcessPower = Var(
        mod.CSP_GEN_TPS,
        within=NonNegativeReals)
    
#   Charge TES
    mod.ChargeTESCSP = Var(
        mod.CSP_GEN_TPS,
        within=NonNegativeReals)

    def Charge_TESCSP_Upper_Limit_rule(m, g, t):
        return m.ChargeTESCSP[g, t] <= \
            m.csp_sf_power_output_mwt[g, t]*m.GenCapacityInTP[g, t]/(m.csp_tes_pb_efficiency[g]*m.csp_pb_efficiency[g]*m.csp_tes_efficiency[g])

    mod.Charge_TESCSP_Upper_Limit = Constraint(
        mod.CSP_GEN_TPS,
        rule=Charge_TESCSP_Upper_Limit_rule)
    
    def Charge_TESCSP_Upper_Limit_rule2(m, g, t):
        return m.ChargeTESCSP[g, t]/m.csp_sf_tes_efficiency[g] + m.ExcessPower[g, t] <= m.csp_sf_power_output_mwt[g, t]*m.GenCapacityInTP[g, t]/(m.csp_sf_tes_efficiency[g]*m.csp_tes_pb_efficiency[g]*m.csp_pb_efficiency[g]*m.csp_tes_efficiency[g])

    mod.Charge_TESCSP_Upper_Limit2 = Constraint(
        mod.CSP_GEN_TPS,
        rule=Charge_TESCSP_Upper_Limit_rule2)
    
    def Excesspower_TESCSP_Upper_Limit_rule(m, g, t):
        return m.ExcessPower[g, t]*m.csp_sf_tes_pb_efficiency[g] <= m.DispatchGen[g, t]/m.csp_pb_efficiency[g]

    mod.Excesspower_TESCSP_Upper_Limit = Constraint(
        mod.CSP_GEN_TPS,
        rule=Excesspower_TESCSP_Upper_Limit_rule)

#   Discharge TES new way to model CSP
    mod.DisChargeTESCSP = Var(
        mod.CSP_GEN_TPS, within=NonNegativeReals)
    
    def Discharge_TESCSP_Upper_Limit_rule(m, g, t):
        return m.DisChargeTESCSP[g, t]*m.csp_tes_pb_efficiency[g] + m.ExcessPower[g, t]*m.csp_sf_tes_pb_efficiency[g] == m.DispatchGen[g, t]/m.csp_pb_efficiency[g]
    
    mod.Discharge_TESCSP_Upper_Limit = Constraint(
        mod.CSP_GEN_TPS,
        rule=Discharge_TESCSP_Upper_Limit_rule)
    
    def Discharge_TESCSP_Upper_Limit_rule2(m, g, t):
        return m.DisChargeTESCSP[g, t]*m.csp_tes_pb_efficiency[g] <= m.DispatchGen[g, t]/m.csp_pb_efficiency[g]
    
    mod.Discharge_TESCSP_Upper_Limit2 = Constraint(
        mod.CSP_GEN_TPS,
        rule=Discharge_TESCSP_Upper_Limit_rule2)
    
    def Discharge_TESCSP_Upper_Limit_rule3(m, g, t):
        return m.ExcessPower[g, t]*m.csp_sf_tes_pb_efficiency[g] <= m.DispatchGen[g, t]/m.csp_pb_efficiency[g]
    
    mod.Discharge_TESCSP_Upper_Limit3 = Constraint(
        mod.CSP_GEN_TPS,
        rule=Discharge_TESCSP_Upper_Limit_rule3)
    
    # si no funciona así, eliminar esto, y dejar discharge CSP-TES como una expresión y no una variable. 
    # eliminando excessPower
    # def Thermal_Power_Balance_rule(m, g, t):
    #     return m.csp_sf_power_output_mwt[g, t]*m.GenCapacityInTP[g, t]/(m.csp_sf_tes_pb_efficiency[g]*m.csp_tes_pb_efficiency[g]*m.csp_pb_efficiency[g]*m.csp_tes_efficiency[g]) == \
    #         m.DispatchGen[g, t]/(m.csp_pb_efficiency[g]*m.csp_sf_tes_pb_efficiency[g]) + \
    #         m.ChargeTESCSP[g, t]/m.csp_sf_tes_efficiency[g] - \
    #         m.DisChargeTESCSP[g, t]*m.csp_tes_pb_efficiency[g] + \
    #         m.ExcessPower[g, t]

    # mod.Thermal_Power_Balance = Constraint(
    #     mod.CSP_GEN_TPS,
    #     rule=Thermal_Power_Balance_rule)
    
    # csp_sf_power_output_mwt new limitation
#     mod.csp_direct_gen_MW = Expression(
#     mod.CSP_GEN_TPS,
#     rule=lambda m, g, t: (
#         m.csp_sf_power_output_mwt[g,t] > 0
#         and m.csp_sf_power_output_mwt[g,t]*m.GenCapacityInTP[g, t] / (
#             m.csp_sf_power_output_mwt[g,t] * m.csp_tes_pb_efficiency[g] * 
#             m.csp_sf_tes_efficiency[g] * m.csp_pb_efficiency[g]
#         )
#     ) or 0
# )

#   State of charge      
    mod.TESCSP_StateOfCharge = Var(
        mod.CSP_GEN_TPS,
        within=NonNegativeReals)

    def Track_TESCSP_State_Of_Charge_rule(m, g, t):
        # impose TES_State_Of_Charge = 0 at the first timepoint
        if t == m.TPS_IN_PERIOD[m.tp_period[t]].first():
            return m.TESCSP_StateOfCharge[g, t] == 0
        else:
            return m.TESCSP_StateOfCharge[g, t] == \
                m.TESCSP_StateOfCharge[g, m.tp_previous[t]]*m.csp_tes_efficiency[g] + \
                (m.ChargeTESCSP[g, m.tp_previous[t]] - m.DisChargeTESCSP[g, m.tp_previous[t]]) * \
                m.tp_duration_hrs[t]

    mod.Track_TESCSP_State_Of_Charge = Constraint(
        mod.CSP_GEN_TPS,
        rule=Track_TESCSP_State_Of_Charge_rule)
    
    mod.Track_TESCSP_State_Of_Charge2 = Constraint(
        mod.CSP_GEN_TS,
        rule=lambda m, g, ts: 
            m.TESCSP_StateOfCharge[g, m.TPS_IN_TS[ts].at(1)] == m.TESCSP_StateOfCharge[g, m.TPS_IN_TS[ts].at(24)]
        )

#   Dummy penalty for excess power. 0.01 dollar if total excess power is different from 0
    # def Excess_Power_Cost_rule(m, t):
    #     ExcessPowerSum = 0
    #     for g in m.CSP_GENS:
    #         ExcessPowerSum += m.ExcessPower[g, t]*0
    #         ExcessPowerSum += m.ExcessPower[g, t]*(10**-8)
    #     return ExcessPowerSum

    # mod.ExcessPowerCost = Expression(
    #     mod.TIMEPOINTS,
    #     rule=Excess_Power_Cost_rule)

    # mod.Cost_Components_Per_TP.append('ExcessPowerCost')

    def TESCSP_State_Of_Charge_Upper_Limit_rule(m, g, t):
        return m.TESCSP_StateOfCharge[g, t] <= \
            m.csp_tes_capacity_upper_mwht[g]*m.GenCapacityInTP[g, t]/(m.csp_tes_pb_efficiency[g]*m.csp_pb_efficiency[g])

    mod.TESCSP_State_Of_Charge_Upper_Limit = Constraint(
        mod.CSP_GEN_TPS,
        rule=TESCSP_State_Of_Charge_Upper_Limit_rule)
        

def load_inputs(mod, switch_data, inputs_dir):
    """

    Import CSP parameters. Optional columns are noted with a *.

    gen_info.csv
        GENERATION_PROJECT, ...
        csp_sf_tes_efficiency*, 
        csp_tes_efficiency,
        csp_tes_pb_efficiency*,
        csp_sf_tes_pb_efficiency,
        csp_pb_efficiency,
        csp_tes_capacity_upper_mwht,

    csp_sf_power_output.tab
        GENERATION_PROJECT, timepoint, csp_sf_power_output_mwt

    """
 
    switch_data.load_aug(
        filename=os.path.join(inputs_dir, 'gen_info.csv'),
        auto_select=True,
        optional_params=['csp_sf_tes_efficiency', 'csp_tes_pb_efficiency'],
        index=mod.GENERATION_PROJECTS,
        param=(mod.csp_sf_tes_efficiency,
               mod.csp_tes_efficiency,
               mod.csp_tes_pb_efficiency,
               mod.csp_sf_tes_pb_efficiency,
               mod.csp_pb_efficiency,
               mod.csp_tes_capacity_upper_mwht))
    # Base the set of storage projects on storage efficiency being specified.
    switch_data.data()['CSP_GENS'] = {
        None: switch_data.data(name='csp_tes_capacity_upper_mwht').keys()}
    switch_data.load_aug(
        filename=os.path.join(inputs_dir, 'sf_power_output.csv'),
        auto_select=True,
        index=mod.CSP_GEN_TPS,
        param=(mod.csp_sf_power_output_mwt))


def post_solve(instance, outdir):
    """
    Export CSP dispatch info to csp_dispatch.txt
    """
    import switch_model.reporting as reporting
    reporting.write_table(
        instance, instance.CSP_GEN_TPS,
        output_file=os.path.join(outdir, "csp_dispatch.txt"),
        headings=("project", "timepoint", "load_zone", 
                  "SF_Power_Output_MWt",
                  "ChargeTESCSP_MWt", "DisChargeTESCSP_MWt",
                  "TESCSP_StateOfCharge_MWht", "PB_Power_MWt",
                  "Excess_Power", "Dispatch_MW"),
#                  "Excess_Power_Cost"),
        values=lambda m, g, t: (
            g, m.tp_timestamp[t], m.gen_load_zone[g],
            m.csp_sf_power_output_mwt[g, t],
            m.ChargeTESCSP[g, t], m.DisChargeTESCSP[g, t],
            m.TESCSP_StateOfCharge[g, t], m.DispatchGen[g, t]/m.csp_pb_efficiency[g] ,
            m.ExcessPower[g, t], m.DispatchGen[g, t]))#,
#            m.ExcessPowerCost[t]))
