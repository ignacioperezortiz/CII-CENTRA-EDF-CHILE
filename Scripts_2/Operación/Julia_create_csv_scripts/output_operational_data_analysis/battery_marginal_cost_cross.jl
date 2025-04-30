using CSV
using DataFrames
include("../global_vars.jl")

function generate_battery_mg_cost_df(input_data_gen_info_route::String, input_data_battery_dispatch_route::String, input_data_marginal_cost_route::String)
    
    periods = [2029, 2030, 2031, 2033, 2040, 2050]

    for period in periods
        period = string(period)
        df_data_gen_info = CSV.read(input_data_gen_info_route, DataFrame)
        df_data_battery_dispatch = CSV.read(input_data_battery_dispatch_route*"_"*period*".csv", DataFrame)
        df_data_marginal_cost = CSV.read(input_data_marginal_cost_route*"_"*period*".csv", DataFrame)

        # 1. Merge the battery-zone data with charge-discharge data
        df = leftjoin(df_data_battery_dispatch, df_data_gen_info, on=:generation_project => :GENERATION_PROJECT)

        # 2. Merge the marginal cost data
        df = leftjoin(df, df_data_marginal_cost, on=[:gen_load_zone => :load_zone, :timepoint])
        
        # # 3. Calculate charging cost (charge * marginal_cost) and discharging earnings (discharge * marginal_cost)
        df.charge_cost = df.ChargeMW .* df.marginal_cost ./ df.factor
        df.discharge_earnings = df.DischargeMW .* df.marginal_cost ./ df.factor
        
        # # 4. Optionally, group by battery to get total cost and earnings for each battery
        result = combine(groupby(df, :generation_project),
                        :charge_cost => sum => :total_charge_cost,
                        :discharge_earnings => sum => :total_discharge_earnings)
                        
        df = select(df, [:generation_project, :timepoint, :charge_cost, :discharge_earnings])

        CSV.write(CURRENT_STUDY_CASE*CURRENT_OUTPUTS_FOLDER*"battery_operational_results_"*period*".csv", result)

        CSV.write(CURRENT_STUDY_CASE*CURRENT_OUTPUTS_FOLDER*"battery_operational_results_extended_"*period*".csv", df)
    end


end

input_data_gen_info_route = CURRENT_STUDY_CASE*CURRENT_INPUTS_FOLDER*"gen_info.csv"
input_data_battery_dispatch_route = CURRENT_STUDY_CASE*CURRENT_OUTPUTS_FOLDER*"consolidated_dispatch"
input_data_marginal_cost_route = CURRENT_STUDY_CASE*CURRENT_OUTPUTS_FOLDER*"consolidated_marginal_cost"
generate_battery_mg_cost_df(input_data_gen_info_route, input_data_battery_dispatch_route, input_data_marginal_cost_route);