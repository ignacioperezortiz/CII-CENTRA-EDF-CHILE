# Copyright (c) 2015-2024 The Switch Authors. All rights reserved.
# Licensed under the Apache License, Version 2.0, which is in the LICENSE file.

"""
Defines simple limitations on project dispatch without considering unit
commitment. This module is mutually exclusive with the operations.unitcommit
module which constrains dispatch to unit commitment decisions.
"""

from pyomo.environ import *

dependencies = (
    "switch_model.timescales",
    "switch_model.balancing.load_zones",
    "switch_model.financials",
    "switch_model.energy_sources.properties.properties",
    "switch_model.generators.core.build",
    "switch_model.generators.core.dispatch",
)


def define_components(mod):
    """

    Adds components to a Pyomo abstract model object to constrain
    dispatch decisions subject to available capacity, renewable resource
    availability, and baseload restrictions. Unless otherwise stated,
    all power capacity is specified in units of MW and all sets and
    parameters are mandatory. This module estimates project dispatch
    limits and fuel consumption without consideration of unit
    commitment. This can be a useful approximation if fuel startup
    requirements are a small portion of overall fuel consumption, so
    that the aggregate fuel consumption with respect to energy
    production can be approximated as a line with a 0 intercept. This
    estimation method has been known to result in excessive cycling of
    Combined Cycle Gas Turbines in the Switch-WECC model.

    DispatchUpperLimit[(g, t) in GEN_TPS] is an
    expression that defines the upper bounds of dispatch subject to
    installed capacity, average expected outage rates, and renewable
    resource availability.

    DispatchLowerLimit[(g, t) in GEN_TPS] in an
    expression that defines the lower bounds of dispatch, which is 0
    except for baseload plants where is it the upper limit.

    Enforce_Dispatch_Lower_Limit[(g, t) in GEN_TPS] and
    Enforce_Dispatch_Upper_Limit[(g, t) in GEN_TPS] are
    constraints that limit DispatchGen to the upper and lower bounds
    defined above.

        DispatchLowerLimit <= DispatchGen <= DispatchUpperLimit

    GenFuelUseRate_Calculate[(g, t) in GEN_TPS]
    calculates fuel consumption for the variable GenFuelUseRate as
    DispatchGen * gen_full_load_heat_rate. The units become:
    MW * (MMBtu / MWh) = MMBTU / h

    DispatchGenByFuel[(g, t, f) in GEN_TP_FUELS]
    calculates power production by each project from each fuel during
    each timepoint.

    """

    # NOTE: DispatchBaseloadByPeriod should eventually be replaced by
    # an "ActiveCapacityDuringPeriod" decision variable that applies to all
    # projects. This should be constrained
    # based on the amount of installed capacity each period, and then
    # DispatchUpperLimit and DispatchLowerLimit should be calculated
    # relative to ActiveCapacityDuringPeriod. Fixed O&M (but not capital
    # costs) should be calculated based on ActiveCapacityDuringPeriod.
    # This would allow mothballing (and possibly restarting) projects.

    # Choose flat operating level for baseload plants during each period
    # (not necessarily running all available capacity)
    # Note: this is unconstrained, because other constraints limit project
    # dispatch during each timepoint and therefore the level of this variable.
    # TODO: this should be harmonized with the treatment of baseload generators
    # in generators.core.commit, where baseload just means they will all be
    # committed all the time, but not required to run at a constant output
    # level. That's the definition of baseload used in the Hawaii power system,
    # while the definition used here is more like common usage (run at a flat level
    # or don't run). Since there are multiple meanings, we should probably
    # have separate parameters for constant_output and always_commit. Or
    # we could implement those via time-varying values for min/max commitment
    # and dispatch.
    # new part

    # para ello además hay que adaptar gen_info (manual). ok

    def get_peak_timepoints_commit(m):
        """
        Return the set of timepoints with peak load within a planning reserve
        requirement area for each period. For this calculation, load is defined
        statically (zone_demand_mw), ignoring the impact of all distributed
        energy resources.
        """
        peak_timepoint_list = []
        ZONES = m.LOAD_ZONES 
        for p in m.PERIODS:
            peak_load = 0.0
            for t in m.TPS_IN_PERIOD[p]:
                load = sum(m.zone_demand_mw[z, t] for z in ZONES)
                if load >= peak_load:
                    peak_timepoint = t
                    peak_load = load
            peak_timepoint_list.append(peak_timepoint)
        return peak_timepoint_list
    
    def Peak_TIMEPOINTS_init(m):
        PRR_TIMEPOINTS = []
        PRR_TIMEPOINTS.extend([(t) for t in get_peak_timepoints_commit(m)])
        return PRR_TIMEPOINTS

    mod.Peak_TIMEPOINTS = Set(
        dimen=1,
        within= mod.TIMEPOINTS,
        initialize=Peak_TIMEPOINTS_init,
        doc=(
            "The sparse set of (t) with peak demanad"
        ),
    )

    # Definir el set de dos dimensiones que contiene (generador, timepoint)
    mod.PEAK_GEN_TPS = Set(
        dimen=2,
        initialize=lambda m: (
            (g, tp) for g in m.GENERATION_PROJECTS 
                    for tp in m.TPS_FOR_GEN[g] 
                    if tp in m.Peak_TIMEPOINTS
        ),
        doc="Set de (generador, timepoint) donde el generador g puede operar durante el timepoint tp de carga pico"
    )

    mod.BASELOAD_GEN_PERIODS = Set(
        dimen=2,
        initialize=lambda m: [
            (g, p) for g in m.BASELOAD_GENS for p in m.PERIODS_FOR_GEN[g]
        ],
    )
    mod.BASELOAD_GEN_TPS = Set(
        dimen=2,
        initialize=lambda m: [
            (g, t) for g, p in m.BASELOAD_GEN_PERIODS for t in m.TPS_IN_PERIOD[p]
        ],
    )

    mod.DispatchBaseloadByPeriod = Var(mod.BASELOAD_GEN_PERIODS)

    def DispatchUpperLimit_expr(m, g, t):
        if g in m.VARIABLE_GENS:
            return (
                m.GenCapacityInTP[g, t]
                * m.gen_availability[g]
                * m.gen_max_capacity_factor[g, t]
            )
        else:
            return m.GenCapacityInTP[g, t] * m.gen_availability[g]

    mod.DispatchUpperLimit = Expression(mod.GEN_TPS, rule=DispatchUpperLimit_expr)

    def DispatchUpperLimit_expr_peakload(m, g, ti):              # new
        if g in m.VARIABLE_GENS:
            return (
                m.GenCapacityInTP[g, ti]
                * m.gen_availability[g]
                * m.peak_demand_gen_max_percent[g]                         # añadir a restricción el % de la capacidad que puede aportar el gen no va lo de max capacity factor.. ya hay una restricción para ello. solamente queda agregar esta segunda restricción para la cual se debe cumplir esto además para los momentos de demanda peak
            )
        else:
            return m.GenCapacityInTP[g, ti] * m.gen_availability[g] *  m.peak_demand_gen_max_percent[g]         # añadir a restricción el % de la capacidad que puede aportar el gen.

    mod.DispatchUpperLimit_peakload = Expression(mod.PEAK_GEN_TPS, rule=DispatchUpperLimit_expr_peakload) # new

    mod.Enforce_Dispatch_Baseload_Flat = Constraint(
        mod.BASELOAD_GEN_TPS,
        rule=lambda m, g, t: m.DispatchGen[g, t]
        == m.DispatchBaseloadByPeriod[g, m.tp_period[t]],
    )

    mod.Enforce_Dispatch_PEAK_Upper_Limit = Constraint(
        mod.PEAK_GEN_TPS,
        rule=lambda m, g, t: (m.DispatchGen[g, t] <= m.DispatchUpperLimit_peakload[g, t]),
    )  # new

    mod.Enforce_Dispatch_Upper_Limit = Constraint(
        mod.GEN_TPS,
        rule=lambda m, g, t: (m.DispatchGen[g, t] <= m.DispatchUpperLimit[g, t]),
    )

    mod.GenFuelUseRate_Calculate = Constraint(
        mod.FUEL_BASED_GEN_TPS,
        rule=lambda m, g, t: (
            sum(m.GenFuelUseRate[g, t, f] for f in m.FUELS_FOR_GEN[g])
            == m.DispatchGen[g, t] * m.gen_full_load_heat_rate[g]
        ),
    )
