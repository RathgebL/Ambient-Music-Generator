# Ambient Music Generator

An interactive SuperCollider project for my Creative Coding II class with Michele Samarotto at HfM Karlsruhe.
It provides two players (Conductor and FreePlayer), a mixing console with GUI, and flexible parameter mappings for generating evolving ambient soundscapes.

## Quick Start

### 1. Open Main.scd

This is the entry point of the project. It provides:

A banner

Setup instructions

Shortcuts to players

A link to this README

### 2. Run Setup

Inside Main.scd, run:

```Setup.scd".loadRelative;```

This will:

Reboot the SC server

Allocate buses

Load all SynthDefs, Engines, Helpers, Patterns, and Scores

Initialize the mixer and GUI

Setup may take a few seconds.

### 3. Choose a Player

You have two options:

*Conductor*
Structured playback with six movements:

1. Intro

2. Inhale

3. Shimmer

4. Ground

5. Punctuate

6. Exhale

Run it:

```"Player/FreePlayer.scd".loadRelative;```

Stop playback anytime with Cmd + .

## Features

Mixing Console + GUI
Full-featured virtual mixer with faders, mute, solo, and groups for instruments, textures, and FX.

Texture Synths
Continuous textures like rain, vinyl crackle, and sea waves, implemented with Pmono patterns.

Harmony Engine
Markov-based harmonic progression system with flexible scale and key selection.

Scores
Predefined structures that fade between layers, groups, and effects over time.

Parameter Mapping
Centralized mappings for density, brightness, rhythmicity, and other expressive controls.

## Project Structure

```Ambient-Music-Generator/
├── AMG-main.scd                   # Main entry point (banner, setup, players)
├── Setup.scd                      # Loads everything after server boot
│
├── Buses/
│   └── Buses.scd                  # Bus allocation and reset utilities
│
├── Checks/
│   └── Checks.scd                 # Debugging / manual checks
│
├── Engines/
│   ├── Control/
│   │   └── Control.scd            # Control engine
│   │
│   ├── Harmony/
│   │   └── Harmony.scd            # Harmony engine
│   │
│   ├── Mixing/
│   │   ├── Mixing-Console.scd     # Mixer engine
│   │   └── Mixing-Console-GUI.scd # Mixer GUI
│   │
│   └── Parameter/
│       ├── Mappings.scd           # Parameter mappings
│       └── Parameter.scd          # Parameter engine
│
├── Helper/
│   └── Helpers.scd                # Helpers and utilities
│
├── Patterns/
│   └── Pdefs.scd                  # Pattern and texture definitions
│
├── Player/
│   ├── Conductor.scd              # Conductor (score-based performance)
│   └── FreePlayer.scd             # Free/improvised performance
│
├── Scores/
│   └── Scores.scd                 # Score structures
│
├── Server/
│   └── Server-Setup.scd           # Server config and options
│ 
└── Synths/
    └── SynthDefs.scd              # All SynthDefs
```

## Requirements

SuperCollider 3.13+

Works best with a stereo output device (though multi-channel setups are supported).

## Example Workflow

Run setup

Launch Conductor

Enjoy six movements of evolving ambient textures

Or launch FreePlayer for endless generative improvisation

Adjust mixer faders in the GUI to blend instruments and effects

## License

- **Code** (SuperCollider scripts, SynthDefs, helpers, etc.): [MIT License](LICENSE)  
- **Artistic content** (scores, harmony engine, textures, musical output): [CC-BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)  

This means:
- You are free to study, modify, and reuse the code without restrictions.  
- You are free to perform and record the generated music for *non-commercial* purposes, provided you give attribution.  
- Commercial use of the musical output requires explicit permission.