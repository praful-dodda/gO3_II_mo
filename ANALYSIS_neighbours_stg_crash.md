# Analysis: neighbours_stg.m Crash with Restrictive dmax

## Executive Summary

The crash in `neighbours_stg.m` at line 169 is **NOT a looping error**. It's a **missing edge case validation** that occurs when the space-time distance constraint is too restrictive. The algorithm has correct logic but lacks defensive programming for three specific edge cases.

---

## The Algorithm Flow

### Step 1: Initialize All Candidates (Lines 115-119)
```matlab
indexMSsub = (1:nMS)';              % All monitoring stations
dMSsub = coord2dist(data.sMS, s0);  % Spatial distances to all stations

indexMEsub = (1:nME);               % All monitoring events (time points)
dMEsub = abs(data.tME - t0);        % Temporal distances to all events
```
**State after Step 1:**
- `nMSsub = nMS` (total stations)
- `nMEsub = nME` (total time events)
- Candidate neighbors = `nMS × nME` (can be very large)

---

### Step 2: Apply dmax Spatial/Temporal Filters (Lines 125-133)
```matlab
idx1 = dMSsub <= dmax(1);           % Keep only MS within spatial limit
indexMSsub = indexMSsub(idx1);
dMSsub = dMSsub(idx1);
nMSsub = length(indexMSsub);        % Number of stations within dmax(1)

idx2 = dMEsub <= dmax(2);           % Keep only ME within temporal limit
indexMEsub = indexMEsub(idx2);
dMEsub = dMEsub(idx2);
nMEsub = length(indexMEsub);        % Number of time events within dmax(2)
```

**🚨 EDGE CASE 1: No neighbors within dmax**
```
If dmax(1) is too small → nMSsub = 0 (no stations close enough)
If dmax(2) is too small → nMEsub = 0 (no time events close enough)
```

**State after Step 2:**
- `nMSsub` = stations within `dmax(1)` spatial distance
- `nMEsub` = time events within `dmax(2)` temporal distance
- ⚠️ **Either can be ZERO if dmax is too restrictive!**

---

### Step 3: Reduce Spatial Neighbors (Lines 144-153)
```matlab
% Sort by distance
[~, idx] = sort(dMSsub);
indexMSsub = indexMSsub(idx);
dMSsub = dMSsub(idx);

% Keep at most ceil(nmax/(1-data.nanratio)) closest stations
nMSsubReduced = nMSsub;
if ceil(nmax/(1-data.nanratio)) < nMSsubReduced
  nMSsubReduced = ceil(nmax/(1-data.nanratio));
end

indexMSsubReduced = indexMSsub(1:nMSsubReduced);
dMSsubReduced = dMSsub(1:nMSsubReduced);
```

**Purpose:** Reduce candidate spatial neighbors to account for missing data (NaNs)
- If `nmax = 100` and `nanratio = 0.5`, we need ~200 station-time pairs
- But we only keep the closest stations

**State after Step 3:**
- `nMSsubReduced` ≤ `nMSsub` (reduced or same)
- `dMSsubReduced(end)` = distance to furthest selected station
- ⚠️ **If `nMSsub = 0`, then `dMSsubReduced = []` (empty array!)**

---

### Step 4: Reduce Temporal Neighbors Using Space-Time Constraint (Lines 163-171)

**🚨 THE CRASH HAPPENS HERE! 🚨**

```matlab
% Sort time events by temporal distance
[~, idx] = sort(dMEsub);
indexMEsub = indexMEsub(idx);
dMEsub = dMEsub(idx);

% LINE 169 - THE CRASH LINE
nMEsubReduced = max(find(dmax(3)*dMEsub <= dMSsubReduced(end)));

% LINE 170 - Tries to use nMEsubReduced as index
indexMEsubReduced = indexMEsub(1:nMEsubReduced);
dMEsubReduced = dMEsub(1:nMEsubReduced);
```

**The Logic (when it works):**
- We've selected spatial neighbors up to distance `dMSsubReduced(end)`
- To balance space and time, limit temporal neighbors to equivalent distance
- Space-time distance = `spatial_dist + dmax(3) × temporal_dist`
- So only keep times where: `dmax(3) × temporal_dist ≤ spatial_dist_max`
- Find maximum index where this holds: `max(find(...))`

**Why this is clever:**
- Prevents selecting many distant times when spatial neighbors are close
- Balances space-time neighborhood symmetrically

---

## 🐛 The Three Crash Scenarios

### **Crash Scenario 1: No Spatial Neighbors**

**When it happens:**
```matlab
dmax = [10, 100, 1];  % Very restrictive spatial limit
% Estimation point is in ocean, nearest station is 50km away
% After Step 2: nMSsub = 0 (no stations within 10km)
```

**What breaks:**
```matlab
% Step 3 produces:
dMSsubReduced = [];  % Empty array

% Line 169 tries:
nMEsubReduced = max(find(dmax(3)*dMEsub <= dMSsubReduced(end)));
                                            ^^^^^^^^^^^^^^^^^^^
                                            ERROR: Index exceeds array bounds
```

**MATLAB Error:**
```
Index exceeds the number of array elements (0).
```

---

### **Crash Scenario 2: Space-Time Constraint Too Restrictive**

**When it happens:**
```matlab
dmax = [100, 365, 0.01];  % Very small space-time metric!
% Nearest station is 50km away
% dMSsubReduced(end) = 50 (km)
% dMEsub = [30, 60, 90, 120] (days)
% dmax(3) * dMEsub = [0.3, 0.6, 0.9, 1.2] (km-equivalent)
% ALL values > 50? NO!
% But if dmax(3) = 0.001:
% dmax(3) * dMEsub = [0.03, 0.06, 0.09, 0.12] (km-equivalent)
% Wait, these are all < 50, so this wouldn't crash...
```

Actually, let me reconsider:

```matlab
dmax = [50, 100, 10];  % Large space-time metric
% Nearest station is 5km away → dMSsubReduced(end) = 5
% dMEsub = [1, 2, 3, 4] (time units, e.g., months)
% dmax(3) * dMEsub = [10, 20, 30, 40] (spatial equivalent)
% Condition: 10 <= 5? NO
%           20 <= 5? NO
%           30 <= 5? NO
%           40 <= 5? NO
% find(...) returns [] (empty)
% max([]) returns [] (empty)
```

**What breaks:**
```matlab
% Line 169:
nMEsubReduced = max(find(dmax(3)*dMEsub <= dMSsubReduced(end)));
                = max([])
                = []  % Empty!

% Line 170 tries:
indexMEsubReduced = indexMEsub(1:[]);
                                  ^^
                                  ERROR: Array indices must be positive integers
```

**MATLAB Error:**
```
Array indices must be positive integers or logical values.
```

This is YOUR error!

---

### **Crash Scenario 3: No Temporal Neighbors**

**When it happens:**
```matlab
dmax = [100, 1, 1];  % Very restrictive temporal limit (1 month)
% Estimation time: 2018.5 (mid-year)
% Data only available at: [2018.0, 2019.0, 2020.0]
% Temporal distances: [0.5, 0.5, 1.5] years = [6, 6, 18] months
% After Step 2: nMEsub = 0 (no time events within 1 month)
```

**What breaks:**
```matlab
% Step 4 produces:
dMEsub = [];  % Empty array

% Line 169:
nMEsubReduced = max(find(dmax(3)*[] <= dMSsubReduced(end)));
                = max(find([]));
                = max([]);
                = [];

% Line 170:
indexMEsubReduced = indexMEsub(1:[]);  % ERROR!
```

---

## 📊 Summary Table: When Crashes Occur

| Scenario | Condition | After Step 2 | After Step 3 | Line 169 Result | Crash? |
|----------|-----------|--------------|--------------|-----------------|--------|
| **Normal** | Balanced dmax | `nMSsub > 0`<br>`nMEsub > 0` | `dMSsubReduced` has data | `nMEsubReduced > 0` | ✅ No |
| **Scenario 1** | `dmax(1)` too small | `nMSsub = 0` | `dMSsubReduced = []` | `dMSsubReduced(end)` fails | ❌ **YES** |
| **Scenario 2** | `dmax(3)` too large<br>OR `dMSsubReduced(end)` too small | `nMSsub > 0`<br>`nMEsub > 0` | `dMSsubReduced(end)` very small | `max(find(...)) = []` | ❌ **YES** |
| **Scenario 3** | `dmax(2)` too small | `nMEsub = 0` | `dMEsub = []` | `max(find([])) = []` | ❌ **YES** |

---

## 🔍 Why the Expansion Loop (Lines 211-267) Doesn't Help

After the crash at line 169-171, there's a clever expansion loop:

```matlab
if nsubReduced < nmax && (nMSsubReduced < nMSsub || nMEsubReduced < nMEsub)
  % Gradually expand MS and ME to find more neighbors
  while nsubReduced < nmax && (ii+1 <= ... || jj+1 <= ...)
    % Increment ii or jj to include more MS or ME
  end
end
```

**Purpose:** If we have fewer than `nmax` neighbors after reduction, try expanding the search.

**Why it doesn't prevent crashes:**
- This loop executes **AFTER** line 169-171
- The crash happens **AT** line 169, so we never reach the expansion loop!
- It's like having a safety net 10 feet below a cliff you fall off at 100 feet

---

## 🛠️ Root Cause

**The root cause is NOT incorrect looping.** The looping logic (expansion) is actually correct and clever!

**The root cause is:** **Missing validation before array indexing**

The algorithm assumes:
1. ✓ There will always be at least 1 spatial neighbor after filtering
2. ✓ The space-time constraint will match at least 1 temporal neighbor
3. ✗ **These assumptions are NOT validated before using them!**

Classic **defensive programming failure** - the algorithm is theoretically correct but breaks on edge cases.

---

## ✅ The Proper Solution

### Fix Location: Immediately After Line 169

```matlab
% Line 163-165: Sort temporal neighbors
[~, idx] = sort(dMEsub);
indexMEsub = indexMEsub(idx);
dMEsub = dMEsub(idx);

% Line 167-169: Apply space-time constraint
% ORIGINAL CODE:
nMEsubReduced = max(find(dmax(3)*dMEsub <= dMSsubReduced(end)));

% FIX: Add validation
if isempty(nMEsubReduced) || nMEsubReduced == 0
  % No temporal neighbors satisfy space-time constraint
  % Strategy: Include at least the closest temporal neighbor
  if nMEsub > 0
    nMEsubReduced = 1;  % Keep the closest time event
  else
    nMEsubReduced = 0;  % No temporal data at all
  end
end

% Line 170-171: Safe to index now
if nMEsubReduced > 0
  indexMEsubReduced = indexMEsub(1:nMEsubReduced);
  dMEsubReduced = dMEsub(1:nMEsubReduced);
else
  indexMEsubReduced = [];
  dMEsubReduced = [];
end
```

### Additional Safety: Handle Empty Spatial Neighbors

**Add before line 169:**
```matlab
% Check if we have any spatial neighbors
if isempty(dMSsubReduced) || nMSsubReduced == 0
  % No spatial neighbors - return empty
  psub = [];
  zsub = [];
  dsub = [];
  nsub = 0;
  index = [];
  return;
end
```

---

## 🧪 Test Cases

### Test Case 1: Very Restrictive Spatial dmax
```matlab
p0 = [0, 0, 2018.5];  % Ocean location
data.sMS = [50, 50; 60, 60];  % Stations far away
data.tME = [2018.0, 2018.5, 2019.0];
nmax = 10;
dmax = [10, 100, 1];  % Only 10 units spatial distance
% Expected: No crash, return empty or nearest regardless of distance
```

### Test Case 2: Very Large Space-Time Metric
```matlab
p0 = [0, 0, 2018.5];
data.sMS = [5, 5];  % Station 5 units away
data.tME = [2018.0, 2019.0, 2020.0];  % Times 0.5, 0.5, 1.5 years away
nmax = 10;
dmax = [100, 10, 100];  % Space-time metric = 100 (very large!)
% dmax(3) * dMEsub = [50, 50, 150] >> dMSsubReduced(end) = 5
% Expected: No crash, include at least 1 temporal neighbor
```

### Test Case 3: Very Restrictive Temporal dmax
```matlab
p0 = [0, 0, 2018.5];
data.sMS = [5, 5];
data.tME = [2016.0, 2020.0];  % Times 2.5 and 1.5 years away
nmax = 10;
dmax = [100, 0.1, 1];  % Only 0.1 time units (very restrictive!)
% Expected: No crash, return empty or relax constraint
```

---

## 📋 Recommended Fix Strategy

### Option A: Conservative (Fail Fast)
Return empty if constraints can't be satisfied:
```matlab
if isempty(nMEsubReduced) || nMEsubReduced == 0
  psub = [];
  zsub = [];
  dsub = [];
  nsub = 0;
  index = [];
  return;
end
```
**Pros:** Clear failure signal
**Cons:** Estimation point gets NaN (no estimate)

### Option B: Relaxed (Best Effort)
Always try to return at least 1 neighbor:
```matlab
if isempty(nMEsubReduced) || nMEsubReduced == 0
  if nMEsub > 0
    nMEsubReduced = 1;  % At least include closest time
  else
    % No temporal data at all - early return
    psub = [];
    zsub = [];
    dsub = [];
    nsub = 0;
    index = [];
    return;
  end
end
```
**Pros:** More likely to produce estimates
**Cons:** May violate user's dmax constraints

### Option C: Warning (Informative)
Same as Option B but warn the user:
```matlab
if isempty(nMEsubReduced) || nMEsubReduced == 0
  if nMEsub > 0
    warning('neighbours_stg: dmax constraints too restrictive, relaxing to include closest temporal neighbor');
    nMEsubReduced = 1;
  else
    warning('neighbours_stg: No temporal neighbors within dmax(2), returning empty');
    psub = [];
    zsub = [];
    dsub = [];
    nsub = 0;
    index = [];
    return;
  end
end
```
**Pros:** User is informed, best effort made
**Cons:** May produce many warnings in large loops

---

## 🎯 My Recommendation

Use **Option B (Relaxed)** for the main fix, with an optional warning parameter:

```matlab
function [psub,zsub,dsub,nsub,index]=neighbours_stg(p0,data,nmax,dmax,options)
% Add optional options parameter:
%   options.strict = 1: Fail if constraints violated (Option A)
%   options.strict = 0: Best effort (Option B, default)
%   options.warn = 1: Show warnings (Option C)

if nargin < 5
  options.strict = 0;  % Default: best effort
  options.warn = 0;    % Default: no warnings
end

% ... existing code ...

% After line 169:
if isempty(nMEsubReduced) || nMEsubReduced == 0
  if options.strict
    % Conservative: fail fast
    psub = [];
    zsub = [];
    dsub = [];
    nsub = 0;
    index = [];
    return;
  else
    % Relaxed: best effort
    if nMEsub > 0
      if options.warn
        warning('neighbours_stg: Space-time constraint too restrictive, including closest temporal neighbor');
      end
      nMEsubReduced = 1;
    else
      % No temporal data at all
      psub = [];
      zsub = [];
      dsub = [];
      nsub = 0;
      index = [];
      return;
    end
  end
end
```

This provides flexibility while preventing crashes!
