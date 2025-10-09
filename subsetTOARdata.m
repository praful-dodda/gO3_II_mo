function [trainObs, testObs] = subsetTOARdata(obs, trainRatio, withinYears)
% subsetTOARdata - Split TOAR obs data into training and test sets
%
% SYNTAX:
%   [trainObs, testObs] = subsetTOARdata(obs, trainRatio, withinYears)
%
% INPUTS:
%   obs        - Structure containing TOAR observational data
%   trainRatio - Proportion of data for training (default 0.95)
%   withinYears - Years to include in analysis (default [] = all years)
%
% OUTPUTS:
%   trainObs - Structure for training data
%   testObs  - Structure for testing data
%
% EXAMPLE:
%   obs = getTOARobservationalData('all', [2010 2020]);
%   [trainObs, testObs] = subsetTOARdata(obs, 0.95);
%   
%   % Or restrict to specific years
%   [trainObs, testObs] = subsetTOARdata(obs, 0.90, [2015 2016 2017]);

if nargin < 2
    trainRatio = 0.95;
end

if nargin < 3
    withinYears = [];
end

% If withinYears is specified, subset data to those years
if ~isempty(withinYears)
    % Extract year from decimal time (floor to get integer year)
    obsYears = floor(obs.tME);
    idxWithinYears = ismember(obsYears, withinYears);
    
    % Replace data outside specified years with NaNs
    obs.Z(:, ~idxWithinYears) = NaN;
    obs.Y(:, ~idxWithinYears) = NaN;
end

% Total number of non-NaN data points
totalData = sum(~isnan(obs.Z(:)));

% Number of data points for training
trainData = round(totalData * trainRatio);

% Get indices of non-NaN data points
idxNonNan = find(~isnan(obs.Z(:)));

% Randomly select training data points
idxTrain = randsample(idxNonNan, trainData);

% Get indices of test data points
idxTest = setdiff(idxNonNan, idxTrain);

% Create training set
trainObs = obs;
trainObs.Z(idxTest) = NaN;
trainObs.Y(idxTest) = NaN;

% Create test set
testObs = obs;
testObs.Z(idxTrain) = NaN;
testObs.Y(idxTrain) = NaN;

% Remove rows (stations) with all NaNs from training set
idxRowsTrain = any(~isnan(trainObs.Z), 2);
trainObs.Z = trainObs.Z(idxRowsTrain, :);
trainObs.Y = trainObs.Y(idxRowsTrain, :);
trainObs.sMS = trainObs.sMS(idxRowsTrain, :);
trainObs.stationID = trainObs.stationID(idxRowsTrain);
trainObs.stationType = trainObs.stationType(idxRowsTrain);

% Remove rows (stations) with all NaNs from test set
idxRowsTest = any(~isnan(testObs.Z), 2);
testObs.Z = testObs.Z(idxRowsTest, :);
testObs.Y = testObs.Y(idxRowsTest, :);
testObs.sMS = testObs.sMS(idxRowsTest, :);
testObs.stationID = testObs.stationID(idxRowsTest);
testObs.stationType = testObs.stationType(idxRowsTest);

% Remove columns (times) with all NaNs from training set
idxColsTrain = any(~isnan(trainObs.Z), 1);
trainObs.Z = trainObs.Z(:, idxColsTrain);
trainObs.Y = trainObs.Y(:, idxColsTrain);
trainObs.tME = trainObs.tME(idxColsTrain);

% Remove columns (times) with all NaNs from test set
idxColsTest = any(~isnan(testObs.Z), 1);
testObs.Z = testObs.Z(:, idxColsTest);
testObs.Y = testObs.Y(:, idxColsTest);
testObs.tME = testObs.tME(idxColsTest);

% Print summary statistics
fprintf('\nData split summary:\n');
fprintf('  Training set: %d stations, %d time points, %d valid observations\n', ...
    size(trainObs.Z, 1), size(trainObs.Z, 2), sum(~isnan(trainObs.Z(:))));
fprintf('  Test set: %d stations, %d time points, %d valid observations\n', ...
    size(testObs.Z, 1), size(testObs.Z, 2), sum(~isnan(testObs.Z(:))));
fprintf('  Train/test ratio: %.2f / %.2f\n', ...
    sum(~isnan(trainObs.Z(:)))/totalData, sum(~isnan(testObs.Z(:)))/totalData);

end