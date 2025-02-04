# Copyright (c) 2016-2017 The Switch Authors. All rights reserved.
# Licensed under the Apache License, Version 2.0, which is in the LICENSE file.

"""
This module defines TES technologie. It builds on top of generic
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
    mod.TES_GENS = Set(within=mod.GENERATION_PROJECTS)

### PARAMETERS    
#   efficiency in the electric heater
    mod.gen_tes_eh_eff = Param(
        mod.TES_GENS,
        within=PercentFraction)

#   efficiency in the heat exchager between the electrical heater and the tes
    mod.gen_tes_eh_tes_eff = Param(
        mod.TES_GENS,
        within=PercentFraction,
        default=1.0)

#   efficiency in the tes couse thermal losses
    mod.gen_tes_tes_losses_eff = Param(
        mod.TES_GENS,
        within=PercentFraction)    

#   efficiency in the heat exchager between the tes and the pb
    mod.gen_tes_tes_powerblock_eff = Param(
        mod.TES_GENS,
        within=PercentFraction,
        default=1.0)

#   efficiency of the pb
    mod.gen_tes_powerblock_eff = Param(
        mod.TES_GENS,
        within=PercentFraction)

#   cumulative charge upper and lower bounds (in thermal mwh)
    mod.gen_tes_duration = Param(
        mod.TES_GENS,
        within=NonNegativeReals)
#    mod.TES_tes_capacity_lower_mwht = Param(
#        mod.TES_GENS, mod.TIMEPOINTS,
#        within=NonNegativeReals)

#   power capacity for the electric heater
    # mod.gen_tes_eh_cap = Param(
    #     mod.TES_GENS,
    #     within=NonNegativeReals)

    mod.TES_GEN_TPS = Set(
        dimen=2,
        initialize=lambda m: (
            (g, tp) 
                for g in m.TES_GENS
                    for tp in m.TPS_FOR_GEN[g]))

    mod.TES_GEN_TS = Set(
            dimen=2,
            initialize=lambda m: (
                (g, tp) for g in m.TES_GENS for tp in m.TS_FOR_GEN[g]
            ),
        )

# deleted... solar field for power input not aviable
#   thermal power delivered by solar field (in thermal mw)
    # mod.TES_sf_power_output_mwt = Param(
    #     mod.TES_GEN_TPS,
    #     within=NonNegativeReals)
    # mod.min_data_check('TES_sf_power_output_mwt')

### VARIABLES

#   Charge TES
    mod.ChargeTES = Var(
        mod.TES_GEN_TPS,
        within=NonNegativeReals)

    def Charge_TES_Upper_Limit_rule(m, g, t):        
        return m.ChargeTES[g, t] <= \
            (m.GenCapacityInTP[g, t]*m.gen_tes_eh_eff[g]*m.gen_tes_eh_tes_eff[g])            # changed: before this was limited by the power output of the sf.

    mod.Charge_TES_Upper_Limit = Constraint(
        mod.TES_GEN_TPS,
        rule=Charge_TES_Upper_Limit_rule)

    # new....
    # add withdrawals from central grid.
    # Summarize TES storage charging for the energy balance equations
    def rule(m, z, t):
        # Construct and cache a set for summation as needed
        if not hasattr(m, 'TES_Charge_Summation_dict'):
            m.TES_Charge_Summation_dict = collections.defaultdict(set)
            for g, t2 in m.TES_GEN_TPS:
                z2 = m.gen_load_zone[g]
                m.TES_Charge_Summation_dict[z2, t2].add(g)
        # Use pop to free memory
        relevant_projects = m.TES_Charge_Summation_dict.pop((z, t), {})
        return sum(m.ChargeTES[g, t]/(m.gen_tes_eh_eff[g]*m.gen_tes_eh_tes_eff[g]) for g in relevant_projects)
    mod.TESNetCharge = Expression(mod.LOAD_ZONES, mod.TIMEPOINTS, rule=rule)
    # Register net charging with zonal energy balance. Discharging is already
    # covered by DispatchGen.
    mod.Zone_Power_Withdrawals.append('TESNetCharge')

#   Discharge TES
    def Discharge_TES_Upper_Limit_rule(m, g, t):
        return (m.DispatchGen[g, t]/(m.gen_tes_powerblock_eff[g]*m.gen_tes_tes_powerblock_eff[g]))       # changed: the efficencis...
    mod.DischargeTES = Expression(
        mod.TES_GEN_TPS, rule=Discharge_TES_Upper_Limit_rule)
    

# deleted... exces power from de sf...
#   Thermal power balance equation
    # mod.ExcessPower = Var(
    #     mod.TES_GEN_TPS,
    #     within=NonNegativeReals)

#   State of charge      
    mod.TES_StateOfCharge = Var(
        mod.TES_GEN_TPS,
        within=NonNegativeReals)

    def Track_TES_State_Of_Charge_rule(m, g, t):                                            # changed: changed the name of the TES eficciency
        # impose TES_State_Of_Charge = 0 at the first timepoint
        if t == m.TPS_IN_PERIOD[m.tp_period[t]].first():
            return m.TES_StateOfCharge[g, t] == 0
        else:
            return m.TES_StateOfCharge[g, t] == \
                m.TES_StateOfCharge[g, m.tp_previous[t]]*m.gen_tes_tes_losses_eff[g] + \
                (m.ChargeTES[g, m.tp_previous[t]] - m.DischargeTES[g, m.tp_previous[t]]) * \
                m.tp_duration_hrs[t]

    mod.Track_TES_State_Of_Charge = Constraint(
        mod.TES_GEN_TPS,
        rule=Track_TES_State_Of_Charge_rule)
    
    mod.Track_TES_State_Of_Charge2 = Constraint(
        mod.TES_GEN_TS,
        rule=lambda m, g, ts: 
            m.TES_StateOfCharge[g, m.TPS_IN_TS[ts].at(1)] == m.TES_StateOfCharge[g, m.TPS_IN_TS[ts].at(24)]
        )

# deleted... excess power from de solar field
#   Dummy penalty for excess power. 0.01 dollar if total excess power is different from 0
    # def Excess_Power_Cost_rule(m, t):
    #     ExcessPowerSum = 0
    #     for g in m.TES_GENS:
    #         ExcessPowerSum += m.ExcessPower[g, t]*0
    #         ExcessPowerSum += m.ExcessPower[g, t]*(10**-8)
    #     return ExcessPowerSum

    # mod.ExcessPowerCost = Expression(
    #     mod.TIMEPOINTS,
    #     rule=Excess_Power_Cost_rule)

    # mod.Cost_Components_Per_TP.append('ExcessPowerCost')

    # def TES_State_Of_Charge_Upper_Limit_rule(m, g, t):
    #     return m.TES_StateOfCharge[g, t] <= \
    #         m.gen_tes_capacity_upper_mwht[g]
    def TES_State_Of_Charge_Upper_Limit_rule(m, g, t):
        return (m.TES_StateOfCharge[g, t] <= \
            m.GenCapacityInTP[g, t]*m.gen_tes_duration[g]/(m.gen_tes_powerblock_eff[g]*m.gen_tes_powerblock_eff[g]))

    mod.TES_State_Of_Charge_Upper_Limit = Constraint(
        mod.TES_GEN_TPS,
        rule=TES_State_Of_Charge_Upper_Limit_rule)
        

def load_inputs(mod, switch_data, inputs_dir):
    """

    Import TES parameters. Optional columns are noted with a *.

    generation_projects_info.tab
        GENERATION_PROJECT, ...
        gen_tes_eh_cap, 
        gen_tes_eh_eff,
        gen_tes_eh_tes_eff,
        gen_tes_tes_losses_eff,
        gen_tes_tes_powerblock_eff,
        gen_tes_powerblock_eff,
        gen_tes_duration,

    Eliminado: Carga de tabla con inputs de generación del solar field

    """
 
    switch_data.load_aug(
        filename=os.path.join(inputs_dir, 'gen_info.csv'),
        auto_select=True,
        index=mod.GENERATION_PROJECTS,
        param=(mod.gen_tes_eh_eff,
               mod.gen_tes_eh_tes_eff,
               mod.gen_tes_tes_losses_eff,
               mod.gen_tes_tes_powerblock_eff,
               mod.gen_tes_powerblock_eff,
               mod.gen_tes_duration))
    # Base the set of storage projects on storage efficiency being specified.
    switch_data.data()['TES_GENS'] = {
        None: switch_data.data(name='gen_tes_duration').keys()}


    
    # solar field power input (eliminar)
    # switch_data.load_aug(
    #     filename=os.path.join(inputs_dir, 'TES_sf_power_output.tab'),
    #     auto_select=True,
    #     index=mod.TES_GEN_TPS,
    #     param=(mod.TES_sf_power_output_mwt))


def post_solve(instance, outdir):
    """
    Export TES dispatch info to TES_dispatch.txt
    """
    import switch_model.reporting as reporting
    reporting.write_table(
        instance, instance.TES_GEN_TPS,
        output_file=os.path.join(outdir, "TES_dispatch.txt"),
        headings=("project", "timepoint", "load_zone", 
                  "EH_Power_in_MWt",                       # acá SF_Power_Output_MWt cambiar por la potencia retirada de la barra o eliminar.
                  "ChargeTES_MWt", "DischargeTES_MWt",
                  "TES_StateOfCharge_MWht", "PB_Power_MWt"),           # Excess power debe eliminarse...
#                  "Excess_Power_Cost"),
        values=lambda m , g, t: (
            g, m.tp_timestamp[t], m.gen_load_zone[g],
            m.ChargeTES[g, t]/(m.gen_tes_eh_eff[g]*m.gen_tes_eh_tes_eff[g]),                         # acá SF_Power_Output_MWt cambiar por la potencia retirada de la barra o eliminar
            m.ChargeTES[g, t], m.DischargeTES[g, t],
            m.TES_StateOfCharge[g, t], m.DispatchGen[g, t]))#,             # Excess power debe eliminarse...
#            m.ExcessPowerCost[t]))
