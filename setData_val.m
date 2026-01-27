function [obs, go, cov, KG, KS, BMEparam] = setData_val(valParam)
% setData_val - Set validation parameters and load data for TOAR analysis
%
% SYNTAX:
%   [obs, go, cov, KG, KS, BMEparam] = setData_val(valParam)
%
% INPUTS:
%   valParam - Structure with fields:
%              .stationTypes     - Station types to include
%              .timeRange        - [startYear endYear]
%              .logTransf        - Log transformation flag
%              .goScenario       - Global offset scenario
%              .temporalModel    - Temporal covariance model
%              .BMEmethod        - BME method code (8-digit string)
%              .softData         - (Optional) Soft data configuration:
%                                  .modelName - CTM model name (e.g., 'UKML')
%                                  .years     - Years to load
%                                  .dataDir   - Directory with parquet files
%                                  .forceReload - Force reload flag
%              .goPlot           - (Optional) Global offset plotting level
%              .forceGO          - (Optional) Force GO re-estimation
%              .forceCov         - (Optional) Force covariance re-estimation
%
% OUTPUTS:
%   obs       - Observational data structure
%   go        - Global offset structure
%   cov       - Covariance structure
%   KG        - General knowledge base
%   KS        - Site-specific knowledge base
%   BMEparam  - BME parameters
%
% DESCRIPTION:
%   This function loads all necessary data for validation including:
%   1. Observational data
%   2. Global offset
%   3. Covariance models
%   4. Soft data (CTM) if specified in BMEmethod
%   5. Knowledge bases for BME
%
%   Soft data is automatically loaded if BMEmethod indicates CTM usage
%   (2nd digit >= 1) and filtered to match the validation time range.
%
% EXAMPLES:
%   % Without soft data
%   valParam.stationTypes = 'all';
%   valParam.timeRange = [2015 2020];
%   valParam.BMEmethod = '10000132';  % No CTM
%   [obs, go, cov, KG, KS, BMEparam] = setData_val(valParam);
%
%   % With soft data
%   valParam.BMEmethod = '11000132';  % CTM enabled
%   valParam.softData.modelName = 'UKML';
%   valParam.softData.years = [2015:2020];
%   [obs, go, cov, KG, KS, BMEparam] = setData_val(valParam);

%% Set defaults
if ~isfield(valParam, 'goPlot'), valParam.goPlot = 0; end
if ~isfield(valParam, 'forceGO'), valParam.forceGO = 0; end
if ~isfield(valParam, 'forceCov'), valParam.forceCov = 0; end

%% Load Observational Data
fprintf('\n========================================\n');
fprintf('  LOADING VALIDATION DATA\n');
fprintf('========================================\n');

fprintf('Loading observational data...\n');
obs = getTOARobservationalData(valParam.stationTypes, valParam.timeRange, valParam.logTransf);

fprintf('  Loaded %d stations, %d time periods\n', size(obs.Z, 1), size(obs.Z, 2));
fprintf('  Valid data: %.1f%%\n', 100*sum(~isnan(obs.Z(:)))/numel(obs.Z));

%% Load Global Offset
fprintf('\nLoading global offset...\n');
go = getTOARglobalOffset(obs, valParam.goScenario, ...
        valParam.goPlot, valParam.forceGO, 0);

fprintf('  Global offset scenario: %d\n', go.scenario);

%% Load Covariance Model
fprintf('\nLoading covariance model...\n');
cov = getTOARautoCov(obs, go, valParam.temporalModel, valParam.forceCov);

fprintf('  Covariance models: %s\n', strjoin(cov.covmodel, ', '));

%% Check if Soft Data is Needed (based on BMEmethod)
BMEmethod8digits = valParam.BMEmethod;
CTMtype = str2double(BMEmethod8digits(2));  % 2nd digit indicates CTM usage

softDataForKB = [];  % Default: no soft data

if CTMtype >= 1
    fprintf('\nCTM data required (BMEmethod digit 2 = %d)\n', CTMtype);

    % Check if soft data configuration is provided
    if isfield(valParam, 'softData') && ~isempty(valParam.softData)
        fprintf('Loading soft data...\n');

        % Get soft data configuration
        if ~isfield(valParam.softData, 'modelName')
            error('softData.modelName required when CTMtype >= 1');
        end
        if ~isfield(valParam.softData, 'years')
            valParam.softData.years = valParam.timeRange(1):valParam.timeRange(2);
        end
        if ~isfield(valParam.softData, 'dataDir')
            valParam.softData.dataDir = fullfile('1data', 'CTM', 'ramp_data');
        end
        if ~isfield(valParam.softData, 'forceReload')
            valParam.softData.forceReload = 0;
        end

        % Load CTM data using loadRAMPdata
        try
            ctmDataFull = loadRAMPdata(valParam.softData.modelName, ...
                valParam.softData.years, ...
                valParam.softData.dataDir, ...
                valParam.softData.forceReload);

            fprintf('  Full CTM data loaded:\n');
            fprintf('    Model: %s\n', ctmDataFull.modelName);
            fprintf('    Grid points: %d\n', size(ctmDataFull.sMS, 1));
            fprintf('    Time periods (full): %d\n', length(ctmDataFull.tME));

            % Filter soft data to validation time range
            fprintf('\n  Filtering soft data to validation time range...\n');
            timeStart = valParam.timeRange(1);
            timeEnd = valParam.timeRange(2) + 1;  % Include full end year

            inTimeRange = (ctmDataFull.tME >= timeStart) & (ctmDataFull.tME < timeEnd);

            if sum(inTimeRange) == 0
                warning('No soft data in validation time range [%d, %d)', ...
                    valParam.timeRange(1), valParam.timeRange(2));
                softDataForKB = [];
            else
                % Create filtered soft data structure
                softDataFiltered = struct();
                softDataFiltered.modelName = ctmDataFull.modelName;
                softDataFiltered.sMS = ctmDataFull.sMS;
                softDataFiltered.tME = ctmDataFull.tME(inTimeRange);
                softDataFiltered.Z = ctmDataFull.Z(:, inTimeRange);
                softDataFiltered.Zv = ctmDataFull.Zv(:, inTimeRange);
                softDataFiltered.Zunit = ctmDataFull.Zunit;

                fprintf('    Filtered time periods: %d\n', length(softDataFiltered.tME));
                fprintf('    Time range: [%.2f, %.2f]\n', ...
                    min(softDataFiltered.tME), max(softDataFiltered.tME));
                fprintf('    Valid data: %.1f%%\n', ...
                    100*sum(~isnan(softDataFiltered.Z(:)))/numel(softDataFiltered.Z));

                % For multi-soft datasets (CTMtype=3), create cell array
                if CTMtype == 3
                    % If multiple models specified, load each
                    if iscell(valParam.softData.modelName)
                        softDataForKB = cell(1, length(valParam.softData.modelName));
                        softDataForKB{1} = softDataFiltered;

                        % Load additional models
                        for iModel = 2:length(valParam.softData.modelName)
                            modelName = valParam.softData.modelName{iModel};
                            fprintf('\n  Loading additional soft data: %s\n', modelName);

                            ctmExtra = loadRAMPdata(modelName, ...
                                valParam.softData.years, ...
                                valParam.softData.dataDir, ...
                                valParam.softData.forceReload);

                            % Filter to time range
                            softDataExtra = struct();
                            softDataExtra.modelName = ctmExtra.modelName;
                            softDataExtra.sMS = ctmExtra.sMS;
                            softDataExtra.tME = ctmExtra.tME(inTimeRange);
                            softDataExtra.Z = ctmExtra.Z(:, inTimeRange);
                            softDataExtra.Zv = ctmExtra.Zv(:, inTimeRange);
                            softDataExtra.Zunit = ctmExtra.Zunit;

                            softDataForKB{iModel} = softDataExtra;
                        end

                        fprintf('\n  Total soft datasets loaded: %d\n', length(softDataForKB));
                    else
                        % Single model for CTMtype=3
                        softDataForKB = {softDataFiltered};
                    end
                else
                    % CTMtype 1 or 2: single soft dataset
                    softDataForKB = softDataFiltered;
                end
            end

        catch ME
            warning(ME.identifier, 'Failed to load soft data: %s', ME.message);
            
            fprintf('  Proceeding without soft data.\n');
            softDataForKB = [];
        end

    else
        warning('BMEmethod requires CTM data (digit 2 = %d) but no softData configuration provided', CTMtype);
        fprintf('  Set valParam.softData.modelName, .years, .dataDir to enable soft data\n');
        fprintf('  Proceeding without soft data.\n');
    end
else
    fprintf('\nNo CTM data required (BMEmethod digit 2 = %d)\n', CTMtype);
end

%% Create Knowledge Base
fprintf('\nCreating knowledge base...\n');
[KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, ...
        softDataForKB, valParam.BMEmethod);

fprintf('  Hard data points: %d\n', length(KS.harddata.z));

if iscell(KS.softdata)
    totalSoftPoints = 0;
    for i = 1:length(KS.softdata)
        if ~isempty(KS.softdata{i}.z)
            totalSoftPoints = totalSoftPoints + length(KS.softdata{i}.z);
        end
    end
    fprintf('  Soft data points (total across %d datasets): %d\n', ...
        length(KS.softdata), totalSoftPoints);
elseif ~isempty(KS.softdata.z)
    fprintf('  Soft data points: %d\n', length(KS.softdata.z));
else
    fprintf('  Soft data points: 0\n');
end

fprintf('\n========================================\n');
fprintf('  DATA LOADING COMPLETE\n');
fprintf('========================================\n\n');

end
