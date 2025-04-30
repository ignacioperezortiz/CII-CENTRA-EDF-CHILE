include("../global_vars.jl")
periods_array = [2024,2026,2029,2030,2031,2033,2040,2050]

daily = true
if daily == true
    max_period_index = 364
elseif daily == false
    max_period_index = 51
end

modules_uc_txt = CURRENT_STUDY_CASE*"modules/modules_unit_commitment.txt"
modules_dispatch_txt = CURRENT_STUDY_CASE*"modules/modules_operation.txt"

for period in periods_array
    println("Currently writing period $period")

    parentpath = CURRENT_STUDY_CASE*"inputs_"*string(period)
    if !isdir(parentpath)
        mkpath(parentpath)  # Create any missing directories
    end

    #Para cada semana se guardan los datos que no dependen de la semana, y los datos correspondientes de la semana.
    for week_index in 0:max_period_index

        week_parentpath = parentpath*"/"*string(week_index)

        #Se copian los modulos para las corridas y los switch inputs versions correspondientes
        modules_txt_target_UC = week_parentpath*"/inputs_unit_commitment/modules.txt"
        # switch_inputs_version_txt_target_UC = week_parentpath*"/inputs_unit_commitment/switch_inputs_version.txt"
        modules_txt_target_dispatch= week_parentpath*"/inputs_dispatch/modules.txt"
        # switch_inputs_version_txt_target_dispatch = week_parentpath*"/inputs_dispatch/switch_inputs_version.txt"
        cp(modules_uc_txt, modules_txt_target_UC, force=true)
        # cp(switch_inputs_version_txt, switch_inputs_version_txt_target_UC, force=true)
        # cp(switch_inputs_version_txt, switch_inputs_version_txt_target_dispatch, force=true)
        cp(modules_dispatch_txt, modules_txt_target_dispatch, force=true)
    end
end