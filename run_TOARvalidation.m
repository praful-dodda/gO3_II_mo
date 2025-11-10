function run_TOARvalidation(valParam)
% run_TOARvalidation - Run TOAR validation analysis based on specified parameters
% SYNTAX:
%   run_TOARvalidation(valParam)
% INPUTS:
%   valParam - Structure with fields:
%   ... See setData_val.m for details
% OUTPUTS:
%   ...
valParam.softData = [];
[obs, go, cov, KG, KS, BMEparam] = setData_val(valParam);

validationMethod = valParam.method;
% change the string to lower case to avoid case sensitivity issues
validationMethod = lower(validationMethod);

switch validationMethod
    case 'loocv'
        % Leave-One-Out Cross-Validation
        [valOut, valPairOut] = validateTOAR_LOOCV(obs, go, cov, KG, KS, BMEparam, valParam);
    case 'kfold'
        % K-Fold Cross-Validation
        [valOut, valPairOut] = validateTOAR_kFold(obs, go, cov, KG, KS, BMEparam, valParam);
    case 'rcv'
        % Random Cross-Validation
        [valOut, valPairOut] = validateTOAR_RCV(obs, go, cov, KG, KS, BMEparam, valParam);
    otherwise
        error('Unknown validation method: %s', valParam.method);
end

