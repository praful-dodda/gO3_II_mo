function [KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, softData, BMEmethod8digits, dataFormat)
% getTOARknowledgeBase - Prepare knowledge bases for BME estimation of TOAR ozone
%
% Creates General Knowledge (KG), Site-specific Knowledge (KS), and BME
% parameters for Bayesian Maximum Entropy estimation
%
% SYNTAX:
%   [KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, softData, BMEmethod8digits, dataFormat)
%
% INPUTS:
%   obs      - Structure from getTOARobservationalData
%   go       - Structure from getTOARglobalOffset
%   cov      - Structure from getTOARautoCov
%   softData - Structure with soft data (optional, for future use)
%              .ctm      - CTM model output structure with fields:
%                         .sMS, .tME, .Z (mean), .Zv (variance)
%              .satellite - Satellite data structure
%   BMEmethod8digits - 8-digit BME method code (default: '10000132')
%                      Digit 1: obsType (1=hard, 2=hard/soft)
%                      Digit 2: CTMtype (0=none, 1=CTM1, 2=CTM2)
%                      Digit 3: RAMPnonLinearity (0-2)
%                      Digit 4: RAMPnonHomoscedasticity (0-2)
%                      Digit 5: RAMPnonStationary (0-4)
%                      Digit 6: BMEnsmax (0-6)
%                      Digit 7: BMEnhmax (1-3)
%                      Digit 8: BMEprobaType (1=BMEprobaMoments, 2=KrigingME)
%   dataFormat - Data format: 'stv', 'stg', or 'stug' (optional, default 'stg')
%
% OUTPUTS:
%   KG       - General Knowledge structure:
%              .order      - Order of mean trend (NaN=zero, 0=constant)
%              .covmodel   - Covariance model names
%              .covparam   - Covariance parameters
%              .sill       - Variance of covariance
%   KS       - Site-specific Knowledge structure:
%              .harddata   - Structure with hard data:
%                .sMS, .tME, .Xh (STG format)
%                .Oh (global offset at hard locations)
%                .p, .z (STV format for BME)
%                .Zisnotnan, .nanratio, .index_stg_to_stv
%              .softdata   - Structure with soft data (if available)
%              .softpdftype, .nl, .limi, .probdens (for BME)
%   BMEparam - BME estimation parameters from getBMEparam
%
% EXAMPLE:
%   obs = getTOARobservationalData('all', [2015 2020]);
%   go = getTOARglobalOffset(obs, 3);
%   cov = getTOARautoCov(obs, go);
%   [KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, [], '10000132', 'stg');

if nargin < 4, softData = []; end
if nargin < 5, BMEmethod8digits = '10000132'; end
if nargin < 6, dataFormat = 'stg'; end


% Input validation

% Ensure BMEmethod8digits is a string
if isnumeric(BMEmethod8digits)
    BMEmethod8digits = num2str(BMEmethod8digits);
end

fprintf('--- Preparing BME Knowledge Bases ---\n');
% Parse BME method code
% [obsType, CTMtype, RAMPnonLinearity, RAMPnonHomoscedasticity, ...
%  RAMPnonStationary, BMEnsmax, BMEnhmax, BMEprobaType] = parseTOARBMEmethod(BMEmethod8digits);

[obsType, CTMtype, ~, ~, ~, BMEprobaType] = parseBMEcode(BMEmethod8digits);

fprintf('  BME Method: %s\n', BMEmethod8digits);
fprintf('    Observation type: %d (1=hard, 2=hard/soft)\n', obsType);
fprintf('    CTM type: %d (0=none)\n', CTMtype);
fprintf('    BME proba type: %d (1=moments, 2=kriging)\n', BMEprobaType);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% General Knowledge (KG) - Covariance Structure
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('  Setting up General Knowledge (covariance)...\n');

% Local mean trend type
switch BMEprobaType
    case 1  % BMEprobaMoments
        KG.order = NaN;  % Zero mean (residuals should have zero mean)
    case 2  % KrigingME
        KG.order = 0;    % Constant mean
    case 3
        KG.order = 0;
    otherwise
        error('BMEprobaType must be 1 (BMEprobaMoments) or 2 (KrigingME) or 3 (for multiple soft-datasets');
end

% Covariance model from fitted covariance
KG.covmodel = cov.covmodel;
KG.covparam = cov.covparam;
KG.sill = cov.var;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Site-Specific Knowledge (KS) - Hard Data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('  Setting up Site-Specific Knowledge...\n');

% Remove global offset from observations to get residuals (STG format)
Oh = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, obs.sMS, obs.tME);
Xh = obs.Y - Oh;

% Create hard data structure (STG format)
if obsType >= 1
    KS.harddata.sMS = obs.sMS;
    KS.harddata.tME = obs.tME;
    KS.harddata.Xh = Xh;
    KS.harddata.Oh = Oh;
    
    % Track NaN locations
    KS.harddata.Zisnotnan = ~isnan(Xh);
    KS.harddata.nanratio = sum(~KS.harddata.Zisnotnan(:)) / numel(Xh);
    KS.harddata.index_stg_to_stv = cumsum(KS.harddata.Zisnotnan(:));
    
    % Convert to STV format for BME functions
    [p_stg, z_stg] = valstg2stv(Xh, obs.sMS, obs.tME);
    KS.harddata.p = p_stg(~isnan(z_stg), :);
    KS.harddata.z = z_stg(~isnan(z_stg));
    
    fprintf('    Hard data: %d valid points (%.1f%% complete)\n', ...
        length(KS.harddata.z), 100*(1-KS.harddata.nanratio));
else
    % Empty hard data structure
    KS.harddata = struct('sMS', [], 'tME', [], 'Xh', [], 'Oh', [], ...
        'p', [], 'z', [], 'Zisnotnan', [], 'nanratio', [], 'index_stg_to_stv', []);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Site-Specific Knowledge (KS) - Soft Data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialize soft data structure
KS.softdata = struct('sMS', [], 'tME', [], 'Xms', [], 'Xvs', [], ...
    'p', [], 'z', [], 'vs', [], 'Zisnotnan', [], 'nanratio', [], 'index_stg_to_stv', []);

if CTMtype >= 1 && ~isempty(softData)
    fprintf('    Processing soft data from CTM...\n');
    
    % Get soft data based on CTM type
    switch CTMtype
        case 1
            if isfield(softData, 'ctm')
                ctmData = softData;
            else
                error('CTMtype=1 but softData.ctm not provided');
            end
        case 2
            if isfield(softData, 'ctm')
                ctmData = softData;
            else
                error('CTMtype=2 but softData.ctm not provided');
            end
        case 3
            % Get multiple soft datasets
            if ~iscell(softData)
                ctmData = softData;
            elseif iscell(softData)
                ctmData = softData;
            end

            % if isfield(softData, 'ctm')
            %     ctmData = softData;
            % else
            %     error('CTMtype=2 but softData.ctm2 not provided');
            % end
    end

    % Process single or multiple soft datasets
    if CTMtype == 1 || CTMtype == 2
        % Single soft dataset
        % Remove global offset from soft data
        Os = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, ctmData.sMS, ctmData.tME);
        
        % TODO: Apply RAMP correction here based on RAMPnonLinearity, 
        % RAMPnonHomoscedasticity, RAMPnonStationary
        % For now, use uncorrected CTM data
        Xms = ctmData.Z - Os;
        Xvs = ctmData.Zv;  % Variance
        
        % Store in STG format
        KS.softdata.sMS = ctmData.sMS;
        KS.softdata.tME = ctmData.tME;
        KS.softdata.Xms = Xms;
        KS.softdata.Xvs = Xvs;
        
        % Track NaN locations
        KS.softdata.Zisnotnan = ~isnan(Xms);
        KS.softdata.nanratio = sum(~KS.softdata.Zisnotnan(:)) / numel(Xms);
        KS.softdata.index_stg_to_stv = cumsum(KS.softdata.Zisnotnan(:));
        
        % Convert to STV format
        [p_stg, z_stg] = valstg2stv(Xms, ctmData.sMS, ctmData.tME);
        [~, vs_stg] = valstg2stv(Xvs, ctmData.sMS, ctmData.tME);
        
        valid_idx = ~isnan(z_stg);
        KS.softdata.p = p_stg(valid_idx, :);
        KS.softdata.z = z_stg(valid_idx);
        KS.softdata.vs = vs_stg(valid_idx);
        
        fprintf('    Soft data: %d valid points (%.1f%% complete)\n', ...
            length(KS.softdata.z), 100*(1-KS.softdata.nanratio));
    elseif CTMtype == 3
        % Multiple soft datasets
        KS.softdata = cell(length(ctmData), 1);
        for m = 1:length(ctmData)
            fprintf('      Processing soft data model %d...\n', m);
            ctmModel = ctmData{m};
            
            % Remove global offset from soft data
            Os = stmeaninterp(go.sMS, go.tME, go.ms, go.mt, ctmModel.sMS, ctmModel.tME);
            Xms = ctmModel.Z - Os;
            Xvs = ctmModel.Zv;  % Variance
            
            % Store in STG format
            KS.softdata{m}.sMS = ctmModel.sMS;
            KS.softdata{m}.tME = ctmModel.tME;
            KS.softdata{m}.Xms = Xms;
            KS.softdata{m}.Xvs = Xvs;
            
            % Track NaN locations
            KS.softdata{m}.Zisnotnan = ~isnan(Xms);
            KS.softdata{m}.nanratio = sum(~KS.softdata{m}.Zisnotnan(:)) / numel(Xms);
            KS.softdata{m}.index_stg_to_stv = cumsum(KS.softdata{m}.Zisnotnan(:));
            
            % Convert to STV format
            [p_stg, z_stg] = valstg2stv(Xms, ctmModel.sMS, ctmModel.tME);
            [~, vs_stg] = valstg2stv(Xvs, ctmModel.sMS, ctmModel.tME);

            valid_idx = ~isnan(z_stg);
            KS.softdata{m}.p = p_stg(valid_idx, :);
            KS.softdata{m}.z = z_stg(valid_idx);
            KS.softdata{m}.vs = vs_stg(valid_idx);
            fprintf('        Soft data model %d: %d valid points (%.1f%% complete)\n', ...
                m, length(KS.softdata{m}.z), 100*(1-KS.softdata{m}.nanratio));
        end
    end
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Soft Data Probability Representation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Convert soft data to probability format for BME
if ~iscell(KS.softdata) && ~isempty(KS.softdata.z)
    switch BMEprobaType
        case 1  % BMEprobaMoments - Gaussian PDF
            [softpdftype, nl, limi, probdens] = probaGaussian(KS.softdata.z, KS.softdata.vs);
            KS.softpdftype = softpdftype;
            KS.nl = nl;
            KS.limi = limi;
            KS.probdens = probdens;
        case 2  % KrigingME - use mean/variance directly
            KS.softpdftype = 2;
            KS.nl = [];
            KS.limi = [];
            KS.probdens = [];
    end
elseif iscell(KS.softdata) && ~isempty(KS.softdata)
    % Multiple soft datasets
    KS.softpdftype = cell(length(KS.softdata), 1);
    KS.nl = cell(length(KS.softdata), 1);
    KS.limi = cell(length(KS.softdata), 1);
    KS.probdens = cell(length(KS.softdata), 1);
    
    for m = 1:length(KS.softdata)
        if ~isempty(KS.softdata{m}.z)
            switch BMEprobaType
                case 1  % BMEprobaMoments - Gaussian PDF
                    [softpdftype, nl, limi, probdens] = probaGaussian(KS.softdata{m}.z, KS.softdata{m}.vs);
                    KS.softpdftype{m} = softpdftype;
                    KS.nl{m} = nl;
                    KS.limi{m} = limi;
                    KS.probdens{m} = probdens;
                case 2  % KrigingME - use mean/variance directly
                    KS.softpdftype{m} = 2;
                    KS.nl{m} = [];
                    KS.limi{m} = [];
                    KS.probdens{m} = [];
            end
        end
    end 

else
    % No soft data
    KS.softpdftype = 1;
    KS.nl = [];
    KS.limi = [];
    KS.probdens = [];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% BME Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('  Setting up BME parameters...\n');

% Get BME parameters using separate function
BMEparam = getBMEparam(BMEmethod8digits, cov.stmetric, dataFormat);

fprintf('  Search parameters: spatial=%.1f deg, temporal=%.1f yr, metric=%.2f\n', ...
    BMEparam.dmax(1), BMEparam.dmax(2), BMEparam.dmax(3));
fprintf('  nhmax=%d, nsmax=%d\n', BMEparam.nhmax, BMEparam.nsmax);

fprintf('--- Knowledge bases prepared ---\n\n');

end