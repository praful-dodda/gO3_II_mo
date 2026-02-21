function [status, report] = verifySoftDataFiles(BMEmethod, years, varargin)
% verifySoftDataFiles - Verify availability of soft-data files for BME method
%
% Checks if all required RAMP-corrected CTM parquet files and spatial grid
% files exist for the specified BME method and year range. Provides detailed
% reporting of missing files and data completeness.
%
% SYNTAX:
%   [status, report] = verifySoftDataFiles(BMEmethod, years)
%   [status, report] = verifySoftDataFiles(BMEmethod, years, 'Name', Value)
%
% INPUTS:
%   BMEmethod - BME method code (e.g., '13000313-02-10')
%   years     - Year or year range to check (e.g., 2017 or [2015 2020])
%
% OPTIONAL PARAMETERS:
%   'dataDir'      - Root directory for soft data files
%                    (default: fullfile('1data', 'CTM'))
%   'rampVersion'  - RAMP version to check (default: 3)
%   'verbose'      - Display detailed report (default: true)
%   'throwError'   - Throw error if files missing (default: false)
%
% OUTPUTS:
%   status - Boolean, true if all required files exist
%   report - Structure with detailed verification results:
%            .BMEmethod        - Input BME method code
%            .years            - Input year range
%            .CTMmodels        - Cell array of required models
%            .allFilesExist    - Boolean, overall status
%            .missingFiles     - Cell array of missing file paths
%            .missingByModel   - Struct with missing files per model
%                                (field names use underscores, e.g., MERRA2_GMI)
%            .spatialGrids     - Struct with spatial grid file status
%                                (field names use underscores, e.g., MERRA2_GMI)
%            .dataFiles        - Struct with parquet file status per model/year
%                                (field names use underscores, e.g., MERRA2_GMI)
%            .summary          - Human-readable summary string
%
% NOTE: Model names with hyphens (e.g., 'MERRA2-GMI') are converted to
%       underscores (e.g., 'MERRA2_GMI') when used as struct field names.
%       The original names are preserved in the .modelName field.
%
% EXAMPLES:
%   % Check single year
%   [status, report] = verifySoftDataFiles('13000313-02', 2017);
%   if ~status
%       fprintf('Missing files:\n');
%       disp(report.missingFiles);
%   end
%
%   % Check multiple years with custom directory
%   [status, report] = verifySoftDataFiles('13000313-02-10', [2015 2020], ...
%       'dataDir', 'd:\Data\ramp_data\', 'verbose', true);
%
%   % Throw error if files missing (useful in automated workflows)
%   verifySoftDataFiles('13000313-02', 2017, 'throwError', true);
%
% See also: parseBMEcode, decodeCTMmodels, loadRAMPdata, getTOARSoftData

%% Parse inputs
p = inputParser;
addRequired(p, 'BMEmethod', @ischar);
addRequired(p, 'years', @isnumeric);
addParameter(p, 'dataDir', fullfile('1data', 'CTM'), @ischar);
addParameter(p, 'rampVersion', 3, @isnumeric);
addParameter(p, 'verbose', true, @islogical);
addParameter(p, 'throwError', false, @islogical);

parse(p, BMEmethod, years, varargin{:});
opts = p.Results;

% Ensure years is a vector
if isscalar(years)
    years = years:years;
end

%% Initialize report structure
report = struct();
report.BMEmethod = BMEmethod;
report.years = years;
report.dataDir = opts.dataDir;
report.rampVersion = opts.rampVersion;
report.CTMmodels = {};
report.allFilesExist = true;
report.missingFiles = {};
report.missingByModel = struct();
report.spatialGrids = struct();
report.dataFiles = struct();
report.summary = '';

%% Parse BME method to get required models
if opts.verbose
    fprintf('\n========================================\n');
    fprintf('  SOFT DATA FILE VERIFICATION\n');
    fprintf('========================================\n');
    fprintf('BME Method: %s\n', BMEmethod);
    fprintf('Years: %s\n', mat2str(years));
    fprintf('Data directory: %s\n', opts.dataDir);
    fprintf('RAMP version: v%d\n', opts.rampVersion);
    fprintf('========================================\n\n');
end

% Parse BME code
try
    [obsType, CTMtype, ~, ~, ~, ~, ctm_models] = parseBMEcode(BMEmethod);
catch ME
    error('Failed to parse BME method code ''%s'': %s', BMEmethod, ME.message);
end

% Check if soft data required
if CTMtype == 0 || isempty(ctm_models)
    if opts.verbose
        fprintf('✓ No soft data required (CTMtype = 0)\n');
        fprintf('  All files present: N/A\n\n');
    end
    report.CTMmodels = {};
    report.allFilesExist = true;
    report.summary = 'No soft data required';
    status = true;
    return;
end

report.CTMmodels = ctm_models;

if opts.verbose
    fprintf('Required CTM models: %d\n', length(ctm_models));
    for i = 1:length(ctm_models)
        fprintf('  %d. %s\n', i, ctm_models{i});
    end
    fprintf('\n');
end

%% Check spatial grid files
if opts.verbose
    fprintf('Checking spatial grid files...\n');
end

spatialGridDir = fullfile(opts.dataDir, 'model_output_data', 'spatial_grids');

for iModel = 1:length(ctm_models)
    modelName = ctm_models{iModel};

    % Sanitize model name for use as struct field (replace hyphens with underscores)
    modelFieldName = strrep(modelName, '-', '_');

    spatialGridFile = sprintf('%s_spatial_grid.mat', modelName);
    spatialGridPath = fullfile(spatialGridDir, spatialGridFile);

    exists = exist(spatialGridPath, 'file') == 2;

    report.spatialGrids.(modelFieldName).modelName = modelName;
    report.spatialGrids.(modelFieldName).file = spatialGridPath;
    report.spatialGrids.(modelFieldName).exists = exists;

    if ~exists
        report.allFilesExist = false;
        report.missingFiles{end+1} = spatialGridPath;
        if ~isfield(report.missingByModel, modelFieldName)
            report.missingByModel.(modelFieldName) = {};
        end
        report.missingByModel.(modelFieldName){end+1} = spatialGridPath;

        if opts.verbose
            fprintf('  ✗ %s: MISSING\n', spatialGridFile);
        end
    else
        if opts.verbose
            fprintf('  ✓ %s: found\n', spatialGridFile);
        end
    end
end

if opts.verbose
    fprintf('\n');
end

%% Check parquet data files for each model and year
if opts.verbose
    fprintf('Checking RAMP-corrected parquet files...\n');
end

for iModel = 1:length(ctm_models)
    modelName = ctm_models{iModel};

    % Sanitize model name for use as struct field (replace hyphens with underscores)
    modelFieldName = strrep(modelName, '-', '_');

    if opts.verbose
        fprintf('\nModel: %s\n', modelName);
    end

    for iYear = 1:length(years)
        year = years(iYear);

        % Construct filenames
        lambda1File = sprintf('lambda1_%s_%d_v%d-parallel.parquet', ...
            modelName, year, opts.rampVersion);
        lambda2File = sprintf('lambda2_%s_%d_v%d-parallel.parquet', ...
            modelName, year, opts.rampVersion);

        lambda1Path = fullfile(opts.dataDir, lambda1File);
        lambda2Path = fullfile(opts.dataDir, lambda2File);

        % Check existence
        lambda1Exists = exist(lambda1Path, 'file') == 2;
        lambda2Exists = exist(lambda2Path, 'file') == 2;

        bothExist = lambda1Exists && lambda2Exists;

        % Store in report
        yearKey = sprintf('year%d', year);
        report.dataFiles.(modelFieldName).(yearKey).modelName = modelName;
        report.dataFiles.(modelFieldName).(yearKey).year = year;
        report.dataFiles.(modelFieldName).(yearKey).lambda1.file = lambda1Path;
        report.dataFiles.(modelFieldName).(yearKey).lambda1.exists = lambda1Exists;
        report.dataFiles.(modelFieldName).(yearKey).lambda2.file = lambda2Path;
        report.dataFiles.(modelFieldName).(yearKey).lambda2.exists = lambda2Exists;
        report.dataFiles.(modelFieldName).(yearKey).bothExist = bothExist;

        % Track missing files
        if ~lambda1Exists
            report.allFilesExist = false;
            report.missingFiles{end+1} = lambda1Path;
            if ~isfield(report.missingByModel, modelFieldName)
                report.missingByModel.(modelFieldName) = {};
            end
            report.missingByModel.(modelFieldName){end+1} = lambda1Path;
        end

        if ~lambda2Exists
            report.allFilesExist = false;
            report.missingFiles{end+1} = lambda2Path;
            if ~isfield(report.missingByModel, modelFieldName)
                report.missingByModel.(modelFieldName) = {};
            end
            report.missingByModel.(modelFieldName){end+1} = lambda2Path;
        end

        % Verbose output
        if opts.verbose
            if bothExist
                fprintf('  ✓ Year %d: lambda1 + lambda2 found\n', year);
            else
                fprintf('  ✗ Year %d: ', year);
                if ~lambda1Exists
                    fprintf('lambda1 MISSING');
                end
                if ~lambda1Exists && ~lambda2Exists
                    fprintf(', ');
                end
                if ~lambda2Exists
                    fprintf('lambda2 MISSING');
                end
                fprintf('\n');
            end
        end
    end
end

%% Generate summary
if opts.verbose
    fprintf('\n========================================\n');
    fprintf('  VERIFICATION SUMMARY\n');
    fprintf('========================================\n');
end

nModels = length(ctm_models);
nYears = length(years);
nExpectedFiles = nModels + (nModels * nYears * 2);  % spatial grids + (lambda1 + lambda2 per year)
nMissingFiles = length(report.missingFiles);
nFoundFiles = nExpectedFiles - nMissingFiles;

report.summary = sprintf('%d/%d files found (%d missing)', ...
    nFoundFiles, nExpectedFiles, nMissingFiles);

if opts.verbose
    fprintf('Models checked: %d\n', nModels);
    fprintf('Years checked: %d\n', nYears);
    fprintf('Expected files: %d\n', nExpectedFiles);
    fprintf('  - Spatial grids: %d\n', nModels);
    fprintf('  - Parquet files: %d (lambda1 + lambda2 × models × years)\n', nModels * nYears * 2);
    fprintf('Found: %d\n', nFoundFiles);
    fprintf('Missing: %d\n', nMissingFiles);
    fprintf('\n');

    if report.allFilesExist
        fprintf('✓ ALL FILES PRESENT\n');
    else
        fprintf('✗ MISSING FILES DETECTED\n\n');
        fprintf('Missing files by model:\n');
        missingModels = fieldnames(report.missingByModel);
        for i = 1:length(missingModels)
            modelFieldName = missingModels{i};
            % Display with hyphens restored
            displayName = strrep(modelFieldName, '_', '-');
            nMissing = length(report.missingByModel.(modelFieldName));
            fprintf('  %s: %d missing\n', displayName, nMissing);
        end

        fprintf('\nFirst 10 missing file paths:\n');
        nShow = min(10, length(report.missingFiles));
        for i = 1:nShow
            fprintf('  %d. %s\n', i, report.missingFiles{i});
        end
        if length(report.missingFiles) > 10
            fprintf('  ... and %d more\n', length(report.missingFiles) - 10);
        end
    end
    fprintf('========================================\n\n');
end

status = report.allFilesExist;

%% Handle errors if requested
if opts.throwError && ~status
    error(['Missing soft-data files for BME method ''%s'':\n' ...
           '  Models: %s\n' ...
           '  Years: %s\n' ...
           '  Missing: %d/%d files\n' ...
           'Run with verbose=true for detailed list.'], ...
           BMEmethod, strjoin(ctm_models, ', '), mat2str(years), ...
           nMissingFiles, nExpectedFiles);
end

end
