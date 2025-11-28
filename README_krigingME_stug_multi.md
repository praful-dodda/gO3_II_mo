# krigingME_stug_multi: Multi-Dataset Kriging with Measurement Errors

## Overview

`krigingME_stug_multi.m` is an enhanced version of `krigingME_stug.m` that supports **multiple soft datasets** while maintaining **full backward compatibility** with existing code.

**Version**: 3.0
**Date**: November 27, 2025
**Based on**: krigingME_stug.m v2.0c

## Key Features

### ✨ New in Version 3.0

1. **Multiple Soft Datasets Support**
   - Combine data from multiple CTM models simultaneously
   - Each dataset can have different spatial/temporal coverage
   - Automatic neighbor selection and aggregation across datasets

2. **Flexible Input Formats**
   - Cell arrays for multiple datasets
   - Structures for single datasets (backward compatible)
   - Legacy vectors for simple cases (backward compatible)

3. **Intelligent Neighbor Selection**
   - Gathers neighbors from all datasets
   - Respects total neighbor limit (`nsmax`) across all datasets
   - Prioritizes closest neighbors by space-time distance

4. **100% Backward Compatible**
   - Drop-in replacement for `krigingME_stug.m`
   - All existing code works without modification
   - Same function signature and behavior for single datasets

---

## Usage

### Syntax

```matlab
[zk, vk] = krigingME_stug_multi(ck, ch, cs, zh, zs, vs, covmodel, covparam, ...
                                 nhmax, nsmax, dmax, order, options, hard_data, soft_data)
```

### Input Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `ck` | matrix/cell | Estimation point coordinates (nk × d) |
| `ch` | matrix/cell | Hard data coordinates (nh × d) |
| `cs` | matrix/cell | Soft data coordinates (single: ns × d, multiple: cell array) |
| `zh` | vector | Hard data values (nh × 1) |
| `zs` | vector/cell | Soft data means (single: ns × 1, multiple: cell array) |
| `vs` | vector/cell | Soft data variances (single: ns × 1, multiple: cell array) |
| `covmodel` | string | Covariance model name |
| `covparam` | vector | Covariance model parameters |
| `nhmax` | scalar | Maximum hard data neighbors |
| `nsmax` | scalar | Maximum soft data neighbors (total across all datasets) |
| `dmax` | vector | Maximum distances [spatial, temporal, metric] |
| `order` | scalar | Mean trend order (NaN=zero, 0=constant) |
| `options` | vector | Options (options(1)=1 for verbose) |
| `hard_data` | struct | Optional hard data structure (future use) |
| `soft_data` | struct/cell | Single dataset (struct) or multiple datasets (cell array) |

### Output Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `zk` | vector | Estimated values at estimation locations (nk × 1) |
| `vk` | vector | Estimation variances at estimation locations (nk × 1) |

---

## Examples

### Example 1: Backward Compatible (Single Soft Dataset)

```matlab
% Load data
obs = getTOARobservationalData('all', [2015 2020]);
soft_data = createSoftDataStructure(ctmData, obs);

% Set parameters
covmodel = 'exponentialC/exponentialC';
covparam = [1000, 50, 0.1, 10];
nhmax = 100;
nsmax = 200;
dmax = [50, 2, 1];

% Estimate - works exactly like krigingME_stug
[zk, vk] = krigingME_stug_multi(ck, ch, [], zh, [], [], covmodel, covparam, ...
                                 nhmax, nsmax, dmax, 0, [1], [], soft_data);
```

### Example 2: Multiple Soft Datasets

```matlab
% Load multiple CTM models
ctm1 = loadRAMPdata('MERRA2-GMI', 'lambda1', [2015 2020]);
ctm2 = loadRAMPdata('CAMS', 'lambda1', [2015 2020]);
ctm3 = loadRAMPdata('AM4', 'lambda1', [2015 2020]);

% Create soft data structures
soft_data1 = createSoftDataStructure(ctm1, obs);
soft_data2 = createSoftDataStructure(ctm2, obs);
soft_data3 = createSoftDataStructure(ctm3, obs);

% Package as cell array
soft_data_multi = {soft_data1, soft_data2, soft_data3};

% Estimate with multiple datasets
[zk, vk] = krigingME_stug_multi(ck, ch, [], zh, [], [], covmodel, covparam, ...
                                 nhmax, nsmax, dmax, 0, [1], [], soft_data_multi);
```

### Example 3: Hard Data Only (No Soft Data)

```matlab
% Estimate using only hard data (standard kriging)
[zk, vk] = krigingME_stug_multi(ck, ch, [], zh, [], [], covmodel, covparam, ...
                                 nhmax, 0, dmax, 0, [1]);
```

---

## How It Works

### Single Soft Dataset Mode

When `soft_data` is a **struct** (or empty):
1. Behaves identically to `krigingME_stug.m`
2. Uses `neighbours_stug_optimized()` for neighbor selection
3. Extracts variances using the returned index

### Multiple Soft Dataset Mode

When `soft_data` is a **cell array**:

1. **Neighbor Gathering Phase**
   - For each dataset in the cell array:
     - Call `neighbours_stug_optimized(ck0, soft_data{i}, nsmax, dmax)`
     - Extract variances for selected neighbors
   - Concatenate all neighbors from all datasets

2. **Neighbor Trimming Phase**
   - If total neighbors exceed `nsmax`:
     - Compute space-time distances to estimation point
     - Sort by distance
     - Keep only the closest `nsmax` neighbors
   - This ensures the best neighbors are selected across all datasets

3. **Kriging Estimation**
   - Proceeds identically to single-dataset case
   - Builds covariance matrices with combined soft data
   - Solves kriging system for optimal weights

---

## Soft Data Structure Format

Each soft dataset (whether single or in a cell array) should be a struct with:

```matlab
soft_data.x        % x-coordinates (nx × 1)
soft_data.y        % y-coordinates (ny × 1)
soft_data.time     % time coordinates (nt × 1)
soft_data.Lon      % longitude at grid points (nx × ny) or (nx × ny × nt)
soft_data.Lat      % latitude at grid points (nx × ny) or (nx × ny × nt)
soft_data.Z        % mean values (nx × ny × nt)
soft_data.Zv       % variance values (nx × ny × nt)
```

This format is compatible with:
- `neighbours_stug_optimized()`
- `createSoftDataStructure()`
- TOAR-II BME framework

---

## Performance Considerations

### Computational Complexity

- **Single dataset**: Same as `krigingME_stug.m`
- **Multiple datasets**: Linear increase with number of datasets
  - Each dataset requires one `neighbours_stug_optimized()` call per estimation point
  - Additional sorting step if total neighbors exceed `nsmax`

### Memory Usage

- Memory scales with `nsmax`, not with total soft data size
- Each estimation point processes at most `nsmax` soft neighbors
- Neighbor search is optimized using grid structure

### Recommendations

1. **For 2-3 datasets**: Set `nsmax` to accommodate all datasets (e.g., 150-300)
2. **For 4+ datasets**: Consider selective datasets or regional subsets
3. **For global estimation**: Use `dmax` to limit search radius appropriately

---

## Differences from krigingME_stug.m

| Feature | krigingME_stug.m | krigingME_stug_multi.m |
|---------|------------------|------------------------|
| Single soft dataset | ✅ | ✅ |
| Multiple soft datasets | ❌ | ✅ |
| Cell array input | ❌ | ✅ |
| Backward compatible | N/A | ✅ |
| Variance extraction | Index-based | Index + structure-based |
| Neighbor trimming | Per dataset | Across all datasets |

---

## Integration with TOAR-II Framework

### Modified Workflow

```matlab
% 1. Load observational data
obs = getTOARobservationalData('all', [2015 2020]);

% 2. Estimate global offset
go = getTOARglobalOffset(obs, 3);

% 3. Fit covariance model
cov = getTOARautoCov(obs, go);

% 4. Load multiple CTM models
models = {'MERRA2-GMI', 'CAMS', 'AM4', 'UKML'};
soft_data_multi = cell(1, length(models));
for i = 1:length(models)
    ctm = loadRAMPdata(models{i}, 'lambda1', [2015 2020]);
    soft_data_multi{i} = createSoftDataStructure(ctm, obs);
end

% 5. Create knowledge bases (modified to use cell array)
[KG, KS, BMEparam] = getTOARknowledgeBase(obs, go, cov, soft_data_multi, '11000142', 'stug');

% 6. Estimate using multiple datasets
[zk, vk] = krigingME_stug_multi(..., soft_data_multi);
```

---

## Testing and Validation

### Unit Tests

1. **Backward compatibility**: Verify identical results with single dataset
2. **Multiple datasets**: Compare with sequential single-dataset estimates
3. **Neighbor limits**: Verify `nsmax` is respected across all datasets
4. **Distance-based selection**: Verify closest neighbors are selected

### Example Test Script

See `example_krigingME_stug_multi.m` for comprehensive usage examples and test cases.

---

## Limitations and Future Work

### Current Limitations

1. **Separate processing**: Soft datasets are treated independently (no fusion)
   - Each dataset contributes neighbors separately
   - No inter-dataset bias correction at neighbor selection stage

2. **Uniform neighbor limit**: `nsmax` is applied uniformly
   - Cannot prioritize specific datasets
   - All datasets compete equally for neighbor slots

### Future Enhancements

1. **Dataset-specific neighbor limits**
   ```matlab
   nsmax = [100, 50, 50];  % Per-dataset limits
   ```

2. **Dataset weighting**
   ```matlab
   soft_weights = [1.0, 0.8, 0.6];  % Weight by data quality
   ```

3. **Fused soft data**
   - Pre-combine datasets using ensemble methods
   - Single fused dataset with aggregated uncertainty

---

## References

- Original `krigingME.m`: BMELIB (Christakos & Serre)
- `krigingME_stug.m` v2.0c: Optimized for uniform grids
- TOAR-II: Tropospheric Ozone Assessment Report

---

## Author & Contact

**Developed by**: Claude (Anthropic)
**Date**: November 27, 2025
**For**: TOAR-II BME Data Fusion Framework

For questions or issues, please refer to the main repository documentation.
