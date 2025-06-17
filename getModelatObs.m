function modelobsPairs = getModelatObs(model, obs)
% GETMODELATOBS          - Extracts matching model values at observation locations.
%
% Retrieves model values corresponding to observation locations where the 
% observation data is valid (i.e. obs.Z is not NaN) by linearly interpolating
% the model values onto the observation locations. It returns a structure with:
%
%   .sMS         n by 2    locations of the observation points.
%   .modelval    n by tME  model values interpolated onto observation locations.
%   .obsval      n by tME  original observation values.
%   .nonNaNPairs n by tME  mask with 1 where both modelval and obsval are not NaN.
%
% SYNTAX:
%
% modelobsPairs = getModelatObs(model, obs)
%
% INPUT:
%
% model        structure with fields:
%               .sMS    m by 2      model coordinates [lon lat]
%               .Z      m by tME    model values
%               .tME    1 by tME    model times
%
% obs          structure with fields:
%               .sMS    n by 2      observation coordinates [lon lat]
%               .Z      n by tME    observation values (NaN indicates missing data)
%               .tME    1 by tME    observation times
%
% OUTPUT:
%
% modelobsPairs  structure with fields:
%               .sMS         n by 2    locations of paired model-observation values.
%               .modelval    n by tME  model values interpolated onto obs locations.
%               .obsval      n by tME  observation values.
%               .nonNaNPairs n by tME  mask: 1 where both modelval and obsval are not NaN.
%
% NOTE:
%
% Performs linear interpolation of model values onto observation locations.
%
    tME = size(obs.tME, 2);
    nObs = size(obs.sMS, 1);
    
    % Initialize interpolated model values matrix
    modelInterp = zeros(nObs, tME);
    
    for t = 1:tME
        % Create interpolant for current time step; return NaN for points outside
        % the convex hull of model.sMS.
        F = scatteredInterpolant(model.sMS(:,1), model.sMS(:,2), model.Z(:,t), 'linear', 'none');
        modelInterp(:,t) = F(obs.sMS(:,1), obs.sMS(:,2));
    end
    
    % Create mask: 1 where both interpolated model values and obs values are not NaN.
    nonNaNPairs = ~isnan(modelInterp) & ~isnan(obs.Z);
    
    % Build output structure.
    modelobsPairs = struct('sMS', obs.sMS, 'modelval', modelInterp, 'obsval', obs.Z, 'nonNaNPairs', nonNaNPairs);
end