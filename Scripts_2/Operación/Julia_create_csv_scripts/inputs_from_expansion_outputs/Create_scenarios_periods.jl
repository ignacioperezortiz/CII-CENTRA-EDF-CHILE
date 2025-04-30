# script para crear archivo csv varaible_capacity_factors.csv en base a ??
using CSV
using DataFrames
using Dates
using Statistics
using Random
using Printf

include("../global_vars.jl")
include("create_weekly_data.jl")

daily = true
if daily == true
    max_period_index = 364
elseif daily == false
    max_period_index = 51
end

new_modules_data = true

##TODO Hacer que los variable capacity factors consideren tanto centrales en construccion en el periodo, asi como las de periodos anteriores
#Para esto se podria generar un array que no se resetee y vaya agregando centrales segun la construccion
function generar_period_scenarios(input_url::String)
    # Archivos que se copian directamente
    modules_uc_txt = CURRENT_STUDY_CASE*"modules/modules_unit_commitment.txt"
    modules_dispatch_txt = CURRENT_STUDY_CASE*"modules/modules_operation.txt"
    switch_inputs_version_txt = input_url*"switch_inputs_version.txt"

    # Archivos que se deben filtrar
    df_timeseries = CSV.read(input_url*"timeseries.csv", DataFrame)
    df_timepoint = CSV.read(input_url*"timepoints.csv", DataFrame)
    df_periods = CSV.read(input_url*"periods.csv", DataFrame)
    df_carbon_policies = CSV.read(input_url*"carbon_policies.csv", DataFrame)
    df_fuel_cost = CSV.read(input_url*"fuel_cost.csv", DataFrame)
    df_gen_build_costs = CSV.read(input_url*"gen_build_costs.csv", DataFrame)
    df_gen_build_predetermined = CSV.read(input_url*"gen_build_predetermined.csv", DataFrame)
    df_gen_info = CSV.read(input_url*"gen_info.csv", DataFrame)
    df_loads = CSV.read(input_url*"loads.csv", DataFrame)
    df_sf_power_output = CSV.read(input_url*"sf_power_output.csv", DataFrame)
    df_storage_build_energy_predetermined = CSV.read(input_url*"storage_build_energy_predetermined.csv", DataFrame)
    df_tx_build_predetermined = CSV.read(input_url*"tx_build_predetermined.csv", DataFrame)
    df_transmission_lines = CSV.read(input_url*"transmission_lines.csv", DataFrame)
    df_variable_capacity_factors = CSV.read(input_url*"variable_capacity_factors.csv", DataFrame)
    df_fuel_supply_curves = CSV.read(input_url*"fuel_supply_curves.csv", DataFrame)
    
    # Archivos que no son necesarios para filtrar
    filtered_csp_efficiencies_df = CSV.read(input_url*"csp_efficiencies.csv", DataFrame)
    filtered_financials_df = CSV.read(input_url*"financials.csv", DataFrame)
    filtered_fuels_df = CSV.read(input_url*"fuels.csv", DataFrame)
    filtered_load_zones_df = CSV.read(input_url*"load_zones.csv", DataFrame)
    filtered_non_fuel_energy_sources_df = CSV.read(input_url*"non_fuel_energy_sources.csv", DataFrame)
    filtered_planning_reserve_requirement_zones_df = CSV.read(input_url*"planning_reserve_requirement_zones.csv", DataFrame)
    filtered_planning_reserve_requirements_df = CSV.read(input_url*"planning_reserve_requirements.csv", DataFrame)
    filtered_zone_to_regional_fuel_market_df = CSV.read(input_url*"zone_to_regional_fuel_market.csv", DataFrame)
    filtered_regional_fuel_markets = CSV.read(input_url*"regional_fuel_markets.csv", DataFrame)
    
    filtered_dfs = Dict()

    timepoints_dataframes_dict = Dict(
        "timeseries" => Dict("timepoint_column_name" => "timepoint"),
        "timepoints" => Dict("timepoint_column_name" => "timepoint"),
        "sf_power_output" => Dict("timepoint_column_name" => "timepoint"),
        "variable_capacity_factors" => Dict("timepoint_column_name" => "timepoint"),
        "loads" => Dict("timepoint_column_name" => "TIMEPOINT"),
    )

    # timepoints_dataframes_dict_no_write = Dict(
    #     "timeseries" => Dict("timepoint_column_name" => "timepoint"),
    #     "timepoints" => Dict("timepoint_column_name" => "timepoint"),
    #     "sf_power_output" => Dict("timepoint_column_name" => "timepoint"),
    #     "variable_capacity_factors" => Dict("timepoint_column_name" => "timepoint"),
    #     "loads" => Dict("timepoint_column_name" => "TIMEPOINT"),
    # )

    generation_projects_of_interest_array = Set([])
    tx_lines_of_interest_array = Set([])

    filtered_gen_build_predetermined_last_period_dict = Dict{Any, Float64}()
    filtered_storage_build_energy_predetermined_last_period_dict = Dict{Any, Float64}()
    filtered_tx_build_predetermined_last_period_dict = Dict{Any, Float64}()
    filtered_last_period_gen_build_costs_df = DataFrame()

    ## Se recuperan las fechas minimas de construccion para saber salida de centrales

    min_years = combine(groupby(df_gen_build_predetermined, :GENERATION_PROJECT), :build_year => minimum => :min_build_year)
    df_gen_info = leftjoin(df_gen_info, min_years, on=:GENERATION_PROJECT)

    for (index,row) in enumerate(eachrow(df_periods))
        period_start = row[:period_start]
        period_end = row[:period_end]

        println("Periodo actual con indice: $index")
        println(period_start)

        # Base time csvs
        filtered_timeseries_df = filter(row -> row[:ts_period] == period_start, df_timeseries)
        timeseries_of_interest = Set(filtered_timeseries_df.TIMESERIES)
        filtered_timepoint_df = filter(row -> row[:timeseries] in timeseries_of_interest, df_timepoint)
        timepoints_of_interest = Set(filtered_timepoint_df.timepoint_id)

        # Filter by timepoints
        filtered_loads_df = filter(row -> row[:TIMEPOINT] in timepoints_of_interest, df_loads)
        
        # Filter the period
        filtered_periods_df = filter(row -> row[:period_start] == period_start, df_periods)
        filtered_carbon_policies_df = filter(row -> row[:PERIOD] == period_start, df_carbon_policies)
        filtered_fuel_cost_df = filter(row -> row[:period] == period_start, df_fuel_cost)
        filtered_fuel_supply_curves = filter(row -> row[:period] == period_start, df_fuel_supply_curves)
        if index == 1
            # En este caso se obtienen igual las construcciones previas al inicio del periodo de estudio para llevarlas al year de estudio
            filtered_tx_build_predetermined_df = filter(row -> row[:build_year] < period_end && row[:tx_predetermined_cap] > 0, df_tx_build_predetermined)
            filtered_storage_build_energy_predetermined_df = filter(row -> row[:build_year] < period_end && row[:build_gen_energy_predetermined] > 0, df_storage_build_energy_predetermined)
            filtered_gen_build_predetermined_df = filter(row -> row[:build_year] < period_end && row[:build_gen_predetermined] > 0, df_gen_build_predetermined)
        else
            filtered_tx_build_predetermined_df = filter(row -> row[:build_year] == period_start && row[:tx_predetermined_cap] > 0, df_tx_build_predetermined)
            filtered_storage_build_energy_predetermined_df = filter(row -> row[:build_year] == period_start && row[:build_gen_energy_predetermined] > 0, df_storage_build_energy_predetermined)
            filtered_gen_build_predetermined_df = filter(row -> row[:build_year] >= period_start && row[:build_year] < period_end && row[:build_gen_predetermined] > 0, df_gen_build_predetermined)
        end
        
        # Filter by transmission lines
        tx_lines_of_interest = Set(filtered_tx_build_predetermined_df.TRANSMISSION_LINE)
        tx_lines_of_interest_array = union(tx_lines_of_interest_array, tx_lines_of_interest)
        filtered_transmission_lines_df = copy(df_transmission_lines)
        # filtered_transmission_lines_df = filter(row -> row[:TRANSMISSION_LINE] in tx_lines_of_interest_array || row[:existing_trans_cap] > 0 || (row[:expansion_trans_cap] > 0 && row[:expansion_trans_cap]), df_transmission_lines)
        if index == 1
            #Asi tambien en el caso de la preexistencia de lineas de transmision, se deben agregar al diccionario base
            filtered_tx_build_predetermined_last_period = groupby(filtered_transmission_lines_df, :TRANSMISSION_LINE)
            filtered_tx_build_predetermined_current_last_period_dict = Dict(first(row.TRANSMISSION_LINE) => sum(row.existing_trans_cap) for row in filtered_tx_build_predetermined_last_period)
            filtered_tx_build_predetermined_last_period_dict = Dict(
                key => get(filtered_tx_build_predetermined_last_period_dict, key, 0.0) + get(filtered_tx_build_predetermined_current_last_period_dict, key, 0.0) 
                for key in union(keys(filtered_tx_build_predetermined_last_period_dict), keys(filtered_tx_build_predetermined_current_last_period_dict))
            )
        end

        filtered_transmission_lines_df.existing_trans_cap = [get(filtered_tx_build_predetermined_last_period_dict, row[:TRANSMISSION_LINE], 0) for row in eachrow(filtered_transmission_lines_df)]

        # In case the tx build predetermined is empty or not complete for the period, fill the data with 0's
        for tx_line_name in Set(filtered_transmission_lines_df.TRANSMISSION_LINE)
            if !(tx_line_name in filtered_tx_build_predetermined_df.TRANSMISSION_LINE)
                push!(filtered_tx_build_predetermined_df, (tx_line_name, period_start, 0))
            end
        end
        # Filter by generation projects
        generation_projects_of_interest = Set(filtered_gen_build_predetermined_df.GENERATION_PROJECT)
        generation_projects_of_interest_array = union(generation_projects_of_interest_array, generation_projects_of_interest)
        # Informacion de generadores a actualizar con expansiones de cada set periodo
        filtered_gen_info_df = filter(row -> row[:GENERATION_PROJECT] in generation_projects_of_interest_array, df_gen_info)
        filtered_gen_info_df.gen_preinstalled_capacity = [get(filtered_gen_build_predetermined_last_period_dict, row[:GENERATION_PROJECT], 0) for row in eachrow(filtered_gen_info_df)]
        filtered_gen_info_df.storage_preinstalled_capacity = [get(filtered_storage_build_energy_predetermined_last_period_dict, row[:GENERATION_PROJECT], 0) for row in eachrow(filtered_gen_info_df)]

        # Valores predeterminados transmision
        filtered_tx_build_predetermined_last_period = groupby(filtered_tx_build_predetermined_df, :TRANSMISSION_LINE)
        filtered_tx_build_predetermined_current_last_period_dict = Dict(first(row.TRANSMISSION_LINE) => sum(row.tx_predetermined_cap) for row in filtered_tx_build_predetermined_last_period)
        filtered_tx_build_predetermined_last_period_dict = Dict(
            key => get(filtered_tx_build_predetermined_last_period_dict, key, 0.0) + get(filtered_tx_build_predetermined_current_last_period_dict, key, 0.0) 
            for key in union(keys(filtered_tx_build_predetermined_last_period_dict), keys(filtered_tx_build_predetermined_current_last_period_dict))
        )
        
        # Valores predeterminados capacidad generacion
        filtered_gen_build_predetermined_last_period = groupby(filtered_gen_build_predetermined_df, :GENERATION_PROJECT)
        filtered_gen_build_predetermined_current_last_period_dict = Dict(first(row.GENERATION_PROJECT) => sum(row.build_gen_predetermined) for row in filtered_gen_build_predetermined_last_period)
        #Se unen los diccionarios para agregar los valores de periodos anteriores
        filtered_gen_build_predetermined_last_period_dict = Dict(
            key => get(filtered_gen_build_predetermined_last_period_dict, key, 0.0) + get(filtered_gen_build_predetermined_current_last_period_dict, key, 0.0) 
            for key in union(keys(filtered_gen_build_predetermined_last_period_dict), keys(filtered_gen_build_predetermined_current_last_period_dict))
        )
        # Valores predeterminados energia almacenamiento
        filtered_storage_build_energy_predetermined_last_period = groupby(filtered_storage_build_energy_predetermined_df, :GENERATION_PROJECT)
        filtered_storage_build_energy_predetermined_current_last_period_dict = Dict(first(row.GENERATION_PROJECT) => sum(row.build_gen_energy_predetermined) for row in filtered_storage_build_energy_predetermined_last_period)
        #Se unen los diccionarios para agregar los valores de periodos anteriores
        filtered_storage_build_energy_predetermined_last_period_dict = Dict(
            key => get(filtered_storage_build_energy_predetermined_last_period_dict, key, 0.0) + get(filtered_storage_build_energy_predetermined_current_last_period_dict, key, 0.0) 
            for key in union(keys(filtered_storage_build_energy_predetermined_last_period_dict), keys(filtered_storage_build_energy_predetermined_current_last_period_dict))
        )

        filtered_gen_build_costs_df = innerjoin(df_gen_build_costs, filtered_gen_build_predetermined_df, on=:GENERATION_PROJECT, makeunique=true)
        filtered_gen_build_costs_df = filter(row -> row[:build_year] == row[:build_year_1], filtered_gen_build_costs_df)
        select!(filtered_gen_build_costs_df, Not(:build_year_1))
        if nrow(filtered_last_period_gen_build_costs_df) > 0 && ncol(filtered_last_period_gen_build_costs_df) > 0
            filtered_last_period_gen_build_costs_df.build_year .= period_start
            filtered_gen_build_costs_df = vcat(filtered_gen_build_costs_df, filtered_last_period_gen_build_costs_df)
        end

        filtered_last_period_gen_build_costs_df = copy(filtered_gen_build_costs_df)
        filtered_sf_power_output_df = filter(row -> row[:timepoint] in timepoints_of_interest && row[:GENERATION_PROJECT] in generation_projects_of_interest_array, df_sf_power_output)
        #filtered_gen_build_costs_df = filter(row -> row[:build_year] >= period_start && row[:build_year] <= period_end && row[:GENERATION_PROJECT] in generation_projects_of_interest, df_gen_build_costs)

        filtered_variable_capacity_factors_df = filter(row -> row[:GENERATION_PROJECT] in generation_projects_of_interest_array && row[:timepoint] in timepoints_of_interest, df_variable_capacity_factors)

        # Store the filtered DataFrame in a dictionary
        filtered_dfs[period_start] = Dict(
            "timeseries" => filtered_timeseries_df,
            "timepoints" => filtered_timepoint_df,
            "periods" => filtered_periods_df,
            "carbon_policies" => filtered_carbon_policies_df,
            "fuel_cost" => filtered_fuel_cost_df,
            "fuel_supply_curves" => filtered_fuel_supply_curves,
            "gen_build_costs" => filtered_gen_build_costs_df,
            "gen_build_predetermined" => filtered_gen_build_predetermined_df,
            "gen_info" => filtered_gen_info_df,
            "loads" => filtered_loads_df,
            "sf_power_output" => filtered_sf_power_output_df,
            "storage_build_energy_predetermined" => filtered_storage_build_energy_predetermined_df,
            "tx_build_predetermined" => filtered_tx_build_predetermined_df,
            "transmission_lines" => filtered_transmission_lines_df,
            "variable_capacity_factors" => filtered_variable_capacity_factors_df,
            "csp_efficiencies" => filtered_csp_efficiencies_df,
            "financials" => filtered_financials_df,
            "fuels" => filtered_fuels_df,
            "load_zones" => filtered_load_zones_df,
            "zone_to_regional_fuel_market" => filtered_zone_to_regional_fuel_market_df,
            "regional_fuel_markets" => filtered_regional_fuel_markets,
            "non_fuel_energy_sources" => filtered_non_fuel_energy_sources_df,
            "planning_reserve_requirement_zones" => filtered_planning_reserve_requirement_zones_df,
            "planning_reserve_requirements" => filtered_planning_reserve_requirements_df,
            "weekly_data" => Dict(),
        )

        #Create weekly data corresponding to period
        """
        archivos a modificar:
        timeseries: Se debe tener una timeseries que tenga la semana de datos horarios
        timepoints: Se deben generar timepoints horarios de una semana
        periods: Ahora pasa a ser el periodo que se esta corriendo
        gen_build_costs: Se debe revisar que los years se contengan dentro del periodo que se esta corriendo operacionalmente
        gen_build_predetermined: Se debe revisar que los years se contengan dentro del periodo que se esta corriendo operacionalmente
        storage_build_energy_predetermined: Se debe revisar que los years se contengan dentro del periodo que se esta corriendo operacionalmente
        tx_build_predetermined: Se debe revisar que los years se contengan dentro del periodo que se esta corriendo operacionalmente
        sf_power_output: Ajustar con los timepoints de interes
        variable_capacity_factors: Replicar datos y obtener solo para puntos de interes
        csp_efficiencies: Replicar datos y obtener solo para puntos de interes
        loads: Replicar datos y obtener solo para puntos de interes
        planning_reserve_requirements: Se puede saltar
        """
        
        #TODO Crear funciones que generen replica de data aparte de funcion que crea nuevos timepoints
        for dataframe_timepoints in keys(timepoints_dataframes_dict)
            println("Value: $dataframe_timepoints for period: $period_start")
            start_date = Date(period_start, 1, 1)
            for week_index in 0:max_period_index
                if !(haskey(filtered_dfs[period_start]["weekly_data"], week_index+1))
                    filtered_dfs[period_start]["weekly_data"][week_index+1] = Dict()
                end
                # Calculate the start date for the current week
                if daily == true
                    week_start = start_date + Day(week_index)
                elseif daily == false
                    week_start = start_date + Week(week_index)
                end
                
                # Expand the data for this week
                if dataframe_timepoints == "timeseries"
                    weekly_data = create_corresponding_timeseries(filtered_dfs[period_start][dataframe_timepoints], week_start, period_start)
                elseif dataframe_timepoints == "timepoints"
                    weekly_data = expand_week_timepoints(filtered_dfs[period_start][dataframe_timepoints], week_start, week_index)
                else
                    weekly_data = generate_week_data(filtered_dfs[period_start][dataframe_timepoints], week_start, timepoints_dataframes_dict[dataframe_timepoints]["timepoint_column_name"])
                end

                filtered_dfs[period_start]["weekly_data"][week_index+1][dataframe_timepoints] = weekly_data
            end
        end

    end
    
    for (period, value) in filtered_dfs
        println("Currently writing period $period")

        parentpath = CURRENT_STUDY_CASE*"inputs_"*string(period)
        if !isdir(parentpath)
            mkpath(parentpath)  # Create any missing directories
        end

        #Para cada semana se guardan los datos que no dependen de la semana, y los datos correspondientes de la semana.
        for week_index in 0:max_period_index
            
            week_parentpath = parentpath*"/"*string(week_index)
            if !isdir(week_parentpath)
                mkpath(week_parentpath)  # Create any missing directories
            end

            for (csv_file, value) in filtered_dfs[period]
                if (csv_file != "weekly_data") && !(csv_file in keys(timepoints_dataframes_dict))
                    file_path = "/"*csv_file*".csv"
                    path_UC = week_parentpath*"/inputs_dispatch"
                    path_dispatch = week_parentpath*"/inputs_unit_commitment"
                    if !isdir(path_UC)
                        mkpath(path_UC)  # Create any missing directories
                    end
                    if !isdir(path_dispatch)
                        mkpath(path_dispatch)  # Create any missing directories
                    end
                    full_path_UC = path_UC*file_path
                    full_path_dispatch = path_dispatch*file_path
                    # println("Saving $file_path for week $week_index")
                    CSV.write(full_path_UC, value)
                    CSV.write(full_path_dispatch, value)
                end            
            end
            for (csv_file, value) in filtered_dfs[period]["weekly_data"][week_index+1]
                file_path = "/"*csv_file*".csv"
                path_UC = week_parentpath*"/inputs_dispatch"
                path_dispatch = week_parentpath*"/inputs_unit_commitment"
                if !isdir(path_UC)
                    mkpath(path_UC)  # Create any missing directories
                end
                if !isdir(path_dispatch)
                    mkpath(path_dispatch)  # Create any missing directories
                end
                full_path_UC = path_UC*file_path
                full_path_dispatch = path_dispatch*file_path
                # println("Saving $file_path for week $week_index")
                CSV.write(full_path_UC, value)
                CSV.write(full_path_dispatch, value)
                println("Saving $file_path for week $week_index")
                CSV.write(full_path_UC, value)
                CSV.write(full_path_dispatch, value)
            end

            #Se copian los modulos para las corridas y los switch inputs versions correspondientes
            modules_txt_target_UC = week_parentpath*"/inputs_unit_commitment/modules.txt"
            switch_inputs_version_txt_target_UC = week_parentpath*"/inputs_unit_commitment/switch_inputs_version.txt"
            modules_txt_target_dispatch= week_parentpath*"/inputs_dispatch/modules.txt"
            switch_inputs_version_txt_target_dispatch = week_parentpath*"/inputs_dispatch/switch_inputs_version.txt"
            cp(modules_uc_txt, modules_txt_target_UC, force=true)
            cp(switch_inputs_version_txt, switch_inputs_version_txt_target_UC, force=true)
            cp(modules_dispatch_txt, modules_txt_target_dispatch, force=true)
            cp(switch_inputs_version_txt, switch_inputs_version_txt_target_dispatch, force=true)
        end
    end
end
input_path = CURRENT_STUDY_CASE*CURRENT_INPUTS_FOLDER
generar_period_scenarios(input_path);
"C:/Users/Ignac/Trabajo_Centra/Catedra-LDES/CII-Centra-EDF/Operacion/escenarios/CaseBase_N/TA/inputs_opp/timeseries.csv" 