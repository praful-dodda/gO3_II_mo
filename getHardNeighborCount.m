function nneighbors = getHardNeighborCount(nhmax_code)
% getHardNeighborCount - Convert nhmax code to actual neighbor count
%
% Converts the encoded nhmax digit (1-3) to the actual number of
% hard data neighbors used in BME estimation.
%
% SYNTAX:
%   nneighbors = getHardNeighborCount(nhmax_code)
%
% INPUT:
%   nhmax_code - Encoded neighbor count (1-3)
%
% OUTPUT:
%   nneighbors - Actual number of neighbors
%
% ENCODING:
%   Code   Neighbors
%   1      50
%   2      100
%   3      150
%   4      200

%
% EXAMPLES:
%   n = getHardNeighborCount(1)  % → 50
%   n = getHardNeighborCount(2)  % → 100
%   n = getHardNeighborCount(3)  % → 150
%   n = getHardNeighborCount(4)  % → 200

% Lookup table
neighbor_map = [50, 100, 150, 200];

% Validate input
if nhmax_code < 1 || nhmax_code > 4
    error('nhmax_code must be in range [1-4], got %d', nhmax_code);
end

% Return mapped value
nneighbors = neighbor_map(nhmax_code);

end
