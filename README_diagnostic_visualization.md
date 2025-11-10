# BME Diagnostic Visualization Tool

Tools for diagnosing artifacts (like vertical lines) in BME standard deviation maps.

## Quick Start

```matlab
% Simple usage - examine std dev with grid only
visualizeBMEdiagnostic('5BMEspatialPlots/BME10000132_go3_lt0_area5_res1.00_stg_time2016.50.mat');

% Or use the example script
run('example_diagnose_vertical_lines.m');
```

## Files

- **`visualizeBMEdiagnostic.m`** - Main diagnostic visualization function
- **`example_diagnose_vertical_lines.m`** - Example script showing how to use the tool
- **`README_diagnostic_visualization.md`** - This file

## Function: visualizeBMEdiagnostic()

### Syntax
```matlab
visualizeBMEdiagnostic(BMEresultFile, options)
```

### Options

| Field | Values | Default | Description |
|-------|--------|---------|-------------|
| `metric` | `'mean'`, `'variance'`, `'std'` | `'std'` | Which metric to visualize |
| `display` | `'obs'`, `'grid'`, `'both'` | `'both'` | What to show |
| `colormap` | `'jet'`, `'parula'`, `'hot'`, etc. | `'jet'` | Color scheme |
| `clim` | `[min max]` or `'auto'` | `'auto'` | Color limits |
| `markerSize` | Numeric | `30` | Point size |
| `saveFig` | `true`, `false` | `true` | Save to file |
| `modelName` | String (e.g., `'MERRA2-GMI'`) | `''` | Model grid to overlay |
| `showModelGrid` | `true`, `false` | `true` | Show model grid if modelName provided |

### Display Modes

#### 1. Grid Only (`display = 'grid'`)
**Best for:** Seeing interpolation artifacts, vertical lines, grid structure issues

Shows only the BME estimation grid points. This makes it easy to spot:
- Vertical or horizontal lines
- Grid-related artifacts
- Interpolation issues
- Structured patterns

```matlab
opts.metric = 'std';
opts.display = 'grid';
visualizeBMEdiagnostic(yourFile, opts);
```

#### 2. Observations Only (`display = 'obs'`)
**Best for:** Checking data quality, understanding observation coverage

Shows only the observation locations (not available for variance/std). Useful for:
- Checking observation spatial distribution
- Identifying data gaps
- Verifying observation values

```matlab
opts.metric = 'mean';
opts.display = 'obs';
visualizeBMEdiagnostic(yourFile, opts);
```

#### 3. Both (`display = 'both'`)
**Best for:** Comparing grid estimates with observations

Shows grid + observations overlaid. Helps understand:
- How grid interpolates between observations
- Whether artifacts occur near/far from observations
- Observation influence on grid

```matlab
opts.metric = 'std';
opts.display = 'both';
visualizeBMEdiagnostic(yourFile, opts);
```

## Metrics

### Mean
- Shows BME estimated mean values (`YkBMEm`)
- Available for: grid and observations
- Use to check if estimation has artifacts

### Variance
- Shows BME estimation variance (`XkBMEv`)
- Available for: grid only
- Raw variance before square root
- Most sensitive to numerical issues

### Std (Standard Deviation)
- Shows `sqrt(variance)`
- Available for: grid only
- Default metric for diagnostic
- Where vertical lines typically appear

## Model Spatial Grid Overlay

**NEW FEATURE**: Overlay the input model's spatial grid to see if artifacts align with grid structure.

### Why This Matters
Vertical lines in STD maps often align with the model grid structure used for soft data. Overlaying the model grid helps identify if:
- Artifacts are grid-aligned (grid structure issue)
- Artifacts are independent of grid (covariance or search radius issue)
- Grid resolution matches/mismatches estimation grid

### How to Use

```matlab
opts.metric = 'std';
opts.display = 'grid';
opts.modelName = 'MERRA2-GMI';  % Specify which model
visualizeBMEdiagnostic(yourFile, opts);
```

### Available Models
Model spatial grids must exist in:
```
1data/CTM/model_output_data/spatial_grids/{modelName}_spatial_grid.mat
```

Generate with: `extractModelSpatialInfo.m`

Common model names:
- `MERRA2-GMI`
- `M3fusion`
- `UKML`
- `NJML`
- (See `checkAllGridUniformity.m` for full list)

### Visual Appearance
- Model grid points: Small gray crosses (`+`)
- BME estimation grid: Colored by metric value
- Model grid is subtle to not dominate visualization
- Title updated to show model name

### What to Look For
1. **Lines align with model grid** → Grid structure artifact
   - Try different dataFormat (stg ↔ stug ↔ stv)
   - Check grid generation

2. **Lines don't align with model grid** → Not grid structure
   - Check covariance parameters
   - Review search radius (dmax)
   - Investigate data boundaries

## Diagnosing Vertical Lines

### Common Causes

1. **Grid Structure Issues**
   - Structured grid interpolation creating boundaries
   - Try switching `stg` ↔ `stug` formats
   - Check grid generation in `getTOARmapGrid.m`

2. **Data Boundaries**
   - Sharp transitions at soft data edges
   - Missing data creating artificial boundaries
   - Check search radius (dmax)

3. **Covariance Issues**
   - Directional anisotropy in covariance
   - Numerical precision problems
   - Review covariance model parameters

4. **Coordinate Artifacts**
   - Transformation between coordinate systems
   - Grid alignment with data structure

### Diagnostic Workflow

```matlab
% 1. Load result file
file = '5BMEspatialPlots/BME10000132_go3_lt0_area5_res1.00_stg_time2016.50.mat';

% 2. Check STD with grid only (primary diagnostic)
opts.metric = 'std';
opts.display = 'grid';
figure(1); visualizeBMEdiagnostic(file, opts);

% 3. Check if mean also has lines
opts.metric = 'mean';
figure(2); visualizeBMEdiagnostic(file, opts);

% 4. Compare with observations overlay
opts.metric = 'std';
opts.display = 'both';
figure(3); visualizeBMEdiagnostic(file, opts);

% 5. Check raw variance (most sensitive)
opts.metric = 'variance';
opts.display = 'grid';
figure(4); visualizeBMEdiagnostic(file, opts);
```

### Interpretation

| Observation | Likely Cause | Solution |
|-------------|--------------|----------|
| Vertical lines in STD only | Variance calculation issue | Check covariance params, numerical precision |
| Lines in both MEAN and STD | Estimation/interpolation issue | Check dataFormat, grid generation |
| Lines align with grid edges | Grid structure artifact | Try different dataFormat (stg/stug) |
| Lines at data boundaries | Search radius too small | Increase dmax, check neighbor selection |
| Random scattered artifacts | Numerical precision | Check for very small/large values |

## Interactive Features

### Data Cursor
Click any point to see:
- Longitude, Latitude
- Exact value
- Point index

Useful for:
- Inspecting artifact values
- Checking realistic ranges
- Identifying problem points

### Zoom
Use zoom tool to:
- Examine artifacts in detail
- Check artifact spacing/pattern
- Verify orientation

## Output Files

Diagnostic figures are saved to:
```
5BMEspatialPlots/diagnostic/{filename}_DIAGNOSTIC_{metric}_{display}.png
```

Example:
```
5BMEspatialPlots/diagnostic/BME10000132_go3_lt0_area5_res1.00_stg_time2016.50_DIAGNOSTIC_std_grid.png
```

## Tips

1. **Start Simple**: Use defaults first, then customize
2. **Compare Metrics**: Check if artifact is metric-specific
3. **Use Grid Only**: Best view for seeing artifacts clearly
4. **Check Multiple Times**: See if artifact is consistent across time periods
5. **Zoom In**: Artifacts may be subtle at full scale
6. **Try Different Colormaps**: Some colormaps reveal patterns better
7. **Use Data Cursor**: Click on artifact points to inspect values

## Examples

### Example 1: Quick Check
```matlab
% Default settings - STD with both grid and obs
visualizeBMEdiagnostic('5BMEspatialPlots/BME10000132_go3_lt0_area5_res1.00_stg_time2016.50.mat');
```

### Example 2: Grid-Only STD (Best for Artifacts)
```matlab
opts.metric = 'std';
opts.display = 'grid';
opts.markerSize = 20;
visualizeBMEdiagnostic('5BMEspatialPlots/BME10000132_go3_lt0_area5_res1.00_stg_time2016.50.mat', opts);
```

### Example 3: Custom Color Scale
```matlab
opts.metric = 'std';
opts.display = 'grid';
opts.colormap = 'parula';
opts.clim = [0 5];  % Fix color range 0-5
visualizeBMEdiagnostic('5BMEspatialPlots/BME10000132_go3_lt0_area5_res1.00_stg_time2016.50.mat', opts);
```

### Example 4: Compare Mean vs STD
```matlab
file = '5BMEspatialPlots/BME10000132_go3_lt0_area5_res1.00_stg_time2016.50.mat';

% Mean
opts.metric = 'mean';
opts.display = 'grid';
figure(1); visualizeBMEdiagnostic(file, opts);

% STD
opts.metric = 'std';
figure(2); visualizeBMEdiagnostic(file, opts);
```

### Example 5: Overlay Model Grid (CRITICAL for Vertical Lines)
```matlab
file = '5BMEspatialPlots/BME11000112_go3_lt0_area5_res1.00_stug_time2016.50.mat';

% STD with model grid overlay
opts.metric = 'std';
opts.display = 'grid';
opts.modelName = 'MERRA2-GMI';  % Change to your model
opts.markerSize = 20;

visualizeBMEdiagnostic(file, opts);

% Now check if vertical lines align with model grid structure!
```

## Troubleshooting

**Q: No figures appear**
- Check if BME result file exists
- Verify file path is correct
- Check MATLAB graphics settings

**Q: "No observation data available"**
- Variance and STD metrics don't have obs data
- Use `metric = 'mean'` to see observations

**Q: Color scale looks wrong**
- Use `opts.clim = [min max]` to set manually
- Check for outliers or NaN values
- Try different colormaps

**Q: Can't see vertical lines**
- Zoom in to examine closely
- Try `display = 'grid'` only
- Use variance instead of std (more sensitive)
- Try different colormap

**Q: Too many/too few points visible**
- Adjust `opts.markerSize`
- Default is 30, try 10-50 range

## Related Files

- `plotTOARsBME.m` - Standard BME plotting
- `plotTOARsBMEvar.m` - Standard variance plotting
- `estTOARsBME.m` - BME estimation function
- `getBMEparam.m` - BME parameter configuration
