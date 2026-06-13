function out = filterLeakFiles(fileList, leakTag)
% filterLeakFiles - Keep only files matching the desired leakage-control state
%
% Glob patterns ending in '*.mat' cannot distinguish legacy CBV/OSDMA8 files
% from leakage-controlled ones (..._lc<R>.mat), because both end in a digit
% before '.mat'. This applies an EXACT post-dir() filter so the wrong variant
% is never read:
%   leakTag = ''       -> exclude every leakage-controlled file (drop *_lc<R>.mat)
%   leakTag = '_lc2'   -> keep only files ending exactly with that tag (*_lc2.mat)
%
% INPUTS:
%   fileList - struct array returned by dir() (uses the .name field), OR a
%              cellstr / string array of file names.
%   leakTag  - '' or '_lc<R>' (from getLeakTag).
%
% OUTPUT:
%   out      - same type as fileList, filtered.
%
% SEE ALSO: getLeakTag, plotCBVresults_Phase4, plotOSDMA8results_Phase4

if nargin < 2, leakTag = ''; end

% Extract names
if isstruct(fileList)
    names = {fileList.name};
elseif isstring(fileList)
    names = cellstr(fileList);
elseif ischar(fileList)
    names = {fileList};
else
    names = fileList;  % assume cellstr
end

if isempty(names)
    out = fileList;
    return;
end

if isempty(leakTag)
    % Legacy only: drop anything carrying a leakage-control tag.
    isLeak = ~cellfun('isempty', regexpi(names, '_lc[0-9.]+\.mat$', 'once'));
    keep = ~isLeak;
else
    % Exact tag: keep only names ending with <leakTag>.mat
    pat = [regexptranslate('escape', leakTag) '\.mat$'];
    keep = ~cellfun('isempty', regexpi(names, pat, 'once'));
end

if isstruct(fileList)
    out = fileList(keep);
elseif isstring(fileList)
    out = fileList(keep);
elseif ischar(fileList)
    if all(keep), out = fileList; else, out = ''; end
else
    out = fileList(keep);
end
end
