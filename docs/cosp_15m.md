# cosp_15m: COSP on every physics time step

## Motivation

In stock CAM6, COSP is called from `radiation_tend` and therefore only on radiation time steps (every hour with the default `iradsw`/`iradlw`). Cloud-top phase statistics compared with CALIPSO benefit from sampling every physics time step (30 min at f09, 15 min with a shorter step) without making radiation more expensive.

## Design

- Namelist switch `cosp_15m` (group `cospsimulator_nl`, default `.false.`). With `.false.` the code path is the stock one.
- With `cosp_15m = .true.`:
  - `cospsimulator_intr_register` adds five physics-buffer fields that hold the radiation-derived COSP inputs: `COSP_CLDTAU`, `COSP_SNOWTAU`, `COSP_SNOWLW`, `COSP_EMIS` and `COSP_COSZRS`.
  - `radiation_tend` keeps its own interval. On radiation steps it stores the cloud optical depths, emissivities and cosine of the solar zenith angle in these fields instead of calling COSP.
  - `tphysbc` (`physpkg.F90`) calls `cospsimulator_intr_run` on every physics time step, right after the radiation call, with the current state and the most recent stored radiation inputs.
- `cosp_nradsteps` is ignored with `cosp_15m = .true.`.
- Radiative fluxes and heating rates are unchanged; only the sampling of the COSP simulators changes.
- The CloudSat subcolumn reflectivity means `DBZE_CS_MEAN` and `DBZE_CS_LINMEAN` are registered only with `cosp_15m = .true.` and the radar simulator on.

## Cost

COSP cost scales with the number of calls, so a run with `cosp_15m = .true.` and a 30 min physics step calls COSP twice as often as the stock hourly configuration.
