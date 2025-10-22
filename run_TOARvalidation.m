function [valOut, valPairOut] = run_TOARvalidation(valParam)
% run_TOARvalidation - Run TOAR validation analysis based on specified parameters
% SYNTAX:
%   [valOut, valPairOut] = run_TOARvalidation(valParam)
% INPUTS:
%   valParam - Structure with fields:
%   ... See setData_val.m for details
% OUTPUTS:
%   valOut     - Table with overall validation statistics
%   valPairOut - Structure with all obs/predicted pairs
%
valParam.softData = [];
[obs, go, cov, KG, KS, BMEparam] = setData_val(valParam);

validationMethod = valParam.method;
% change the string to lower case to avoid case sensitivity issues
validationMethod = lower(validationMethod);

switch validationMethod
    case 'loocv'
        % Leave-One-Out Cross-Validation (Monthly approach)
        fprintf('\nUsing monthly LOOCV validation approach...\n');
        [valOut, valPairOut] = validateTOARsBME(obs, go, cov, BMEparam, valParam);
    case 'kfold'
        % K-Fold Cross-Validation
        if ~exist('validateTOAR_kFold', 'file')
            error('K-Fold validation not implemented yet');
        end
        [valOut, valPairOut] = validateTOAR_kFold(obs, go, cov, KG, KS, BMEparam, valParam);
    case 'rcv'
        % Random Cross-Validation
        if ~exist('validateTOAR_RCV', 'file')
            error('Random cross-validation not implemented yet');
        end
        [valOut, valPairOut] = validateTOAR_RCV(obs, go, cov, KG, KS, BMEparam, valParam);
    otherwise
        error('Unknown validation method: %s', valParam.method);
end

