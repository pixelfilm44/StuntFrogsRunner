# Weather Variant Assets Required

This document lists all the texture assets that need to be added to your asset catalog to support weather-specific variants for enemies and logs.

## 🐝 Bee Variants
The bee enemy now supports textures for all 6 weather types:

- ✅ `bee.png` (sunny - already exists)
- ⚠️ `beeNight.png` (darker coloration for night)
- ⚠️ `beeRain.png` (wet appearance for rain)
- ⚠️ `beeWinter.png` (frost/snow covered for winter)
- ⚠️ `beeDesert.png` (desert coloration, possibly scorpion-like)
- ✅ `beeSpace.png` (alien/robotic variant - already exists)

## 🦋 Dragonfly Variants
The dragonfly enemy now supports textures for all 6 weather types:

- ✅ `dragonfly.png` (sunny - already exists)
- ⚠️ `dragonflyNight.png` (darker/glowing variant for night)
- ⚠️ `dragonflyRain.png` (wet appearance for rain)
- ⚠️ `dragonflyWinter.png` (icy/crystalline variant for winter)
- ⚠️ `dragonflyDesert.png` (desert insect variant)
- ✅ `asteroid.png` (space variant - already exists)

## 🐍 Snake Variants (5 frames each)
The snake enemy uses 5-frame animations and now supports all weather types:

### Sunny (already exists)
- ✅ `snake1.png` through `snake5.png`

### Night
- ⚠️ `snakeNight1.png` through `snakeNight5.png` (darker, glowing eyes)

### Rain
- ⚠️ `snakeRain1.png` through `snakeRain5.png` (wet, shiny appearance)

### Winter
- ⚠️ `snakeWinter1.png` through `snakeWinter5.png` (ice snake or pale coloration)

### Desert
- ⚠️ `snakeDesert1.png` through `snakeDesert5.png` (sand-colored rattlesnake)

### Space
- ⚠️ `snakeSpace1.png` through `snakeSpace5.png` (alien serpent or energy coil)

## 🪵 Log Variants
Logs now support textures for all 6 weather types:

- ✅ `log.png` (sunny - already exists)
- ⚠️ `logNight.png` (darker log texture)
- ⚠️ `logRain.png` (wet, darker log)
- ⚠️ `logWinter.png` (snow-covered or icy log)
- ⚠️ `logDesert.png` (driftwood or desert wood)
- ⚠️ `logSpace.png` (metallic beam or alien material)

## Design Guidelines

### Night Variants
- Darker overall colors
- Add subtle glow effects (glowing eyes for creatures)
- Cooler color temperature
- Moon/star motifs where appropriate

### Rain Variants
- Add water droplets or wet sheen
- Darker, saturated colors
- Reflective highlights
- Water effects

### Winter Variants
- Add snow, frost, or ice crystals
- Cooler color palette (blues, whites)
- Crystalline effects
- Icicles where appropriate

### Desert Variants
- Warm color palette (browns, oranges, yellows)
- Sand texture or dune patterns
- Weathered/dried appearance
- Cactus or desert creature themes

### Space Variants
- Alien/futuristic appearance
- Glowing neon accents
- Metallic or crystalline materials
- Stars, nebula patterns, or cosmic effects
- Bioluminescence

## Implementation Notes

All texture loading is now centralized in the entity classes:
- `Enemy` class handles bee, dragonfly, and ghost textures
- `Pad` class handles log textures
- `Snake` class handles snake animation frames

The code will automatically:
1. Load the correct texture based on current weather
2. Update textures when weather changes
3. Maintain animation frame sync for snakes
4. Use fallback textures if weather variants are missing

## Priority Order

If you need to implement these gradually, here's a suggested priority:

1. **High Priority (Most Visible)**
   - Snake variants (appears frequently, large on screen)
   - Log variants (common obstacle)
   
2. **Medium Priority**
   - Bee variants (common enemy)
   - Dragonfly variants (frequent in certain weather)

3. **Lower Priority**
   - Can start with recolored versions before creating fully unique designs
   - Space variants already exist for bees and dragonflies

## Fallback Behavior

If a weather-specific texture is missing, the code will:
- Use the base texture (sunny variant)
- Not crash or show errors
- Continue to function normally

This means you can implement variants gradually and test as you go.
