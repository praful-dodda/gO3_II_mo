function [obsType, CTMtype, RAMPnonLinearity, RAMPnonHomoscedasticity, ...
          RAMPnonStationary, BMEnsmax, BMEnhmax, BMEprobaType] = parseTOARBMEmethod(BMEmethod8digits)
% parseTOARBMEmethod - Parse 8-digit BME method code
%
% Extracts individual method switches from the 8-digit code
%
% INPUT:
%   BMEmethod8digits - 8-digit integer code
%
% OUTPUT:
%   obsType              - Digit 1: Observation type (1=hard, 2=hard/soft)
%   CTMtype              - Digit 2: CTM type (0=none, 1=CTM1, 2=CTM2)
%   RAMPnonLinearity     - Digit 3: RAMP linearity (0=linear, 1=piece-linear, 2=monotonic)
%   RAMPnonHomoscedasticity - Digit 4: RAMP variance (0=constant, 1=non-constant, 2=monotonic)
%   RAMPnonStationary    - Digit 5: RAMP stationarity (0-4)
%   BMEnsmax             - Digit 6: Soft data max neighbors (0-6)
%   BMEnhmax             - Digit 7: Hard data max neighbors (1-3)
%   BMEprobaType         - Digit 8: Probability type (1=moments, 2=kriging)

% Validate input
% if the input is numeric, convert to string
if isnumeric(BMEmethod8digits)
    BMEmethodStr = num2str(BMEmethod8digits);
elseif ischar(BMEmethod8digits)
    BMEmethodStr = BMEmethod8digits;
else
    error('BMEmethod8digits must be a numeric or string input');
end

if length(BMEmethodStr) ~= 8
    error('BMEmethod8digits must be an 8-digit number');
end

% Convert to string and extract digits
% BMEmethodStr = num2str(BMEmethod8digits);

obsType = str2double(BMEmethodStr(1));
CTMtype = str2double(BMEmethodStr(2));
RAMPnonLinearity = str2double(BMEmethodStr(3));
RAMPnonHomoscedasticity = str2double(BMEmethodStr(4));
RAMPnonStationary = str2double(BMEmethodStr(5));
BMEnsmax = str2double(BMEmethodStr(6));
BMEnhmax = str2double(BMEmethodStr(7));
BMEprobaType = str2double(BMEmethodStr(8));

% Validate ranges
if ~ismember(obsType, [1, 2])
    warning('obsType (digit 1) must be 1 or 2');
end
if ~ismember(CTMtype, [0, 1, 2])
    warning('CTMtype (digit 2) must be 0, 1, or 2');
end
if ~ismember(BMEnsmax, 0:6)
    warning('BMEnsmax (digit 6) must be 0-6');
end
if ~ismember(BMEnhmax, 1:3)
    warning('BMEnhmax (digit 7) must be 1-3');
end
if ~ismember(BMEprobaType, [1, 2])
    warning('BMEprobaType (digit 8) must be 1 or 2');
end

end
