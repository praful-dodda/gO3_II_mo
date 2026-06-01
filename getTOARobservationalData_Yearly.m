function obsY = getTOARobservationalData_Yearly(stationTypes, years, varargin)
% getTOARobservationalData_Yearly - Load per-station annual OSDMA8 from TOAR-II
%
% Annual counterpart to getTOARobservationalData (which returns monthly MDA8).
% Loads monthly MDA8, then aggregates each calendar year into OSDMA8 using
% computeOSDMA8. Computing OSDMA8 for year Y needs Jan(Y)..Mar(Y+1), so the
% monthly data is loaded over [min(years), max(years)+1] internally.
%
% SYNTAX:
%   obsY = getTOARobservationalData_Yearly('all', 2017)
%   obsY = getTOARobservationalData_Yearly('all', [2016 2017 2018], ...
%              'dataDir', 'D:\path\to\alt', 'completeness', 'partial')
%
% INPUTS:
%   stationTypes - 'all' | 'urban' | 'rural' | {cell}  (passed through)
%   years        - target year(s) to compute OSDMA8 for (scalar or vector)
%
% OPTIONAL (name/value):
%   'dataDir'      - directory holding TOAR-II-monthly-mda8-YYYY.csv files
%                    (default: ./1data/TOAR-II). Point this at a DIFFERENT
%                    folder to validate against an alternate obs file set.
%   'logTransf'    - 0/1 (default 0; OSDMA8 is computed in ppb, so 0)
%   'completeness' - 'strict' (default) | 'partial' | 'any'  (see computeOSDMA8)
%   'minMonths'    - threshold for 'partial' (default 4)
%
% OUTPUTS:
%   obsY.Z         - [nStations x nYears] OSDMA8 (ppb), NaN where undefined
%   obsY.sMS       - [nStations x 2] station coordinates [lon lat]
%   obsY.years     - [1 x nYears] the target years
%   obsY.stationID - [nStations x 1] cell of synthetic station IDs
%   obsY.Zname/Zunit - metadata ('OSDMA8-TOAR', 'ppb')
%   obsY.opts      - the completeness options used
%
% SEE ALSO: computeOSDMA8, getTOARobservationalData, runOSDMA8validation

%% Parse options
p = inputParser;
addParameter(p, 'dataDir', fullfile('.', '1data', 'TOAR-II'), @ischar);
addParameter(p, 'logTransf', 0, @isnumeric);
addParameter(p, 'completeness', 'strict', @ischar);
addParameter(p, 'minMonths', 4, @isnumeric);
parse(p, varargin{:});
opt = p.Results;

if opt.logTransf ~= 0
    warning('getTOARobservationalData_Yearly:logTransf', ...
        'OSDMA8 is computed in ppb; forcing logTransf=0 for loading.');
    opt.logTransf = 0;
end

years = years(:).';
startYear = min(years);
endYear   = max(years) + 1;            % +1 to cover wrap months Jan-Mar(Y+1)

%% Load monthly MDA8 (reuses the standard loader + its cache)
obs = getTOARobservationalData(stationTypes, [startYear endYear], ...
    opt.logTransf, opt.dataDir);

nStations = size(obs.Z, 1);
nMonths   = size(obs.Z, 2);
nYears    = numel(years);

cOpts = struct('completeness', opt.completeness, 'minMonths', opt.minMonths);

%% Aggregate each target year into OSDMA8
obsY.Z = nan(nStations, nYears);
for iy = 1:nYears
    Y = years(iy);
    % Column index for year y, month m in obs: (y-startYear)*12 + m
    cols = nan(1, 15);
    for k = 1:12                       % Jan(Y)..Dec(Y)
        cols(k) = (Y - startYear) * 12 + k;
    end
    for k = 13:15                      % Jan..Mar(Y+1)
        cols(k) = (Y + 1 - startYear) * 12 + (k - 12);
    end

    % Guard against months that fall outside the loaded range.
    inRange = cols >= 1 & cols <= nMonths;
    block = nan(nStations, 15);
    block(:, inRange) = obs.Z(:, cols(inRange));

    obsY.Z(:, iy) = computeOSDMA8(block, cOpts);
end

%% Metadata
obsY.sMS       = obs.sMS;
obsY.years     = years;
obsY.stationID = obs.stationID;
obsY.Zname     = 'OSDMA8-TOAR';
obsY.Zunit     = 'ppb';
obsY.Zlabel    = 'OSDMA8 TOAR-II (ppb)';
obsY.spaceUnit = 'deg';
obsY.opts      = cOpts;

fprintf('OSDMA8 loader: %d stations x %d year(s); %.1f%% defined (%s).\n', ...
    nStations, nYears, 100*mean(~isnan(obsY.Z(:))), opt.completeness);

end
