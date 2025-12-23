function nneighbors = getCTMneighborCount(nsmax_code)
% getCTMneighborCount - Convert nsmax code to actual neighbor count
%
% Converts the encoded nsmax digit (0-6) to the actual number of
% soft data neighbors used in BME estimation.
%
% SYNTAX:
%   nneighbors = getCTMneighborCount(nsmax_code)
%
% INPUT:
%   nsmax_code - Encoded neighbor count (0-6)
%
% OUTPUT:
%   nneighbors - Actual number of neighbors
%
% ENCODING:
%   Code   Neighbors
%   0      0
%   1      3
%   2      4
%   3      10
%   4      50
%   5      100
%   6      200
%
% EXAMPLES:
%   n = getCTMneighborCount(0)  % → 0
%   n = getCTMneighborCount(4)  % → 50
%   n = getCTMneighborCount(6)  % → 200

% Lookup table
neighbor_map = [0, 3, 4, 10, 50, 100, 200];

% Validate input
if nsmax_code < 0 || nsmax_code > 6
    error('nsmax_code must be in range [0-6], got %d', nsmax_code);
end

% Return mapped value
nneighbors = neighbor_map(nsmax_code + 1);  % +1 for 1-based indexing

end
