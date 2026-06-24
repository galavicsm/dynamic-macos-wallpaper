# Dynamic Wallpaper

This project creates a macOS dynamic wallpaper HEIC from two PNG images:

- a light/day image
- a dark/night image

The included Swift script writes a two-frame HEIC and embeds Apple's light/dark appearance metadata so macOS can switch between the images automatically.

## Files

- `make_dynamic.swift` - generates the dynamic wallpaper

## Requirements

- macOS
- Swift
- HEIC encoding support available through the system image frameworks

## Usage

Run:

```bash
swift make_dynamic.swift --light <light-image> --dark <dark-image> --output <output.heic>
```

Example:

```bash
swift make_dynamic.swift --light abstract-waves-sun.png --dark abstract-waves-moon.png --output dynamic-waves-sun-moon.heic
```

You can use any input filenames and any output filename you want, as long as the output ends in `.heic`.

## Notes

- The script maps image `0` to Light Mode and image `1` to Dark Mode.
- Source images should have the same dimensions for the best result.
- Tested with image resolution `3840x2160`.
