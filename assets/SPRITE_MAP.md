# Tiny Town sprite map (Kenney)

Atlas: `assets/kenney/tiny-town/Tilemap/tilemap_packed.png` — 12×11 grid, 16×16 px per cell (192×176 px).

## Terrain (ground TileMap)

| Role | Tile index | Notes |
|------|------------|--------|
| Grass | 0 | Plain meadow |
| Grass tufts | 1 | Variant |
| Grass flowers | 2 | Variant |
| Dirt patch | 3 | Decorative ground |
| Village paths | 25 | Solid tan dirt (sample paths) |
| Shore transitions | 13, 14 | Grass ↔ dirt edges at river |
| Courtyard / blocked | 60 | Stone paving for building footprints |
| Under river | 0 + overlay | **Gap:** pack has no open-water tile; river uses grass + semi-transparent blue overlay |

## Vegetation & props

| Role | Index |
|------|-------|
| Pine tree | 7 |
| Autumn pine | 4 |
| Round tree | 16 |
| Bush | 6 |
| Tree pair | 8 |
| Mushroom | 18 |
| Signpost | 83 |
| Well (roof + water) | 104 |
| Logs / beehive prop | 106 |

## Villagers (characters)

| Villager | Index |
|----------|-------|
| Mira | 45 |
| Elden | 56 |
| Toma | 58 |
| Pella | 59 |
| Finn | 73 |

Do **not** use building UI fragments (49–53), tools alone, or slime (5) as villagers.

## Buildings (multi-tile)

Composed from roof 67, wood walls 88–91, stone tower 102, walls 100, fences 24–25. See `VillageTiles.blueprint_*()` in `scripts/tiles.gd`.

## Points of interest

| POI | Props |
|-----|--------|
| Abandoned shrine | Stone arch 78 |
| Old ruins | Corner ruin 113 |
| River | Overlay only (see gap above) |

## Known asset gaps

- No dedicated **river/water surface** tile (well 104 is a structure, not terrain).
- No **animated walk cycles** for villagers (static 16×16 figures only).
- **Lumber camp** uses fence + logs/axe props rather than a unique building sprite.
