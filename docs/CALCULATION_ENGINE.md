# Construction Calculation Engine

All formulas live in `engine/lib/src/calculators`. Every calculator receives a typed input plus a configurable `Assumptions` object and returns `CalculationResult<T>` containing: `input` echo, `output`, `formulaIds`, `steps` (labelled intermediate values), `units`, `assumptions`, `warnings`, optional `cost`, and `validity`.

## Shared conventions
- All geometry inputs are SI (m, m², m³) at the engine boundary; UI converts using `engine.units`.
- Rounding happens at presentation/export boundaries via `PrecisionPolicy` (default: 3 decimals for volumes, 2 for areas, 0 for piece counts rounded up).
- Quantity counts (bricks, bags, tiles, bars) round **up** to whole units; volumes/masses keep decimals.
- Waste is applied once, to the final quantity: `final = netQuantity × (1 + wastePercent/100)`.
- Cost = `finalQuantity × unitRate`, with rates supplied by the caller (never invented).

## Concrete

| Step | Formula | Notes |
|---|---|---|
| Wet volume | `L × W × T` (rectangular element); element-specific helpers for column/beam/footing/stair | m³ |
| Dry volume | `wet × dryFactor` | default `dryFactor = 1.54`, configurable |
| Mix share | `share_i = dry × ratio_i / Σratio` | e.g. M20 1:1.5:3 → Σ=5.5 |
| Cement mass | `cementVolume × cementDensity` | density default 1440 kg/m³ |
| Cement bags | `ceil(cementMass / bagWeight)` | bag default 50 kg; volume per bag ≈ 0.0347 m³ |
| Sand / aggregate | `share_sand`, `share_aggregate` in m³ | optionally converted to CFT |
| Water | `cementMass × waterCementRatio` litres | default 0.50, configurable range |
| Waste & cost | applied to each material | rates from `MaterialRates` |

Supported elements: PCC, RCC, footing, foundation, column, beam, slab, roof, stair, lintel, ground beam. Each element has its own input model and formula ID (e.g. `concrete.slab.v1`, `concrete.column.v1`) so reports are traceable.

## Brick & masonry

| Step | Formula |
|---|---|
| Wall volume | `length × height × thickness` (openings subtracted when supplied) |
| Brick volume | `brickL × brickW × brickH` |
| Nominal unit with mortar | `(brickL + joint) × (brickW + joint) × (brickH + joint)` |
| Bricks | `ceil(wallVolume / nominalUnitVolume × (1 + waste))` |
| Mortar volume | `wallVolume − bricksNet × brickVolume` (floored at 0) |
| Cement (1:m) | `mortarDry × cementDensity / (1+m) / bagWeight` → bags |
| Sand | `mortarDry × m / (1+m)` m³ |

`mortarDry = mortarWet × mortarDryFactor` (default 1.33). Orientation, joint thickness, brick dimensions and waste are configurable.

## Steel & rebar

| Step | Formula |
|---|---|
| Unit weight | `D² / 162` kg/m for circular bar diameter D in mm (derived from steel density 7850 kg/m³) |
| Cutting length | member length + hook/development length − cover adjustments (configurable) |
| Number of bars | `ceil(spacing span / spacing) + 1` |
| Total weight | `unitWeight × cuttingLength × count × (1 + waste)` |
| Cost | `weight × ratePerKg` |

Square bars use `side² × 0.00785` kg/m; sections (angle/channel) use table lookup with explicit warning if absent.

## Finishing

| Item | Formula |
|---|---|
| Plaster | `area × thickness → wet m³ → dry (×1.33) → cement:sand (default 1:4 wall, 1:3 ceiling)` |
| Putty | `area / coverage(m²/kg) × coats` |
| Primer | `area / coverage(m²/L) × coats` |
| Paint | `area / coverage(m²/L) × coats` |
| Tiles | `ceil(area / tileArea × (1+waste))`; skirting `perimeter × skirtingHeight` |
| Waterproofing | `area / coverage × coats` |
| Ceiling | area-based with ceiling-specific plaster/paint assumptions |

## Validation & safety
- Non-positive dimensions, negative waste > 100%, unknown mix ratio, zero density → `ValidationIssue` with field and message.
- Division by zero is always an error result; no NaN/Infinity leaks to UI.
- Structural adequacy is **not** claimed. Every result involving load-bearing elements carries: "Estimation only — requires qualified structural engineer review."

## Test expectations
Golden tests assert exact outputs for documented examples (e.g. 10 m³ M20 concrete with 1.54 dry factor; 100 m² 12 mm plaster 1:4), plus waste=0, waste>0, invalid input, precision and cost paths.
