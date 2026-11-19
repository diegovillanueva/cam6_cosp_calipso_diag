# cam6_cosp_calipso_diag

Output-only diagnostics for CESM 2.1.5 / CAM6, distributed as patches against CAM tag `cam_cesm2_1_rel_60`:

1. COSP on every physics time step and CALIPSO/CloudSat cloud-top diagnostics (`patches/`).
2. MG2 cloud-top temperature, pressure and phase fields (`patches/`, or `patches_on_minimal/` on top of mg2_limiter_update v1.0.1).
3. The in-model cloud-top diagnostics module `cloud_top_diag` (`patches_ctd/`, on top of mg2_limiter_update v1.0.1).

## Purpose

This repository provides the model diagnostics used for the cloud-top phase evaluation in

> Villanueva, D., et al. (in review): Reconciling droplet freezing parameterizations with cloud top phase and ice number observations.

The CALIPSO-simulator cloud-top phase and the `cloud_top_diag` fields are used for the cloud-top versus bulk ice fraction sensitivity maps (dITF/dLD) in the Supporting Information. The microphysics changes of the letter (droplet freezing limiter and related switches) are in [mg2_limiter_update](https://github.com/diegovillanueva/mg2_limiter_update); this repository adds diagnostics only.

## Contents

| Path | Purpose |
|---|---|
| `patches/` | Standalone set (5 files) for a clean `cam_cesm2_1_rel_60` |
| `patches_on_minimal/micro_mg_cam.F90.patch` | Replaces `patches/micro_mg_cam.F90.patch` on a tree that already carries mg2_limiter_update v1.0.1 |
| `patches_ctd/` | Cloud-top diagnostics module (3 new files, 13 modified files); applies after mg2_limiter_update v1.0.1, `patches/` and `patches_on_minimal/` |
| `scripts/apply_patches.sh` | Checks the CAM commit, then applies the selected set |
| `docs/cosp_15m.md` | Design of the `cosp_15m` switch |
| `versions.env` | CESM, CAM and source commit pins |
| `LICENSE`, `NOTICE`, `CITATION.cff`, `.zenodo.json` | Licence, third-party notice and citation metadata |
| `SHA256SUMS` | Checksums of all tracked files |

## Requirements

- CESM 2.1.5 (`release-cesm2.1.5`) with CAM `cam_cesm2_1_rel_60` checked out by `manage_externals/checkout_externals`.
- A COSP build (`./xmlchange --append CAM_CONFIG_OPTS=-cosp`) for the COSP fields.
- The MG2 microphysics (`micro_mg_version = 2`, default in CAM6) and `use_subcol_microp = .false.` for `patches_ctd/`.
- For `--on-minimal` and `--ctd`: the patches of [mg2_limiter_update](https://github.com/diegovillanueva/mg2_limiter_update) v1.0.1 applied first.
- git and bash to apply the patches.
- The patches are tested only on the MG2 microphysics stack (mg2_limiter_update); they were not tested with PUMAS (`micro_mg_version = 3`).

## Versions

| Component | Version |
|---|---|
| CESM | `release-cesm2.1.5` (`7a6c5b0d`) |
| CAM | `cam_cesm2_1_rel_60` (`a03b84b7`) |
| Source of `patches/`, `patches_on_minimal/` | the author's CAM development branch `dv_diag`, commit `e3bd85da` (tag `dv_diag-frozen-20261105`) |
| Source of `patches_ctd/` | CAM development worktree, commit `b5195044` |
| Base for `patches_on_minimal/`, `patches_ctd/` | mg2_limiter_update v1.0.1 (`e56c7bc9`) |

All pins are in `versions.env`.

## Group 1: COSP every time step, CALIPSO and CloudSat

Requires a COSP build and the usual COSP namelist switches (for example `cosp_lite = .true.`).
Files: `src/physics/cam/cospsimulator_intr.F90`, `src/physics/cam/physpkg.F90`, `src/physics/rrtmg/radiation.F90`, `bld/namelist_files/namelist_definition.xml`.

| Namelist (`cospsimulator_nl`) | Default | Effect |
|---|---|---|
| `cosp_15m` | `.false.` | Calls COSP on every physics time step from `physpkg` instead of on the radiation counter; radiation keeps its interval and stores the COSP inputs in the physics buffer (`COSP_CLDTAU`, `COSP_SNOWTAU`, `COSP_SNOWLW`, `COSP_EMIS`, `COSP_COSZRS`). See `docs/cosp_15m.md`. |

| Field | Units | Registered when | Meaning |
|---|---|---|---|
| `ACTT_CAL` | K | lidar simulator on | Temperature at the CALIPSO cloud top |
| `ACTP_CAL` | Pa | lidar simulator on | Pressure at the CALIPSO cloud top |
| `ACT_ITF_CAL` | fraction | lidar simulator on | Ice cover fraction at the CALIPSO cloud top |
| `DBZE_CS_MEAN` | dBZe (`lev`) | radar simulator on and `cosp_15m` | Subcolumn mean CloudSat reflectivity, averaged in dBZ |
| `DBZE_CS_LINMEAN` | dBZe (`lev`) | radar simulator on and `cosp_15m` | Same, averaged in linear Z and converted back |

The CALIPSO cloud top is the first COSP level from the top with `cld_cal > 0.01`; temperature and pressure are interpolated to that level height. Radar means use subcolumn samples of at least -30 dBZ and skip the undefined and ground flags. All five fields are instantaneous (`'I'`) and are not on any default history tape; request them with `fincl`.

## Group 2: MG2 cloud-top fields

File: `src/physics/cam/micro_mg_cam.F90`.

| Field | Units | Flag | Meaning |
|---|---|---|---|
| `ACTT` | K | `I` | Stratiform cloud-top temperature |
| `ACTP` | Pa | `I` | Stratiform cloud-top pressure |
| `ACT_NITF` | fraction | `I` | Cloud-top ice number fraction, `ACTNI / (ACTNL + ACTNI)` |
| `ACT_ITMF` | fraction | `I` | Cloud-top ice mass fraction, in-cloud ice / (ice + liquid) |

The four fields are set to the fill value 1.e36 where no cloud top is found and are registered with `flag_xyfill=.true., fill_value=1.e36_r8`, so the history files carry the matching `_FillValue`.

## Group 3: cloud-top diagnostics module (`patches_ctd/`)

New modules `cloud_top_diag.F90`, `cloud_top_diag_rates.F90` and `ctd_water_budget.F90`, with hooks in `micro_mg2_0.F90` (six extra grid-mean rate outputs), `micro_mg_cam.F90`, `physpkg.F90`, `clubb_intr.F90`, `zm_conv_intr.F90`, `radiation.F90`, `cam_diagnostics.F90`, `cloud_diagnostics.F90`, `cospsimulator_intr.F90`, `cam_history.F90`, `runtime_opts.F90` and the namelist XML files. With `ctd_on = .false.` (default) no field is registered and nothing is computed.

Namelist group `cloud_top_diag_nl`:

| Variable | Default | Meaning |
|---|---|---|
| `ctd_on` | `.false.` | Master switch |
| `ctd_qthr` | `1.e-7,1.e-6,1.e-5` | Three cloud-top thresholds on grid-mean CLDLIQ+CLDICE [kg/kg]; field suffix `T<j>` is the negative exponent |
| `ctd_mask_incl_snow` | `.false.` | Add snow to the cloud-top mask |
| `ctd_ctt_bin0` | `180.` | Lower edge of the first cloud-top temperature bin `ctt_bin` [K] |
| `ctd_dbin` | `3.` | Bin width [K] |
| `ctd_nbin` | `40` | Number of bins |
| `ctd_h0_default` | `3` | Fields added to h0 by default: 0 none, 1 all 2-D fields, 2 also the bin families of `T<ctd_combo_thr>` and the `*_TB` fields, 3 everything |
| `ctd_combo_thr` | `5` | Threshold exponent of the combined regime by bin family and of level 2 |

Field families (all grid-mean; binned fields are zero outside the bin of the current cloud top, so the ratio of time means gives the conditional mean per cloud-top temperature):

| Family | Meaning |
|---|---|
| `CTT_T<j>`, `CTP_T<j>`, `CVF_T<j>`, `ILF_T<j>`, `ISLF_T<j>` | Cloud-top temperature, pressure, cover frequency, ice and supercooled liquid fractions per threshold |
| `<VAR>_PATH`, `<VAR>_PATH_C/M/W` | Column paths of every MG2 rate, tendency and number/mass, split by layer temperature (C below 234.15 K, W above 273.15 K) |
| `<VAR>_CTT_T<j>`, `CVF_CTT_T<j>`, `ILF_CTT_T<j>` | The same, binned on cloud-top temperature (`ctt_bin` coordinate) |
| `TWP_TB`, `TCP_TB`, `ICP_TB`, `IWP_TB` | Water paths binned on layer temperature |
| `NCALL_CAL`, `N_CAL_CTT`, `ICE_CAL_CTT`, `LIQ_CAL_CTT`, `UN_CAL_CTT`, `CVF_CAL_CTT`, `CTT_CAL_CTT` (and `_T<j>` variants) | CALIPSO-simulator cloud-top phase binned on `ACTT_CAL` and on the MG2 cloud top (COSP build only) |

Use in the letter (Supporting Information, dITF/dLD maps, run `F2000climo` nudged 1979-2006):

- cloud-top ice fraction, model: `ILF_CTT_T5 / CVF_CTT_T5`
- bulk ice fraction, model: `IWP_TB / TWP_TB`
- cloud-top ice fraction, CALIPSO simulator: `ICE_CAL_CTT / (ICE_CAL_CTT + LIQ_CAL_CTT)`
- bulk ice fraction, CALIPSO simulator: `CLD_CAL_TMPICE / (CLD_CAL_TMPICE + CLD_CAL_TMPLIQ)` (with the swap fix below)

Namelist used for the Fig. 3 runs starting in 1979 (`user_nl_cam`):

```fortran
ctd_on         = .true.
ctd_h0_default = 3
ctd_combo_thr  = 5
nhtfrq         = 0
mfilt          = 1
fincl1         = 'CLD_CAL_TMPICE:A','CLD_CAL_TMPLIQ:A','CLD_CAL_TMPUN:A','CLD_CAL_TMP:A'
```

## CALIPSO temperature-phase swap fix

COSP2 fills `calipso_lidarcldtmp(:,:,k)` with k = 1 total, 2 ice, 3 liquid, 4 undefined (`lidar_simulator.F90`).
Stock `cospsimulator_intr.F90` of `cam_cesm2_1_rel_60` reads index 2 into `cld_cal_tmpliq` and index 3 into `cld_cal_tmpice`, so in stock CAM the history fields `CLD_CAL_TMPLIQ` and `CLD_CAL_TMPICE` are swapped.
Both `cospsimulator_intr.F90` patches here (`patches/`, `patches_ctd/`) correct this (`tmpliq = index 3`, `tmpice = index 2`), as in CAM commit `174524a7` (full hash in `versions.env`) that built the 1979 runs of the letter.
Archives from stock CAM, or from builds of `dv_diag` before the fix, need the two fields swapped. In the letter this applies to the Fig. 2 profile runs; the plotting code handles that.

## Effect on model results

- No change touches the model state or tendencies: everything is history output, and `cosp_15m` and `ctd_on` default to `.false.`.
- One exception in the diagnostics: the standalone `patches/micro_mg_cam.F90.patch` carries the cloud-top definition that the `ACT*` fields need. Cloud top becomes the first layer with `totcldf > 0.01` and total in-cloud condensate `ictmrst > 1.e-5` kg/kg, instead of the stock separate liquid and ice tests (`> 1.e-7`). This changes the stock outputs `ACTREL`, `ACTNL`, `ACTREI`, `ACTNI`, `FCTL`, `FCTI`, `FCTM`, `FCTSL` and `FCTSLM`. The same definition is part of mg2_limiter_update v1.0.1, so the on-minimal variant adds fields only.
- With `cosp_15m = .true.`, five extra physics-buffer fields are registered and COSP sampling changes; radiation is unchanged.
- `patches_ctd/` adds six `intent(out)` arguments to `micro_mg_tend` that copy existing rates; they do not feed back on the tendencies.
- No bit-for-bit test was run for this repository; neutrality is argued from the code.

## How to apply

```bash
# clean cam_cesm2_1_rel_60
scripts/apply_patches.sh <CESM_ROOT>/components/cam

# tree that already has mg2_limiter_update v1.0.1 applied
scripts/apply_patches.sh --on-minimal <CESM_ROOT>/components/cam

# same, plus the cloud-top diagnostics module
scripts/apply_patches.sh --on-minimal --ctd <CESM_ROOT>/components/cam
```

The script stops unless CAM `HEAD` is `a03b84b7` (`cam_cesm2_1_rel_60`), runs `git apply --check` on the whole set, then applies it. Build with `-cosp` and set, for example:

```fortran
cosp_lite = .true.
cosp_15m  = .true.
fincl2    = 'ACTT_CAL','ACTP_CAL','ACT_ITF_CAL','DBZE_CS_MEAN','DBZE_CS_LINMEAN',
            'ACTT','ACTP','ACT_NITF','ACT_ITMF'
```

## Validation

- `git apply --check` passes for `patches/` on `cam_cesm2_1_rel_60` (`a03b84b7`), for `patches/` with `patches_on_minimal/` on top of mg2_limiter_update v1.0.1, and for `patches_ctd/` on top of that.
- `patches/` and `patches_on_minimal/` are identical to `dv_diag` commit `e3bd85da` except comments, the four removed placeholder fields (column path fields that were always zero) and the fill values.
- `patches_ctd/` contains only the cloud-top diagnostic changes of commit `b5195044`; the other changes on that branch are not included.
- The `dv_diag` code was compiled with gfortran 8.5 and `-DUSE_COSP` and used in model runs. The cleaned patch sets were not recompiled as a whole and no run was made with them.
- Checksums: `sha256sum -c SHA256SUMS`.

## Related repositories

- [mg2_limiter_update](https://github.com/diegovillanueva/mg2_limiter_update): droplet freezing limiter and microphysics switches for MG2 (CESM 2.1.5 default), with the run configurations.
- [PUMAS_interface_215](https://github.com/diegovillanueva/PUMAS_interface_215): CAM patches that let CESM 2.1.5 run PUMAS.
- [pumas_limiter_update](https://github.com/diegovillanueva/pumas_limiter_update): the droplet freezing limiter for PUMAS, applied on top of PUMAS_interface_215.

## Data availability

Model output of the runs is available from the author on request.

## Licence and citation

The changes in this repository are released under the BSD 3-Clause License (`LICENSE`). The patches modify CESM2/CAM6 source code, copyright UCAR, which remains under the CESM2 terms of use; see `NOTICE`.

Please cite Villanueva et al. (in review) and this software via the Zenodo DOI of the release (metadata in `CITATION.cff`). A Zenodo DOI is minted for release v1.0.0.

## Contact

Diego Villanueva, Institute for Atmospheric and Climate Science, ETH Zurich (GitHub: diegovillanueva).
