%% demo_BMEfusionStory.m
% Demonstrate the "whole story" of BME data fusion for a smaller region.
%
% Produces a 2x3 figure:
%   Row 1 — Mean ozone (shared color scale):
%     [1] RAMP-corrected CTM soft data
%     [2] BME fusion posterior mean  (+ hard obs as dots)
%     [3] Difference: BME minus CTM
%   Row 2 — Uncertainty std dev (shared color scale):
%     [4] RAMP CTM std dev  (sqrt(lambda2))
%     [5] BME fusion std dev  (sqrt(XkBMEv))
%     [6] Uncertainty reduction: CTM_std minus BME_std
%
% To show the full 6-panel RAW→RAMP→BME story, uncomment step 5
% (requires the raw model output netcdf and loadRawCTMfromNC.m).

clear; clc; close all;

%% ---- 0. User settings -----------------------------------------------

% Display region (can be smaller than BME estimation area for detail).
% Options: Europe, W.Europe, CONUS, E.US, California, NE.US, E.Asia
%
% The BME_AREA_CODE is the area used when running estTOARsBME.
% The REGION can be equal to or smaller than BME_AREA_CODE's extent.
% E.g. BME run over CONUS (5) but display only California.
REGION_CHOICE = 'E.US';   % change here — what to DISPLAY
BME_AREA_CODE = 5;        % what area the BME result was estimated over

switch REGION_CHOICE
    case 'Europe'
        region   = [-15 40 35 72];
    case 'W.Europe'
        region   = [-10 20 36 60];
    case 'CONUS'
        region   = [-126 -66 24 50];
    case 'E.US'
        region   = [-100 -66 24 48];
    case 'California'
        region   = [-125 -114 32 42];
    case 'NE.US'
        region   = [-78 -70 38 43];
    case 'E.Asia'
        region   = [100 150 20 55];
    otherwise
        error('Unknown REGION_CHOICE: %s', REGION_CHOICE);
end
areaCode = BME_AREA_CODE;

% CTM model and years
CTM_MODEL = 'M3fusion';
YEARS     = [2016 2016];

% Which year/month to plot (index into ctm.tME)
YEAR_PLOT  = 2016;
MONTH_PLOT = 1;   % January

% Global offset scenario
GO_SCENARIO = 3;

% Resolution for the existing BME results
MAP_RES = 1.0;  % degrees

%% ---- 1. Load observational data ------------------------------------
fprintf('\n=== Loading observational data ===\n');
obs = getTOARobservationalData('all', YEARS);

%% ---- 2. Load global offset -----------------------------------------
fprintf('\n=== Loading global offset ===\n');
go  = getTOARglobalOffset(obs, GO_SCENARIO, 0);

%% ---- 3. Load RAMP-corrected CTM ------------------------------------
fprintf('\n=== Loading RAMP-corrected CTM (%s) ===\n', CTM_MODEL);
ctm = loadRAMPdata(CTM_MODEL, YEARS, 'D:\Users\praful\Documents\Data\ramp_data');

%% ---- 4. Find matching BME result file --------------------------------
fprintf('\n=== Locating BME result file ===\n');

tVal = YEAR_PLOT + (MONTH_PLOT - 1)/12;

% Build expected filename pattern
% Adjust pattern to match your actual files (stug or stg, land flag, etc.)
bmeDir  = '5BMEspatialPlots';
pattern = sprintf('BME*go%d*area%d*res%.2f*time%.2f*.mat', ...
                  GO_SCENARIO, areaCode, MAP_RES, tVal);
bmeFiles = dir(fullfile(bmeDir, pattern));

if isempty(bmeFiles)
    % Try without area code in pattern (area may differ)
    pattern2 = sprintf('BME*go%d*res%.2f*time%.2f*.mat', ...
                       GO_SCENARIO, MAP_RES, tVal);
    bmeFiles = dir(fullfile(bmeDir, pattern2));
end

if isempty(bmeFiles)
    % Try the global area files
    pattern3 = sprintf('BME*go%d*time%.2f*.mat', GO_SCENARIO, tVal);
    bmeFiles = dir(fullfile(bmeDir, pattern3));
    if ~isempty(bmeFiles)
        fprintf('  No area-specific file found; using first matching: %s\n', bmeFiles(1).name);
    end
end

if isempty(bmeFiles)
    error(['No BME result file found for GO=%d, area=%d, res=%.2f, time=%.2f\n' ...
           'Run estTOARsBME first, or adjust the parameters above.'], ...
           GO_SCENARIO, areaCode, MAP_RES, tVal);
end

% Prefer files that already have the right area code
areaTag = sprintf('area%d', areaCode);
areaMatch = find(contains({bmeFiles.name}, areaTag));
if ~isempty(areaMatch)
    bmeFile = fullfile(bmeFiles(areaMatch(1)).folder, bmeFiles(areaMatch(1)).name);
else
    bmeFile = fullfile(bmeFiles(1).folder, bmeFiles(1).name);
end
fprintf('  Using: %s\n', bmeFile);

%% ---- 5. (Optional) Load raw CTM to expand to 6-panel story ---------
% Uncomment to add a "Raw CTM → RAMP → BME" column pair:
%
%   nc_path  = sprintf('1data/CTM/model_output_data/netcdf_combined/%s_MDA8_combined.nc', CTM_MODEL);
%   p.ctmRaw = loadRawCTMfromNC(nc_path, YEAR_PLOT, MONTH_PLOT);
%
% (Set p.ctmRaw before step 7 to enable the full 6-panel layout)

%% ---- 6. Set story parameters ----------------------------------------
p = struct();
p.region      = region;
% Time index: find month in ctm.tME
p.timeIndex   = find(abs(ctm.tME - tVal) < 1/24, 1);
if isempty(p.timeIndex)
    [~, p.timeIndex] = min(abs(ctm.tME - tVal));
    fprintf('  Nearest time index %d (tME=%.4f) for requested %.4f\n', ...
            p.timeIndex, ctm.tME(p.timeIndex), tVal);
end

p.figDir      = fullfile('5BMEspatialPlots', 'story');
p.nxpix       = 250;
p.nypix       = 180;
p.interpMethod = 'natural';
p.obsMkrSize  = 55;
% p.ctmRaw is set in step 5 if raw CTM was loaded (optional)

% Color axis percentiles — tighter for cleaner maps
p.climMeanPct = [3 97];
p.climUncPct  = [0 95];

p.figTitle = sprintf('BME Data Fusion — %s, %s, Year %d Month %02d', ...
                     CTM_MODEL, REGION_CHOICE, YEAR_PLOT, MONTH_PLOT);

%% ---- 7. Create the story figure ------------------------------------
fprintf('\n=== Generating BME fusion story figure ===\n');
figPath = plotBMEfusionStory(ctm, bmeFile, obs, go, p);
fprintf('\nDone! Figure saved to:\n  %s\n', figPath);


