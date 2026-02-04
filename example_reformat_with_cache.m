% example_reformat_with_cache.m
% Examples demonstrating the updated reformat_stg_to_stug with caching

%% Example 1: Basic usage with caching (default)
% When you provide model name, it will cache the reformatted data

% Assuming you have loaded soft data from M3fusion
% grid_data = reformat_stg_to_stug(KS.softdata, 'modelName', 'M3fusion');
%
% First run: Reformats and saves to cache
% Subsequent runs: Loads from cache (much faster!)
%
% Cache file location: 0cache/stug/stug_M3fusion_global_y2015-2020_abc12345.mat

fprintf('\n=== Example 1: Basic Caching ===\n');
fprintf('Usage:\n');
fprintf('  grid_data = reformat_stg_to_stug(KS.softdata, ''modelName'', ''M3fusion'');\n\n');

%% Example 2: Multiple datasets with detailed naming
% When working with multiple satellite/model datasets, use descriptive names

fprintf('\n=== Example 2: Multiple Datasets ===\n');
fprintf('For OMI-MLS satellite data:\n');
fprintf('  grid_omi = reformat_stg_to_stug(omi_data, ...\n');
fprintf('      ''modelName'', ''OMI-MLS'', ...\n');
fprintf('      ''areaCode'', ''global'', ...\n');
fprintf('      ''dataFormat'', ''stug_v2'');\n\n');

fprintf('For IASI-GOME2 satellite data:\n');
fprintf('  grid_iasi = reformat_stg_to_stug(iasi_data, ...\n');
fprintf('      ''modelName'', ''IASI-GOME2'', ...\n');
fprintf('      ''areaCode'', ''global'');\n\n');

fprintf('For regional analysis (e.g., North America):\n');
fprintf('  grid_na = reformat_stg_to_stug(na_data, ...\n');
fprintf('      ''modelName'', ''M3fusion'', ...\n');
fprintf('      ''areaCode'', ''NA'');\n\n');

%% Example 3: Force reformatting (skip cache)
% Use this when you've updated the source data and need to regenerate

fprintf('\n=== Example 3: Force Reformat ===\n');
fprintf('When source data has been updated:\n');
fprintf('  grid_data = reformat_stg_to_stug(KS.softdata, ...\n');
fprintf('      ''modelName'', ''M3fusion'', ...\n');
fprintf('      ''forceReformat'', true);\n\n');

%% Example 4: Disable caching (for testing or temporary use)

fprintf('\n=== Example 4: No Caching ===\n');
fprintf('For one-time use or testing:\n');
fprintf('  grid_data = reformat_stg_to_stug(KS.softdata, ...\n');
fprintf('      ''saveCache'', false);\n\n');

%% Example 5: Non-uniform grid handling
% The function now automatically detects and handles non-uniform grids

fprintf('\n=== Example 5: Non-Uniform Grids ===\n');
fprintf('If your data is not uniformly gridded:\n');
fprintf('  - Function automatically detects this\n');
fprintf('  - Uses stg_to_stug hybrid method for regridding\n');
fprintf('  - No error thrown, just automatic handling\n\n');

fprintf('Example:\n');
fprintf('  grid_data = reformat_stg_to_stug(irregular_data, ...\n');
fprintf('      ''modelName'', ''NJML'', ...\n');
fprintf('      ''method'', ''hybrid'', ...\n');
fprintf('      ''resolution'', 0.5);  %% 0.5 degree grid\n\n');

%% Example 6: Custom cache directory

fprintf('\n=== Example 6: Custom Cache Location ===\n');
fprintf('  grid_data = reformat_stg_to_stug(KS.softdata, ...\n');
fprintf('      ''modelName'', ''M3fusion'', ...\n');
fprintf('      ''cacheDir'', ''my_cache/stug_files'');\n\n');

%% Example 7: Typical workflow in runCBV_toar.m

fprintf('\n=== Example 7: Typical CBV Workflow ===\n');
fprintf('In runCBV_toar.m, you can now use:\n\n');

fprintf('%% For cell array of soft datasets:\n');
fprintf('for ii = 1:length(KS_fold.softdata)\n');
fprintf('    soft_data_stug{ii} = reformat_stg_to_stug(KS_fold.softdata{ii}, ...\n');
fprintf('        ''modelName'', sprintf(''model_%%d'', ii), ...\n');
fprintf('        ''verbose'', false);\n');
fprintf('end\n\n');

fprintf('%% For single soft dataset:\n');
fprintf('soft_data_stug = reformat_stg_to_stug(KS_fold.softdata, ...\n');
fprintf('    ''modelName'', ''M3fusion'', ...\n');
fprintf('    ''areaCode'', sprintf(''box%%d_fold%%d'', iBox, iFold), ...\n');
fprintf('    ''verbose'', false);\n\n');

%% Cache File Naming Convention

fprintf('\n=== Cache File Naming Convention ===\n');
fprintf('Files are named as:\n');
fprintf('  stug_{modelName}_{areaCode}_y{startYear}-{endYear}_{dataHash}.mat\n\n');

fprintf('Examples:\n');
fprintf('  stug_M3fusion_global_y2015-2020_abc12345.mat\n');
fprintf('  stug_OMI-MLS_NA_y2005-2019_def67890.mat\n');
fprintf('  stug_IASI-GOME2_global_y2017-2020_ghi13579.mat\n\n');

fprintf('The hash ensures unique files for different spatial/temporal extents\n\n');

%% Performance Benefits

fprintf('\n=== Performance Benefits ===\n');
fprintf('First run (no cache):\n');
fprintf('  - Uniform grid: ~2-5 seconds\n');
fprintf('  - Non-uniform grid (hybrid): ~10-30 seconds depending on size\n\n');

fprintf('Subsequent runs (with cache):\n');
fprintf('  - Load from cache: ~0.5-2 seconds\n');
fprintf('  - Speedup: 5-20x faster!\n\n');

%% Metadata Information

fprintf('\n=== Metadata Available ===\n');
fprintf('After reformatting, grid_data.metadata contains:\n');
fprintf('  .loaded_from_cache - Boolean, true if loaded from cache\n');
fprintf('  .cache_file - Full path to cache file\n');
fprintf('  .model_name - Model/dataset name\n');
fprintf('  .area_code - Geographic area code\n');
fprintf('  .year_range - [start_year, end_year]\n');
fprintf('  .source_format - ''STG_uniform'' or ''STG_nonuniform''\n');
fprintf('  .reformatting_function - Which method was used\n');
fprintf('  .regridding_method - ''hybrid'', ''linear'', etc. (if non-uniform)\n\n');

%% Checking if cache was used

fprintf('\n=== Check Cache Usage ===\n');
fprintf('To see if data was loaded from cache:\n');
fprintf('  if grid_data.metadata.loaded_from_cache\n');
fprintf('      fprintf(''Loaded from: %%s\\n'', grid_data.metadata.cache_file);\n');
fprintf('  else\n');
fprintf('      fprintf(''Freshly reformatted\\n'');\n');
fprintf('  end\n\n');

%% Best Practices

fprintf('\n=== Best Practices ===\n');
fprintf('1. Always provide meaningful modelName for caching\n');
fprintf('2. Use areaCode to distinguish different spatial subsets\n');
fprintf('3. Set verbose=false in loops to reduce output clutter\n');
fprintf('4. Use forceReformat=true when source data has changed\n');
fprintf('5. Let the function auto-detect uniform vs non-uniform grids\n');
fprintf('6. For non-uniform grids, prefer ''hybrid'' method for BME\n');
fprintf('7. Check metadata.loaded_from_cache to verify caching is working\n\n');

fprintf('For more information, see: help reformat_stg_to_stug\n\n');
