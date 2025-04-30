using CSV
using DataFrames
using Random

function generate_marginal_cost_dummy_data_csv(input_data_load_zones_route::String, input_data_timepoints_route::String, output_data_route::String)

    df_data_load_zones = CSV.read(input_data_load_zones_route, DataFrame)
    df_data_timepoints = CSV.read(input_data_timepoints_route, DataFrame)

    df_combined = DataFrame(Iterators.product(df_data_load_zones.LOAD_ZONE, df_data_timepoints.timestamp))
    rename!(df_combined, [:load_zone, :timepoint])

    df_combined.marginal_cost = rand(20:60, nrow(df_combined))

    CSV.write(output_data_route, df_combined)

end

input_data_load_zones_route = "inputs/load_zones.csv"
input_data_timepoints_route = "inputs/timepoints.csv"
output_data_route = "inputs_test/marginal_cost.csv"
generate_marginal_cost_dummy_data_csv(input_data_load_zones_route, input_data_timepoints_route, output_data_route);