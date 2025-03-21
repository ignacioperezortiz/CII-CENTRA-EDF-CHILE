# Copyright (c) 2015-2024 The Switch Authors. All rights reserved.
# Licensed under the Apache License, Version 2.0, which is in the LICENSE file.

"""
This module defines storage technologies. It builds on top of generic
generators, adding components for deciding how much energy to build into
storage, when to charge, energy accounting, etc.
"""

from pyomo.environ import *
import os, collections
from switch_model.financials import capital_recovery_factor as crf

dependencies = (
    "switch_model.timescales",
    "switch_model.balancing.load_zones",
    "switch_model.financials",
    "switch_model.energy_sources.properties",
    "switch_model.generators.core.build",
    "switch_model.generators.core.dispatch",
)


def define_components(mod):
    """

    STORAGE_GENS is the subset of projects that can provide energy storage.

    STORAGE_GEN_BLD_YRS is the subset of GEN_BLD_YRS, restricted to storage
    projects.

    gen_storage_efficiency[STORAGE_GENS] describes the round trip efficiency of
    a storage technology. A storage technology that is 75 percent efficient
    would have a storage_efficiency of .75. If 1 MWh was stored in such a
    storage project, 750 kWh would be available for extraction later. Internal
    leakage or energy dissipation of storage technologies is assumed to be
    neglible, which is consistent with short-duration storage technologies
    currently on the market which tend to consume stored power within 1 day. If
    a given storage technology has significant internal discharge when it stores
    power for extended time perios, then those behaviors will need to be modeled
    in more detail.

    gen_store_to_release_ratio[STORAGE_GENS] describes the maximum rate that
    energy can be stored, expressed as a ratio of discharge power capacity. This
    is an optional parameter and will default to 1. If a storage project has 1
    MW of dischage capacity and a gen_store_to_release_ratio of 1.2, then it can
    consume up to 1.2 MW of power while charging.

    gen_storage_energy_to_power_ratio[STORAGE_GENS], if specified, restricts the
    storage capacity (in MWh) to be a fixed multiple of the output power (in
    MW), i.e., specifies a particular number of hours of storage capacity. Omit
    this column or specify "." to allow Switch to choose the energy/power ratio.
    (Note: gen_storage_energy_overnight_cost or gen_overnight_cost should often
    be set to 0 when using this.)

    gen_storage_max_cycles_per_year[STORAGE_GENS], if specified, restricts the
    number of charge/discharge cycles each storage project can perform per year;
    one cycle is defined as discharging an amount of energy equal to the storage
    capacity of the project.

    gen_storage_energy_overnight_cost[(g, bld_yr) in STORAGE_GEN_BLD_YRS] is the
    overnight capital cost per MWh of energy capacity for building the given
    storage technology installed in the given investment period. This is only
    defined for storage technologies. Note that this describes the energy
    component and the overnight_cost describes the power component.

    gen_storage_energy_fixed_om[(g, bld_yr) in STORAGE_GEN_BLD_YRS] is the
    annual fixed operations & maintenance cost per MWh of energy capacity
    installed. This is charged every year over the life of the storage project,
    whether it is operated or not. It should be in units of real dollars per
    year per MWh of capacity. This should only be defined for storage
    technologies; it will be ignored for non-storage generators. Note that this
    shows the cost per unit of energy capacity (i.e., batteries) and
    gen_fixed_om shows the cost per unit of power capacity (i.e. inverters).
    Note: there is no gen_storage_energy_variable_om parameter; variable O&M for
    the storage component should be included in variable O&M for the power
    component (gen_fixed_om).

    build_gen_energy_predetermined[(g, bld_yr) in PREDETERMINED_GEN_BLD_YRS] is
    the amount of storage that has either been installed previously, or is
    slated for installation and is not a free decision variable. This is
    analogous to build_gen_predetermined, but in units of energy of storage
    capacity (MWh) rather than power (MW).

    BuildStorageEnergy[(g, bld_yr) in STORAGE_GEN_BLD_YRS] is a decision of how
    much energy capacity to build onto a storage project. This is analogous to
    BuildGen, but for energy rather than power.

    StorageEnergyInstallCosts[PERIODS] is an expression of the annual costs
    incurred by the BuildStorageEnergy decision.

    StorageEnergyCapacity[g, period] is an expression describing the cumulative
    available energy capacity of BuildStorageEnergy. This is analogous to
    GenCapacity.

    STORAGE_GEN_TPS is the subset of GEN_TPS, restricted to storage projects.

    ChargeStorage[(g, t) in STORAGE_GEN_TPS] is a dispatch decision of how much
    to charge a storage project in each timepoint.

    StorageNetCharge[LOAD_ZONE, TIMEPOINT] is an expression describing the
    aggregate impact of ChargeStorage in each load zone and timepoint.

    Charge_Storage_Upper_Limit[(g, t) in STORAGE_GEN_TPS] constrains
    ChargeStorage to available power capacity (accounting for
    gen_store_to_release_ratio)

    StateOfCharge[(g, t) in STORAGE_GEN_TPS] is a variable for tracking state of
    charge. This value stores the state of charge at the end of each timepoint
    for each storage project.

    Track_State_Of_Charge[(g, t) in STORAGE_GEN_TPS] constrains StateOfCharge
    based on the StateOfCharge in the previous timepoint, ChargeStorage and
    DispatchGen.

    State_Of_Charge_Upper_Limit[(g, t) in STORAGE_GEN_TPS] constrains
    StateOfCharge based on installed energy capacity.

    """

    # includes generators that we manage depth of charge for and also ones that
    # we don't, i.e., pumped storage hydro
    mod.ALL_STORAGE_GENS = Set(within=mod.GENERATION_PROJECTS, dimen=1)
    # peek at the hydro gens (so this can load before hydro_system module)
    mod._STORAGE_HYDRO_GENS = Set(within=mod.GENERATION_PROJECTS, dimen=1)
    # standard storage gens (not hydro)
    mod.STORAGE_GENS = Set(
        within=mod.GENERATION_PROJECTS,
        dimen=1,
        initialize=lambda m: m.ALL_STORAGE_GENS - m._STORAGE_HYDRO_GENS,
    )
    mod.STORAGE_GEN_PERIODS = Set(
        dimen=2,
        within=mod.GEN_PERIODS,
        initialize=lambda m: [
            (g, p) for g in m.STORAGE_GENS for p in m.PERIODS_FOR_GEN[g]
        ],
    )

    mod.gen_storage_efficiency = Param(mod.ALL_STORAGE_GENS, within=PercentFraction)
    # TODO: rename to gen_charge_to_discharge_ratio?
    mod.gen_store_to_release_ratio = Param(
        mod.ALL_STORAGE_GENS, within=NonNegativeReals, default=1.0
    )
    mod.gen_storage_energy_to_power_ratio = Param(
        mod.STORAGE_GENS, within=NonNegativeReals, default=float("inf")
    )  # inf is a flag that no value is specified (nan and None don't work)
    mod.gen_storage_max_cycles_per_year = Param(
        mod.STORAGE_GENS, within=NonNegativeReals, default=float("inf")
    )

    # TODO: build this set up instead of filtering down, to improve performance
    mod.STORAGE_GEN_BLD_YRS = Set(
        dimen=2,
        initialize=mod.GEN_BLD_YRS,
        filter=lambda m, g, bld_yr: g in m.STORAGE_GENS,
    )
    # storage may be priced per MW and/or per MWh
    # NOTE: gen_storage_energy_overnight_cost must be supplied even if zero,
    # just to be sure the user has thought about this; but we don't do a
    # min_data_check on it because it may not be supplied in systems that use
    # this module only for pumped hydro, where storage capacity is handled via
    # the hydro network.
    mod.gen_storage_energy_overnight_cost = Param(
        mod.STORAGE_GEN_BLD_YRS, within=NonNegativeReals
    )
    mod.build_gen_energy_predetermined = Param(
        mod.PREDETERMINED_GEN_BLD_YRS, within=NonNegativeReals
    )

    mod.gen_storage_energy_fixed_om = Param(
        mod.STORAGE_GEN_BLD_YRS, within=NonNegativeReals, default=0.0
    )

    def bounds_BuildStorageEnergy(m, g, bld_yr):
        if (g, bld_yr) in m.build_gen_energy_predetermined:
            return (
                m.build_gen_energy_predetermined[g, bld_yr],
                m.build_gen_energy_predetermined[g, bld_yr],
            )
        else:
            return (0, None)

    mod.BuildStorageEnergy = Var(
        mod.STORAGE_GEN_BLD_YRS,
        within=NonNegativeReals,
        bounds=bounds_BuildStorageEnergy,
    )

    # Summarize capital and O&M costs of energy storage for the objective
    # function
    mod.StorageEnergyCapitalCost = Expression(
        mod.STORAGE_GENS,
        mod.PERIODS,
        rule=lambda m, g, p: sum(
            m.BuildStorageEnergy[g, bld_yr]
            * m.gen_storage_energy_overnight_cost[g, bld_yr]
            * crf(m.interest_rate, m.gen_max_age[g])
            # apply to all vintages (bld_yr) of storage that are active in the
            # current period (p)
            for bld_yr in m.BLD_YRS_FOR_GEN_PERIOD[g, p]
        ),
    )
    mod.StorageEnergyFixedOMCost = Expression(
        mod.STORAGE_GENS,
        mod.PERIODS,
        rule=lambda m, g, p: sum(
            m.BuildStorageEnergy[g, bld_yr] * m.gen_storage_energy_fixed_om[g, bld_yr]
            for bld_yr in m.BLD_YRS_FOR_GEN_PERIOD[g, p]
        ),
    )
    mod.StorageEnergyFixedCost = Expression(
        mod.PERIODS,
        rule=lambda m, p: sum(
            m.StorageEnergyCapitalCost[g, p] + m.StorageEnergyFixedOMCost[g, p]
            for g in m.STORAGE_GENS
        ),
    )
    mod.Cost_Components_Per_Period.append("StorageEnergyFixedCost")

    mod.StorageEnergyCapacity = Expression(
        mod.STORAGE_GENS,
        mod.PERIODS,
        rule=lambda m, g, period: sum(
            m.BuildStorageEnergy[g, bld_yr]
            for bld_yr in m.BLD_YRS_FOR_GEN_PERIOD[g, period]
        ),
    )

    mod.STORAGE_GEN_TPS = Set(
        dimen=2,
        initialize=lambda m: (
            (g, tp) for g in m.STORAGE_GENS for tp in m.TPS_FOR_GEN[g]
        ),
    )

    mod.STORAGE_GEN_TS = Set(
        dimen=2,
        initialize=lambda m: (
            (g, tp) for g in m.STORAGE_GENS for tp in m.TS_FOR_GEN[g]
        ),
    )

    mod.ALL_STORAGE_GEN_TPS = Set(
        dimen=2,
        initialize=lambda m: (
            (g, tp) for g in m.ALL_STORAGE_GENS for tp in m.TPS_FOR_GEN[g]
        ),
    )

    mod.ChargeStorage = Var(mod.ALL_STORAGE_GEN_TPS, within=NonNegativeReals)

    # Summarize storage charging for the energy balance equations
    # TODO: rename this StorageTotalCharging or similar (to indicate it's a
    # sum for a zone, not a net quantity for a project)
    def rule(m, z, t):
        # Construct and cache a set for summation as needed
        if not hasattr(m, "Storage_Charge_Summation_dict"):
            m.Storage_Charge_Summation_dict = collections.defaultdict(set)
            for g, t2 in m.ALL_STORAGE_GEN_TPS:
                z2 = m.gen_load_zone[g]
                m.Storage_Charge_Summation_dict[z2, t2].add(g)
        # Use pop to free memory
        relevant_projects = m.Storage_Charge_Summation_dict.pop((z, t), {})
        return sum(m.ChargeStorage[g, t] for g in relevant_projects)

    mod.StorageNetCharge = Expression(mod.LOAD_ZONES, mod.TIMEPOINTS, rule=rule)
    # Register net charging with zonal energy balance. Discharging is already
    # covered by DispatchGen.
    mod.Zone_Power_Withdrawals.append("StorageNetCharge")

    # use fixed energy/power ratio (# hours of capacity) when specified
    mod.Enforce_Fixed_Energy_Storage_Ratio = Constraint(
        mod.STORAGE_GEN_BLD_YRS,
        rule=lambda m, g, y: (
            Constraint.Skip
            if m.gen_storage_energy_to_power_ratio[g]
            == float("inf")  # no value specified
            else (
                m.BuildStorageEnergy[g, y]
                == m.gen_storage_energy_to_power_ratio[g] * m.BuildGen[g, y]
            )
        ),
    )

    mod.Charge_Storage_Upper_Limit = Constraint(
        mod.ALL_STORAGE_GEN_TPS,
        rule=lambda m, g, t: m.ChargeStorage[g, t]
        <= m.DispatchUpperLimit[g, t] * m.gen_store_to_release_ratio[g],
    )

    mod.StateOfCharge = Var(mod.STORAGE_GEN_TPS, within=NonNegativeReals)

    def Track_State_Of_Charge_rule(m, g, t):
        return (
            m.StateOfCharge[g, t]
            == m.StateOfCharge[g, m.tp_previous[t]]
            + (
                m.ChargeStorage[g, t] * m.gen_storage_efficiency[g]
                - m.DispatchGen[g, t]
            )
            * m.tp_duration_hrs[t]
        )

    mod.Track_State_Of_Charge = Constraint(
        mod.STORAGE_GEN_TPS, rule=Track_State_Of_Charge_rule
    )

    # new to dont allow discharging in other timeseries
    mod.Track_State_Of_Charge2 = Constraint(
        mod.STORAGE_GEN_TS,
        rule=lambda m, g, ts: 
            m.StateOfCharge[g, m.TPS_IN_TS[ts].at(1)] == m.StateOfCharge[g, m.TPS_IN_TS[ts].at(24)]
        )
    # finish of the new part

    def State_Of_Charge_Upper_Limit_rule(m, g, t):
        return m.StateOfCharge[g, t] <= m.StorageEnergyCapacity[g, m.tp_period[t]]

    mod.State_Of_Charge_Upper_Limit = Constraint(
        mod.STORAGE_GEN_TPS, rule=State_Of_Charge_Upper_Limit_rule
    )

    # batteries can only complete the specified number of cycles per year, averaged over each period
    mod.Battery_Cycle_Limit = Constraint(
        mod.STORAGE_GEN_PERIODS,
        rule=lambda m, g, p:
        # solvers sometimes perform badly with infinite constraint
        (
            Constraint.Skip
            if m.gen_storage_max_cycles_per_year[g] == float("inf")
            else (
                sum(
                    m.DispatchGen[g, tp] * m.tp_duration_hrs[tp]
                    for tp in m.TPS_IN_PERIOD[p]
                )
                <= m.gen_storage_max_cycles_per_year[g]
                * m.StorageEnergyCapacity[g, p]
                * m.period_length_years[p]
            )
        ),
    )

    # Some projects are retired before the first study period, so they don't
    # appear in the objective function or any constraints. In this case, pyomo
    # may leave the variable value undefined even after a solve instead of
    # assigning a value within the allowed range. This causes errors in the
    # Progressive Hedging code, which expects every variable to have a value
    # after the solve. So as a starting point we assign an appropriate value to
    # all the existing projects here.
    def BuildStorageEnergy_assign_default_value(m, g, bld_yr):
        if (g, bld_yr) in m.build_gen_energy_predetermined:
            m.BuildStorageEnergy[g, bld_yr] = m.build_gen_energy_predetermined[
                g, bld_yr
            ]
        elif g in m.STORAGE_GENS and m.gen_storage_energy_to_power_ratio[g] == float(
            "inf"
        ):
            raise ValueError(
                f"For storage generator g='{g}', gen_build_predetermined[g, {bld_yr}] "
                f"has been specified, but not "
                f"gen_build_energy_predetermined[g, {bld_yr}] or "
                f"gen_storage_energy_to_power_ratio[g]."
            )

    mod.BuildStorageEnergy_assign_default_value = BuildAction(
        mod.PREDETERMINED_GEN_BLD_YRS, rule=BuildStorageEnergy_assign_default_value
    )

    # TODO: expand m.PREDETERMINED_GEN_BLD_YRS to include generators with energy
    # specified but not power, and in these cases, raise an error if
    # energy_to_power_ratio is not specified.


def load_inputs(mod, switch_data, inputs_dir):
    """

    Import storage parameters. Optional columns are noted with a *.

    gen_info.csv
        GENERATION_PROJECT, ...
        gen_storage_efficiency, gen_store_to_release_ratio*,
        gen_storage_energy_to_power_ratio*, gen_storage_max_cycles_per_year*

    gen_build_costs.csv
        GENERATION_PROJECT, build_year, ...
        gen_storage_energy_overnight_cost
        gen_storage_energy_fixed_om*

    gen_build_predetermined.csv
        GENERATION_PROJECT, build_year, ...,
        build_gen_energy_predetermined*

    """

    # TODO: maybe move these columns to a storage_gen_info file to avoid the weird index
    # reading and avoid having to create these extra columns for all projects;
    # Alternatively, say that these values are specified for _all_ projects (maybe with None
    # as default) and then define STORAGE_GENS as the subset of projects for which
    # gen_storage_efficiency has been specified, then require valid settings for all
    # STORAGE_GENS.
    switch_data.load_aug(
        filename=os.path.join(inputs_dir, "gen_info.csv"),
        optional_params=[
            "gen_store_to_release_ratio",
            "gen_storage_energy_to_power_ratio",
            "gen_storage_max_cycles_per_year",
        ],
        param=(
            mod.gen_storage_efficiency,
            mod.gen_store_to_release_ratio,
            mod.gen_storage_energy_to_power_ratio,
            mod.gen_storage_max_cycles_per_year,
        ),
    )
    switch_data.load_aug(
        filename=os.path.join(inputs_dir, "hydro_generation_projects.csv"),
        index=mod._STORAGE_HYDRO_GENS,
        param=(),
        optional=True,
    )

    # Base the set of storage projects on storage efficiency being specified.
    # TODO: define this in a more normal way
    switch_data.data()["ALL_STORAGE_GENS"] = {
        None: list(switch_data.data(name="gen_storage_efficiency").keys())
    }
    # cost data must be provided for non-hydro storage gens, but may not be
    # provided if this module is only used for pumped hydro storage
    switch_data.load_aug(
        filename=os.path.join(inputs_dir, "gen_build_costs.csv"),
        optional=True,
        param=(mod.gen_storage_energy_overnight_cost, mod.gen_storage_energy_fixed_om),
    )
    switch_data.load_aug(
        optional=True,
        filename=os.path.join(inputs_dir, "gen_build_predetermined.csv"),
        param=(mod.build_gen_energy_predetermined,),
    )


def post_solve(instance, outdir):
    """
    Export storage dispatch info to storage_dispatch.csv

    Note that construction information is reported by the generators.core.build
    module, so is not reported here.
    """
    import switch_model.reporting as reporting

    reporting.write_table(
        instance,
        instance.ALL_STORAGE_GEN_TPS,
        output_file=os.path.join(outdir, "storage_dispatch.csv"),
        headings=(
            "generation_project",
            "timepoint",
            "load_zone",
            "ChargeMW",
            "DischargeMW",
            "StateOfCharge",
        ),
        values=lambda m, g, t: (
            g,
            m.tp_timestamp[t],
            m.gen_load_zone[g],
            m.ChargeStorage[g, t],
            m.DispatchGen[g, t],
            m.StateOfCharge[g, t] if g in m.STORAGE_GENS else ".",
        ),
    )
