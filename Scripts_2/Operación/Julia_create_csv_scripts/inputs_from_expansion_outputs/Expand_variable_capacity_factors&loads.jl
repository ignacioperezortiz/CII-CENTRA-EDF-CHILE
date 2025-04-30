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

function process_variable_capacity_factors(input_url::String, input_variable_cap_factors::String)
    df_timeseries = CSV.read(input_url*"timeseries.csv", DataFrame)
    df_timepoint = CSV.read(input_url*"timepoints.csv", DataFrame)
    df_periods = CSV.read(input_url*"periods.csv", DataFrame)
    df_variable_capacity_factors = CSV.read(input_variable_cap_factors*"variable_capacity_factors_sin_cuatridias.csv", DataFrame)
    df_loads = CSV.read(input_variable_cap_factors*"loads_sin_cuatridias.csv", DataFrame)
    df_gen_build_predetermined = CSV.read(input_url*"gen_build_predetermined.csv", DataFrame)

    filtered_dfs = Dict()
    timepoints_dataframes_dict = Dict(
        "variable_capacity_factors" => Dict("timepoint_column_name" => "timepoint"),
        "loads" => Dict("timepoint_column_name" => "TIMEPOINT"),
    )
    generation_projects_of_interest_array = Set([])

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
        filtered_periods_df = filter(row -> row[:period_start] == period_start, df_periods) #ADDED


        if index == 1
            filtered_gen_build_predetermined_df = filter(row -> row[:build_year] < period_end && row[:build_gen_predetermined] > 0, df_gen_build_predetermined)
        else
            filtered_gen_build_predetermined_df = filter(row -> row[:build_year] >= period_start && row[:build_year] < period_end && row[:build_gen_predetermined] > 0, df_gen_build_predetermined)
        end
        
        # Filter by generation projects
        generation_projects_of_interest = Set(filtered_gen_build_predetermined_df.GENERATION_PROJECT)
        generation_projects_of_interest_array = union(generation_projects_of_interest_array, generation_projects_of_interest)

        filtered_variable_capacity_factors_df = filter(row -> row[:GENERATION_PROJECT] in generation_projects_of_interest_array && row[:timepoint] in timepoints_of_interest, df_variable_capacity_factors)

        filtered_loads_df = filter(row -> row[:TIMEPOINT] in timepoints_of_interest, df_loads)

        # Store the filtered DataFrame in a dictionary
        filtered_dfs[period_start] = Dict(
            "timeseries" => filtered_timeseries_df,
            "timepoints" => filtered_timepoint_df,
            "periods" => filtered_periods_df,
            "variable_capacity_factors" => filtered_variable_capacity_factors_df,
            "loads" => filtered_loads_df,
            "weekly_data" => Dict(),
        )
        
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
                    if csv_file == "variable_capacity_factors" || csv_file == "loads"
                        CSV.write(full_path_UC, value)
                        CSV.write(full_path_dispatch, value)
                    end
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
                # Add this condition:
                if csv_file == "variable_capacity_factors" || csv_file == "loads"
                    CSV.write(full_path_UC, value)
                    CSV.write(full_path_dispatch, value)
                    println("Saving $file_path for week $week_index")
                end
            end
        end
    end
end

input_path = CURRENT_STUDY_CASE*CURRENT_INPUTS_FOLDER
input_variable_cap_factors = CURRENT_STUDY_CASE
process_variable_capacity_factors(input_path, input_variable_cap_factors);
