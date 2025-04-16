import os, time
from pyomo.environ import *

try:
    from pyomo.repn import generate_standard_repn
except ImportError:
    # this was called generate_canonical_repn before Pyomo 5.6
    from pyomo.repn import generate_canonical_repn as generate_standard_repn

import switch_model.hawaii.util as util

# Modulo custom para recuperar valores duales de las restricciones del modelo

def define_components(m):

    if not hasattr(m, "dual"):
        m.dual = Suffix(direction=Suffix.IMPORT)
    if not hasattr(m, "rc"):
        m.rc = Suffix(direction=Suffix.IMPORT)


def write_dual_costs(m, include_iter_num=True):
    outputs_dir = m.options.outputs_dir
    tag = filename_tag(m, include_iter_num)

    outfile = os.path.join(outputs_dir, "dual_costs{t}.csv".format(t=tag))
    dual_data = []
    ## Cuenta el tiempo que se demora en escribir las soluciones duales
    start_time = time.time()
    print("Writing {} ... ".format(outfile), end=" ")

    def add_dual(const, lbound, ubound, duals, prefix="", offset=0.0):
        if const in duals:
            dual = duals[const]
            if dual >= 0.0:
                direction = ">="
                bound = lbound
            else:
                direction = "<="
                bound = ubound
            if bound is None:
                # Variable is unbounded; dual should be 0.0 or possibly a tiny non-zero value.
                if not (-1e-5 < dual < 1e-5):
                    raise ValueError(
                        "{} has no {} bound but has a non-zero dual value {}.".format(
                            const.name, "lower" if dual > 0 else "upper", dual
                        )
                    )
            else:
                total_cost = dual * (bound + offset)
                if total_cost != 0.0:
                    dual_data.append(
                        (
                            prefix + const.name,
                            direction,
                            (bound + offset),
                            dual,
                            total_cost,
                        )
                    )

    for comp in m.component_objects(ctype=Var):
        for idx in comp:
            var = comp[idx]
            if var.value is not None:  # ignore vars that weren't used in the model
                if var.is_integer() or var.is_binary():
                    # integrality constraint sets upper and lower bounds
                    add_dual(var, value(var), value(var), m.rc, prefix="integer: ")
                else:
                    add_dual(var, var.lb, var.ub, m.rc)
    for comp in m.component_objects(ctype=Constraint):
        for idx in comp:
            constr = comp[idx]
            if constr.active:
                offset = 0.0
                # cancel out any constants that were stored in the body instead of the bounds
                # (see https://groups.google.com/d/msg/pyomo-forum/-loinAh0Wx4/IIkxdfqxAQAJ)
                # (might be faster to do this once during model setup instead of every time)
                standard_constraint = generate_standard_repn(constr.body)
                if standard_constraint.constant is not None:
                    offset = -standard_constraint.constant
                add_dual(
                    constr,
                    value(constr.lower),
                    value(constr.upper),
                    m.dual,
                    offset=offset,
                )

    dual_data.sort(key=lambda r: (not r[0].startswith("DR_Convex_"), r[3] >= 0) + r)

    with open(outfile, "w") as f:
        f.write(
            ",".join(["constraint", "direction", "bound", "dual", "total_cost"]) + "\n"
        )
        f.writelines(",".join(map(str, r)) + "\n" for r in dual_data)
    print("time taken: {dur:.2f}s".format(dur=time.time() - start_time))


def filename_tag(m, include_iter_num=True):
    tag = ""
    if m.options.scenario_name:
        tag += "_" + m.options.scenario_name
    if include_iter_num:
        if m.options.max_iter is None:
            n_digits = 4
        else:
            n_digits = len(str(m.options.max_iter - 1))
        tag += "".join(f"_{t:0{n_digits}d}" for t in m.iteration_node)
    return tag

def electricity_marginal_cost(m, z, tp):
    """Return marginal cost of providing product prod in load_zone z during timepoint tp."""

    try:
        component = m.Zone_Energy_Balance[z, tp]
        mg_cost = m.dual[component] / m.bring_timepoint_costs_to_base_year[tp] if component in m.dual else -1
    except:
        mg_cost = -404
    return mg_cost

# def reserve_up_marginal_cost_advanced(m, r, b, tp):
#     """Return marginal cost of providing product prod in load_zone z during timepoint tp."""

#     component = m.Satisfy_Spinning_Reserve_Up_Requirement[r, b, tp]
#     try:
#         mg_cost = m.dual[component]/ m.bring_timepoint_costs_to_base_year[tp] if component in m.dual else -1
#     except:
#         mg_cost = -404
#     return mg_cost

# def reserve_down_marginal_cost_advanced(m, r, b, tp):
#     """Return marginal cost of providing product prod in load_zone z during timepoint tp."""

#     component = m.Satisfy_Spinning_Reserve_Down_Requirement[r, b, tp]
#     try:
#         mg_cost = m.dual[component] / m.bring_timepoint_costs_to_base_year[tp] if component in m.dual else -1
#     except:
#         mg_cost = -404
#     return mg_cost

# def reserve_up_marginal_cost(m, b, tp):
#     """Return marginal cost of providing product prod in load_zone z during timepoint tp."""

#     component = m.Satisfy_Spinning_Reserve_Up_Requirement[b, tp]
#     try:
#         mg_cost = m.dual[component]/ m.bring_timepoint_costs_to_base_year[tp] if component in m.dual else -1
#     except:
#         mg_cost = -404
#     return mg_cost

# def reserve_down_marginal_cost(m, b, tp):
#     """Return marginal cost of providing product prod in load_zone z during timepoint tp."""

#     component = m.Satisfy_Spinning_Reserve_Down_Requirement[b, tp]
#     try:
#         mg_cost = m.dual[component] / m.bring_timepoint_costs_to_base_year[tp] if component in m.dual else -1
#     except:
#         mg_cost = -404
#     return mg_cost

def write_results(m, include_iter_num=True):
    outputs_dir = m.options.outputs_dir
    tag = filename_tag(m, include_iter_num)

    util.write_table(
        m,
        m.LOAD_ZONES,
        m.TIMEPOINTS,
        output_file=os.path.join(outputs_dir, "marginal_cost.csv"),
        headings=("load_zone", "period", "timepoint", "marginal_cost"),
        values=lambda m, z, t: (z, m.tp_period[t], m.tp_timestamp[t])
        + tuple([electricity_marginal_cost(m, z, t)])
    )

    #Reserve spinning advanced
    # util.write_table(
    #     m,
    #     m.BALANCING_AREA_TIMEPOINTS,
    #     output_file=os.path.join(outputs_dir, "reserve_up_down_marginal_cost{t}.csv".format(t=tag)),
    #     headings=("reserve_type", "balancing_area", "period", "timepoint", "reserve_up_marginal_cost", "reserve_down_marginal_cost"),
    #     values=lambda m, r, b, t: (r, b, m.tp_period[t], m.tp_timestamp[t])
    #     + tuple([reserve_up_marginal_cost_advanced(m, r, b, t)])
    #     + tuple([reserve_down_marginal_cost_advanced(m, r, b, t)])
    # )

    #Reserve spinning basic
    # util.write_table(
    #     m,
    #     m.BALANCING_AREA_TIMEPOINTS,
    #     output_file=os.path.join(outputs_dir, "reserve_up_down_marginal_cost{t}.csv".format(t=tag)),
    #     headings=("balancing_area", "period", "timepoint", "reserve_up_marginal_cost", "reserve_down_marginal_cost"),
    #     values=lambda m, b, t: (b, m.tp_period[t], m.tp_timestamp[t])
    #     + tuple([reserve_up_marginal_cost(m, b, t)])
    #     + tuple([reserve_down_marginal_cost(m, b, t)])
    # )


def post_solve(m, outputs_dir):

    write_dual_costs(m, include_iter_num=False)
    write_results(m, include_iter_num=False)