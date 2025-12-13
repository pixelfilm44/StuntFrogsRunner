# Asset Naming Convention Reference

## Quick Reference Table

| Entity Type | Sunny | Night | Rain | Winter | Desert | Space |
|-------------|-------|-------|------|--------|--------|-------|
| **Bee** | `bee` | `beeNight` | `beeRain` | `beeWinter` | `beeDesert` | `beeSpace` |
| **Dragonfly** | `dragonfly` | `dragonflyNight` | `dragonflyRain` | `dragonflyWinter` | `dragonflyDesert` | `asteroid` |
| **Log** | `log` | `logNight` | `logRain` | `logWinter` | `logDesert` | `logSpace` |

## Snake Animation Frames

Each weather type has 5 animation frames:

### Sunny
```
snake1.png
snake2.png
snake3.png
snake4.png
snake5.png
```

### Night
```
snakeNight1.png
snakeNight2.png
snakeNight3.png
snakeNight4.png
snakeNight5.png
```

### Rain
```
snakeRain1.png
snakeRain2.png
snakeRain3.png
snakeRain4.png
snakeRain5.png
```

### Winter
```
snakeWinter1.png
snakeWinter2.png
snakeWinter3.png
snakeWinter4.png
snakeWinter5.png
```

### Desert
```
snakeDesert1.png
snakeDesert2.png
snakeDesert3.png
snakeDesert4.png
snakeDesert5.png
```

### Space
```
snakeSpace1.png
snakeSpace2.png
snakeSpace3.png
snakeSpace4.png
snakeSpace5.png
```

## Asset Status Checklist

Use this to track which assets you've created:

### Bees
- [x] bee (exists)
- [ ] beeNight
- [ ] beeRain
- [ ] beeWinter
- [ ] beeDesert
- [x] beeSpace (exists)

### Dragonflies
- [x] dragonfly (exists)
- [ ] dragonflyNight
- [ ] dragonflyRain
- [ ] dragonflyWinter
- [ ] dragonflyDesert
- [x] asteroid (exists as space variant)

### Logs
- [x] log (exists)
- [ ] logNight
- [ ] logRain
- [ ] logWinter
- [ ] logDesert
- [ ] logSpace

### Snakes (30 frames total)
- [x] snake1-5 (exists)
- [ ] snakeNight1-5
- [ ] snakeRain1-5
- [ ] snakeWinter1-5
- [ ] snakeDesert1-5
- [ ] snakeSpace1-5

## Total Assets Needed

- **Bees:** 4 new variants (2 exist)
- **Dragonflies:** 4 new variants (2 exist)
- **Logs:** 5 new variants (1 exists)
- **Snakes:** 25 new frames (5 exist)

**Grand Total:** 38 new texture assets needed

## Batch Creation Tips

### Using Image Editing Software

#### Adobe Photoshop / Affinity Photo
1. Open the base texture
2. Create adjustment layers for each variant:
   - Night: Levels (darken), Hue/Saturation (cooler)
   - Rain: Levels (darken slightly), add glossy overlay
   - Winter: Hue/Saturation (blue), add white overlay
   - Desert: Hue/Saturation (warmer), add sand texture
   - Space: Color Balance (purple/cyan), add glow
3. Use batch processing to export all variants
4. Export with exact naming convention

#### Procreate
1. Duplicate your base asset 5 times
2. Use color adjustment layers for each weather
3. Export each with the correct naming

### Using Code (Python + Pillow)

```python
from PIL import Image, ImageEnhance, ImageFilter

def create_night_variant(base_path, output_path):
    img = Image.open(base_path)
    # Darken
    enhancer = ImageEnhance.Brightness(img)
    img = enhancer.enhance(0.6)
    # Cool tones
    enhancer = ImageEnhance.Color(img)
    img = enhancer.enhance(0.8)
    img.save(output_path)

def create_rain_variant(base_path, output_path):
    img = Image.open(base_path)
    # Slightly darker and more saturated
    enhancer = ImageEnhance.Brightness(img)
    img = enhancer.enhance(0.85)
    enhancer = ImageEnhance.Contrast(img)
    img = enhancer.enhance(1.2)
    img.save(output_path)

# Use for batch processing all variants
```

### Using AI Tools

Prompt suggestions for each weather type:

**Night:** "Make this [creature/object] darker with cool blue tones and subtle bioluminescent glow"

**Rain:** "Add wet, glossy appearance with water droplets, slightly darker and more saturated"

**Winter:** "Cover with frost and ice crystals, pale blue-white coloration, winter themed"

**Desert:** "Desert environment colors, sandy browns and oranges, dry weathered appearance"

**Space:** "Alien futuristic version with neon glowing accents and metallic surfaces"

## File Organization

Suggested folder structure in your Xcode asset catalog:

```
Assets.xcassets/
├── Enemies/
│   ├── Bees/
│   │   ├── bee.imageset/
│   │   ├── beeNight.imageset/
│   │   ├── beeRain.imageset/
│   │   ├── beeWinter.imageset/
│   │   ├── beeDesert.imageset/
│   │   └── beeSpace.imageset/
│   ├── Dragonflies/
│   │   ├── dragonfly.imageset/
│   │   ├── dragonflyNight.imageset/
│   │   ├── dragonflyRain.imageset/
│   │   ├── dragonflyWinter.imageset/
│   │   ├── dragonflyDesert.imageset/
│   │   └── asteroid.imageset/
│   └── Snakes/
│       ├── Sunny/
│       │   └── snake1-5.imageset/
│       ├── Night/
│       │   └── snakeNight1-5.imageset/
│       ├── Rain/
│       │   └── snakeRain1-5.imageset/
│       ├── Winter/
│       │   └── snakeWinter1-5.imageset/
│       ├── Desert/
│       │   └── snakeDesert1-5.imageset/
│       └── Space/
│           └── snakeSpace1-5.imageset/
└── Environment/
    └── Logs/
        ├── log.imageset/
        ├── logNight.imageset/
        ├── logRain.imageset/
        ├── logWinter.imageset/
        ├── logDesert.imageset/
        └── logSpace.imageset/
```

## Resolution Guidelines

Match your existing assets:
- Check the resolution of your current `bee.png`
- Use the same resolution for all variants
- Typical sizes: 30x30 for small enemies, 120x40 for logs, 60x40 for snakes
- Use @2x and @3x variants for retina displays if needed

## Color Palette Suggestions

### Night
- Base: Darken by 40%
- Accent: Cool blues (#1A3B5C, #2E5266)
- Glow: Pale cyan (#7FDBFF)

### Rain
- Base: Darken by 15%, increase saturation
- Accent: Blue-gray (#607D8B, #455A64)
- Shine: White highlights

### Winter
- Base: Desaturate, lighten slightly
- Accent: Ice blue (#B3E5FC, #81D4FA)
- Frost: White (#FFFFFF, #F5F5F5)

### Desert
- Base: Warm tones
- Accent: Sandy browns (#D4A574, #C9A882)
- Highlights: Bright orange (#FF9800)

### Space
- Base: Dark with high contrast
- Accent: Neon purple (#9C27B0, #E040FB)
- Glow: Cyan (#00BCD4, #00E5FF)

## Testing Each Variant

After creating assets, test them in-game:

```swift
// In your game scene's update or a test method
func cycleWeatherForTesting() {
    let weathers: [WeatherType] = [.sunny, .night, .rain, .winter, .desert, .space]
    var currentIndex = 0
    
    // Call this every few seconds to see all variants
    Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
        let weather = weathers[currentIndex]
        self.transitionWeather(to: weather, duration: 0.5)
        currentIndex = (currentIndex + 1) % weathers.count
    }
}
```
