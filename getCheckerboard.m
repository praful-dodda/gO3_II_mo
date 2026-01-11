% File: getCheckerboard.m
function [obs_train, obs_val, is_box_for_validation] = getCheckerboard(obs_data_input, s_deg)
    % Assigns observation points to alternating training and validation sets
    % based on a spatial checkerboard grid.

    % Assumes obs_data_input.sMS is [lon, lat]
    lon_coords = obs_data_input.sMS(:,1);
    lat_coords = obs_data_input.sMS(:,2);

    lon_step = 2 * s_deg;
    lat_step = s_deg;

    lon_edges = (floor(min(lon_coords)/lon_step)*lon_step) : lon_step : (ceil(max(lon_coords)/lon_step)*lon_step);
    lat_edges = (floor(min(lat_coords)/lat_step)*lat_step) : lat_step : (ceil(max(lat_coords)/lat_step)*lat_step);

    num_lon_boxes = length(lon_edges) - 1;
    num_lat_boxes = length(lat_edges) - 1;

    is_box_for_validation = false(num_lat_boxes, num_lon_boxes);

    % Create alternating pattern
    for i_lat = 1:num_lat_boxes
        for i_lon = 1:num_lon_boxes
            if mod(i_lat + i_lon, 2) == 1
                is_box_for_validation(i_lat, i_lon) = true;
            end
        end
    end

    % Assign observations to validation or training
    is_obs_for_validation = false(size(lon_coords));
    for i_lat = 1:num_lat_boxes
        for i_lon = 1:num_lon_boxes
            obs_in_box = lon_coords >= lon_edges(i_lon) & lon_coords < lon_edges(i_lon+1) & ...
                         lat_coords >= lat_edges(i_lat) & lat_coords < lat_edges(i_lat+1);
            if is_box_for_validation(i_lat, i_lon)
                is_obs_for_validation(obs_in_box) = true;
            end
        end
    end

    val_idx = find(is_obs_for_validation);
    train_idx = find(~is_obs_for_validation);

    % Build output structs
    obs_val.sMS = obs_data_input.sMS(val_idx,:);
    obs_val.tME = obs_data_input.tME;
    obs_val.value = obs_data_input.value(val_idx,:);

    obs_train.sMS = obs_data_input.sMS(train_idx,:);
    obs_train.tME = obs_data_input.tME;
    obs_train.value = obs_data_input.value(train_idx,:);
end
