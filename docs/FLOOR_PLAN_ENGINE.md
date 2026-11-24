# Floor Plan Engine & Shared-Wall Rules

Floor Plan Intelligence is a domain system in `engine/lib/src/floorplan`, not a drawing widget.

## Data hierarchy
`Project → Building → Floor → Room → Wall (physical) + Opening`

- A **Room** owns a polygon (`[(x,y), ...]`, metres) used for floor-area calculation (shoelace formula).
- A **Wall** is an independent physical entity with a global unique ID, endpoints, thickness, height, type and material.
- The `room_walls` link table associates rooms with the walls that bound them. A shared wall has two or more links but **one** wall row.

## Shared-wall invariant (critical)
> No physical wall may be counted more than once in any building-level quantity takeoff.

Implementation rules:
1. `Wall.id` is globally unique and stable across edits; room deletion never deletes a wall that other rooms reference.
2. `SharedWallRegistry` indexes `wallId → Set<roomId>`.
3. Takeoff functions accept `Iterable<Wall>` and immediately deduplicate by `id` into a `LinkedHashMap<String, Wall>` before summing.
4. Editing a wall (length/thickness/height/openings) mutates the single wall record; all linked rooms observe the change on next recompute. No per-room wall copies exist.
5. Removing a room removes only its links; orphan walls are flagged, never silently deleted.
6. Opening area is subtracted from that wall's net area once, regardless of how many rooms share it.
7. Validation flags: duplicate wall ID, zero-length wall, overlapping collinear segments, wall not linked to any room, opening wider than wall, opening outside wall extent.

## Quantity takeoff from walls
For each deduplicated wall:
```
grossArea   = length × height
openingArea = Σ(width × height) for openings on that wall
netArea     = max(0, grossArea − openingArea)
brickworkVol= netArea × thickness
plasterArea = netArea × faces
```
`faces` is `1` or `2` depending on which linked rooms expose the wall; it is derived from links, not stored per room. Exterior walls use the configured external finish.

Bricks, mortar, cement, sand, plaster, paint and waterproofing are computed by passing wall takeoff into the construction calculators. Result: a shared wall contributes exactly once to building totals.

## Editor requirements (`lib/features/floorplan`)
- 2D canvas with grid + snapping (configurable snap step, default 0.05 m).
- Create room by drawing closed polygon; create wall by two clicks; select/tap; move; resize endpoints; rotate; delete; duplicate.
- Undo/redo stack of immutable commands (`AddRoom`, `MoveWall`, `SetOpening`, ...).
- Zoom/pan; measurement labels; room labels; wall labels.
- Door/window placement snaps to a wall and stores `offset_m`, `width_m`, `height_m`, `sill_m`.
- AI draft layers render with dashed strokes and status badges until user verification.

## Geometry validation
- Polygon must have ≥ 3 non-collinear vertices and no self-intersection.
- Room area > 0; wall length > 0; thickness within configured range.
- Overlapping rooms are allowed (e.g. halls) but flagged as a warning for review, not silently merged.

## Mandatory tests
`engine/test/floorplan/shared_wall_test.dart` must cover:
1. Two rooms sharing one wall → wall count 1, takeoff equals one wall.
2. Editing shared thickness → both rooms' recomputed takeoff changes consistently.
3. Deleting one room → shared wall retained for remaining room.
4. Duplicate wall ID injection → registry rejects/flags it.
5. Opening on shared wall → deducted once from building total.
6. Three-room chain sharing two walls → no duplication across the chain.
