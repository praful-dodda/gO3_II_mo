function rawCtm = loadRawCTMfromNC(nc_path, year_plot, month_plot)
% loadRawCTMfromNC - Load raw (pre-RAMP) CTM output from a combined NetCDF file
%
% Returns a structure compatible with the storyParam.ctmRaw field of
% plotBMEfusionStory, or [] if the file cannot be read.
%
% SYNTAX:
%   rawCtm = loadRawCTMfromNC(nc_path, year_plot, month_plot)
%
% INPUTS:
%   nc_path    - Path to the combined NetCDF file, e.g.:
%                '1data/CTM/model_output_data/netcdf_combined/UKML_MDA8_combined.nc'
%   year_plot  - Year to extract (e.g., 2016)
%   month_plot - Month to extract (1-12)
%
% OUTPUTS:
%   rawCtm - Structure with fields:
%            .sMS       [nGrid x 2]  [lon lat] coordinates
%            .Z         [nGrid x 1]  ozone values (ppb)
%            .tME       scalar       decimal year of this time step
%            .modelName string       derived from filename
%            .lon, .lat column vectors (same data as sMS columns)
%
% EXAMPLE:
%   nc  = '1data/CTM/model_output_data/netcdf_combined/UKML_MDA8_combined.nc';
%   raw = loadRawCTMfromNC(nc, 2016, 1);   % January 2016
%   p.ctmRaw = raw;
%   figPath = plotBMEfusionStory(ctm, bmeFile, obs, go, p);

rawCtm = [];

if ~exist(nc_path, 'file')
    warning('loadRawCTMfromNC: file not found: %s', nc_path);
    return;
end

try
    %% Read variable catalogue
    info      = ncinfo(nc_path);
    var_names = {info.Variables.Name};

    %% Find ozone variable
    oz_var = '';
    candidates = {'mda8','dma8','ozone','o3','MDA8','O3','DMA8'};
    for k = 1:length(candidates)
        if any(strcmpi(var_names, candidates{k}))
            oz_var = candidates{k};
            break;
        end
    end
    if isempty(oz_var)
        warning('loadRawCTMfromNC: no ozone variable found in %s\n  Variables: %s', ...
                nc_path, strjoin(var_names, ', '));
        return;
    end

    %% Read spatial coordinates
    lon_raw = double(ncread(nc_path, 'lon'));
    lat_raw = double(ncread(nc_path, 'lat'));

    %% Read and interpret time axis
    time_raw = double(ncread(nc_path, 'time'));
    tVal_req = year_plot + (month_plot - 1) / 12;

    if max(time_raw) > 100000   % YYYYMM integer format (e.g. 201601)
        times_dec = floor(time_raw/100) + (mod(time_raw,100) - 1)/12;
    elseif max(time_raw) > 3000  % integer years * 12 or similar — treat as months since 1850
        % months since epoch 1850-01: convert to decimal year
        epoch_year  = 1850;
        times_dec   = epoch_year + time_raw / 12;
    else
        % Assume already decimal years
        times_dec = time_raw;
    end

    [~, iT] = min(abs(times_dec - tVal_req));
    fprintf('loadRawCTMfromNC: nearest time index %d  (%.4f) for requested %.4f\n', ...
            iT, times_dec(iT), tVal_req);

    %% Read ozone slice
    oz_info = info.Variables(strcmpi(var_names, oz_var));
    sz      = oz_info.Size;
    ndim    = length(sz);

    if ndim == 3
        % Typical layout: (lon x lat x time) or (lat x lon x time)
        ozone3d = double(ncread(nc_path, oz_var));
        ozone_slice = ozone3d(:,:,iT);   % lon x lat  (or lat x lon)

        % If first dim is lat (size matches lat_raw), transpose
        if sz(1) == length(lat_raw) && sz(2) == length(lon_raw)
            ozone_slice = ozone_slice';  % now lon x lat
        end

        % meshgrid: lon varies along columns, lat along rows
        [LON, LAT] = meshgrid(lon_raw, lat_raw);
        % ozone_slice is lon x lat, LON/LAT are lat x lon — transpose
        Z_flat = ozone_slice';   % lat x lon
        Z_flat = Z_flat(:);      % column vector, same order as meshgrid output

    elseif ndim == 2
        % Single time step already
        ozone2d = double(ncread(nc_path, oz_var));
        [LON, LAT] = meshgrid(lon_raw, lat_raw);
        if isequal(size(ozone2d), [length(lon_raw), length(lat_raw)])
            Z_flat = ozone2d';
        else
            Z_flat = ozone2d;
        end
        Z_flat = Z_flat(:);

    else
        warning('loadRawCTMfromNC: unexpected %d-D ozone variable', ndim);
        return;
    end

    %% Build output structure
    rawCtm.sMS       = [LON(:), LAT(:)];
    rawCtm.lon       = LON(:);
    rawCtm.lat       = LAT(:);
    rawCtm.Z         = Z_flat;
    rawCtm.tME       = tVal_req;

    % Model name from filename
    [~, fname, ~]    = fileparts(nc_path);
    rawCtm.modelName = strrep(fname, '_MDA8_combined', '') ;
    rawCtm.modelName = [rawCtm.modelName ' (raw)'];

    % Remove fill values (common: 1e30, -999, NaN)
    fillVal = 1e29;
    rawCtm.Z(abs(rawCtm.Z) > fillVal) = NaN;
    rawCtm.Z(rawCtm.Z < 0) = NaN;

    nValid = sum(~isnan(rawCtm.Z));
    fprintf('loadRawCTMfromNC: loaded %d valid grid points, range [%.1f %.1f] ppb\n', ...
            nValid, min(rawCtm.Z, [], 'omitnan'), max(rawCtm.Z, [], 'omitnan'));

catch ME
    warning('loadRawCTMfromNC: failed to load %s\n  Error: %s', nc_path, ME.message);
    rawCtm = [];
end

end
