function [obs, go, cov, KG, KS, BMEparam] = setData_val(valParam)
% setData_val - Set validation parameters for TOAR analysis
% SYNTAX:
%   setData_val(valParam)
% INPUTS:
%   valParam - Structure with fields:
%
% get observational data
obs = getTOARobservationalData(valParam.stationTypes, valParam.timeRange, valParam.logTransf);

fprintf('  Loaded %d stations, %d time periods\n', size(obs.Z, 1), size(obs.Z, 2));
fprintf('  Valid data: %.1f%%\n', 100*sum(~isnan(obs.Z(:)))/numel(obs.Z));

% get global offset data
go = getTOARglobalOffset(obs, valParam.goScenario, ...
        valParam.goPlot, valParam.forceGO, 0);

% get covariance model
cov = getTOARautoCov(obs, go, valParam.temporalModel, valParam.forceCov);

% get knowledge base for BME analysis
[KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, ...
        valParam.softData, valParam.BMEmethod);

fprintf('  Hard data points: %d\n', length(KS.harddata.z));
if ~isempty(KS.softdata.z)
    fprintf('  Soft data points: %d\n', length(KS.softdata.z));
else
    fprintf('  Soft data points: 0\n');
end