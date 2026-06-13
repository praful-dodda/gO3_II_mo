function tag = getLeakTag(cfgOrParam)
% getLeakTag - Filename/dir tag encoding CBV soft-data leakage control
%
% Returns '' when leakage control is OFF (so all filenames are byte-identical to
% the legacy pipeline), else '_lc<R>' where <R> is the representative (maximum)
% leak radius in degrees. Threaded through CBV + OSDMA8 filenames and figure
% output folders so leakage-controlled results never collide with the originals.
% NOTE: intentionally NOT used in figure TITLES.
%
% INPUT:
%   cfgOrParam - struct with optional fields:
%       .leakControl - logical/0-1 (default 0 = off)
%       .leakRadius  - scalar deg, OR struct mapping sanitized modelName -> deg
%                      (0/absent = that source not masked)
%
% EXAMPLES:
%   getLeakTag(struct('leakControl',0))                         -> ''
%   getLeakTag(struct('leakControl',1,'leakRadius',2.0))        -> '_lc2'
%   getLeakTag(struct('leakControl',1,'leakRadius', ...
%                     struct('M3fusion',2.0,'OMIMLS',0)))       -> '_lc2'
%
% SEE ALSO: maskSoftDataLeakage, runCBV_toar, runOSDMA8validation

tag = '';

if ~isstruct(cfgOrParam), return; end
if ~isfield(cfgOrParam, 'leakControl') || isempty(cfgOrParam.leakControl) ...
        || ~cfgOrParam.leakControl
    return;
end

if isfield(cfgOrParam, 'leakRadius') && ~isempty(cfgOrParam.leakRadius)
    lr = cfgOrParam.leakRadius;
else
    lr = 2.0;  % default radius if control is on but radius unspecified
end

if isnumeric(lr)
    rep = max(lr(:));
elseif isstruct(lr)
    vals = struct2cell(lr);
    vals = vals(cellfun(@(x) isnumeric(x) && isscalar(x), vals));
    if isempty(vals)
        rep = 0;
    else
        rep = max(cell2mat(vals));
    end
else
    rep = 0;
end

tag = sprintf('_lc%g', rep);
end
