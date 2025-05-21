# Urban Assault Level Creator

<div align="center">
  <img src="screenshots/ualc1.png" width="350"/>
  <img src="screenshots/ualc2.png" width="350"/>
  <img src="screenshots/ualc3.png" width="350"/>
</div>

## 🎮 Project Overview

The **Urban Assault Level Creator** is the most comprehensive level editing tool ever developed for Urban Assault, the pioneering hybrid RTS/FPS game from 1998. Unlike the original game's level creation process that relied on manual text file editing in LDF format, this editor provides a visual, intuitive interface for designing complex battle environments with unprecedented precision and efficiency.

This professional-grade tool transforms the original tedious process that required deep technical knowledge into an accessible, visually-driven experience while maintaining complete binary compatibility with Urban Assault's level format.

### Core Urban Assault Concepts Implemented

- **Sector-Based Map System**: Complete implementation of Urban Assault's unique grid-based sector system with proper typ/own/blg/hgt map matrices and accurate visualization of height differentials between sectors
- **Faction Management**: Support for all game factions (Resistance, Ghorkovs, Taerkastens, Mykonians, Sulgogar, Black Sect) with accurate faction icons and ownership indicators
- **Host Station System**: Precise implementation of AI host station behavior parameters and energy reservoirs with faction-specific properties
- **Squad Deployment**: Comprehensive vehicle management supporting all unit types with proper tactical positioning and ownership assignment 
- **Special Building System**: Full implementation of all special game structures (Beam Gates, Stoudson Bombs, Tech Upgrades) with proper key sector relationships and activation mechanics
- **Level Parameters**: Complete configuration interface for all level-specific settings including environment set (1-6), sky selection, music tracks, and briefing/debriefing maps

## 🛠️ Technical Implementation Details

### Map Generation & Parsing

- **LDF File Format Handling**
  - Custom parser for Urban Assault's Level Definition Format (*.ldf files) with robust error detection
  - Bidirectional conversion between hexadecimal values (in LDF files) and decimal values (in editor interface)
  - Binary-compatible serialization ensuring perfect compatibility with the original game

- **Sector Data Management**
  - Accurate implementation of Urban Assault's four critical map arrays for each sector:
    - `typ_map`: Stores terrain type values (0-255) affecting sector appearance and decoration
    - `own_map`: Maintains sector ownership by faction (0-7) for territorial control
    - `blg_map`: Contains functional buildings (power stations, radar stations, flak stations)
    - `hgt_map`: Controls terrain elevation with proper height differential visualization

- **Building System**
  - Environment-specific terrain type management through typ_map values
  - Functional building implementation through blg_map with proper game mechanics
  - Environment-specific validation to prevent inappropriate buildings for each setting
  - Automatic error detection for prohibited building placements

### Game Element Implementation

- **Beam Gate System**
  - Complete implementation of level exit mechanics with proper open/closed building states
  - Target level integration using level ID system (mapping to corresponding LDF files)
  - Multiple key sector support for complex gate activation requirements
  - Visual indicators showing relationships between beam gates and their key sectors

- **Stoudson Bomb System**
  - Full implementation of bomb mechanics with inactive/active/trigger building states
  - Countdown timer configuration with proper game time units
  - Key sector relationship visualization for bomb activation conditions
  - Environment-specific validation preventing incorrect bomb building types

- **Tech Upgrade System**
  - Support for all tech upgrade types with appropriate building representations
  - Complete implementation of upgrade effects for vehicles, weapons and buildings
  - Sound effect type configuration for upgrade activation
  - Environment-specific validation ensuring appropriate upgrade buildings

### Host Station & Squad Management

- **Host Station Configuration**
  - Complete implementation of the 8 critical AI behavior parameters:
    - Conquering sectors (con): Controls sector conquering priority
    - Defense (def): Manages defensive unit and building production
    - Reconnaissance (rec): Controls units for sector reconnoissance
    - Attack (rob): Controls attack aggressiveness
    - Power building (pow): Controls power station construction priority
    - Radar building (rad): Controls radar station construction priority
    - Flak building (saf): Controls flak station construction priority
    - Moving station (cpl): Controls host station movement behavior
  - Energy reservoir management with proper game-optimized values
  - View Angle and Reload Constant parameter implementation affecting AI behavior

- **Squad Deployment**
  - Support for all vehicle types with proper faction-specific availability
  - Accurate initial positioning using Urban Assault's coordinate system
  - Full integration with Metropolis Dawn expansion units and behaviors

## 🎯 Features & User Interface

### Interactive Map Editing
- **Multi-Sector Selection**: Select and edit multiple sectors simultaneously, a capability impossible in the text editing
- **Sector Owner Painting**: Hold faction number keys (1-7) and drag to quickly assign ownership to multiple sectors
- **Height Editing**: Visually adjust terrain height with real-time display of elevation differentials
- **Error Detection**: Automatic identification of problematic sectors with visual indicators:
  - Beam Gates without target levels
  - Stoudson Bombs with incompatible buildings for the environment
  - Tech Upgrades with environment-incompatible building IDs

### Advanced Navigation
- **Dynamic Zoom**: Scale between 0.03x to 0.3x zoom with smooth camera controls
- **Panning**: Middle-mouse button navigation for efficient map traversal
- **Overview Modes**: Toggle between different map array viewer values (typ, own, blg, hgt) for technical debugging

### Property Editors
- **Building Editor**: Configure building IDs (0-255) with visual previews
- **Host Station Properties**: Full configuration of all AI parameters with energy and behavioral settings
- **Squad Configuration**: Complete control over squad placement, ownership, and vehicle type
- **Beam Gate Properties**: Configure connections with proper key sector linkage
- **Stoudson Bomb Properties**: Configure inactive/active/trigger building pairs with intuitive countdown timer
- **Tech Upgrade Properties**: Configure upgrade building IDs with visual previews, unlock units and buildings, change their energy, shield and damage

### Level Management
- **Campaign Integration**: Configure map briefings, debriefings, and victory parameters
- **Drag & Drop**: Open existing level files by simply dragging them into the editor
- **Environment Selection**: Switch between all six UA environments (City, Hills, Nacht, Ice, Desert, Myko)
- **Metropolis Dawn Support**: Full compatibility with the Metropolis Dawn expansion's extended unit types/data

## 🏃‍♂️ Getting Started

### Download
Visit the [official releases page](https://github.com/dubstabber/Urban-Assault-Level-Creator/releases) for the latest stable version.

### Creating Your First Level
1. Launch the Urban Assault Level Creator
2. Create a new level (File → New)
3. Set map dimensions and click create
4. Select your desired environment type (City, Hills, Nacht, Ice, Desert, or Myko) in Level Parameters
5. Place a Host Station by right clicking on a sector and selecting "Host Station" from the context menu
6. Add enemy Host Stations and configure their AI parameters
7. Design your map using the sector editing tools
8. Add Beam Gates, Tech Upgrades, and other special structures
9. Save your level as an LDF file (File → Save or Ctrl+S)
10. Place/save the LDF file in your Urban Assault /LEVELS/SINGLE directory

### Building From Source

```
1. Download and install Godot 4.4.1 from https://godotengine.org
2. Clone this repository or download the source code
3. Open Godot and import the project
4. Select 'Edit' to explore the source code or run the editor
5. For distribution:
   - Navigate to Project > Export...
   - Configure your target platform
   - Export the project to your desired location
```

## 🔍 Code Structure Overview

```
Urban Assault Level Creator/
├── main/                              # Main application components
│   ├── main.gd                        # Main application entry point
│   ├── nav_bar/                       # Navigation bar components
│   └── parsers/                       # LDF file format handlers
├── map/                               # Map rendering and manipulation components
│   ├── map_renderer.gd                # Map rendering engine
│   ├── input_handler.gd               # User input processing
│   ├── context_menu_builders/         # Context menu builders for map window
│   └── ua_structures/                 # Game element implementations
│       ├── host_station.gd            # Host Station implementation
│       ├── squad.gd                   # Squad implementation
│       ├── beam_gate.gd               # Beam Gate implementation
│       ├── stoudson_bomb.gd           # Stoudson Bomb implementation
│       └── tech_upgrade.gd            # Tech Upgrade implementation
├── modals/                            # UI dialog implementations
│   ├── level_parameters_window.gd     # Level configuration editor
│   ├── sector_building_window.gd      # Building selection window
│   └── player_host_station_window.gd  # Select Host Station dialog script
├── properties/                        # Property panels
│   ├── sector_properties.gd           # Sector properties panel
│   └── unit_properties.gd             # Unit properties panel
├── resources/                         # Editor asset files
│   └── ua_data.json                   # Database of Urban Assault data
└── themes/                            # UI theme components
```

## 📄 License

This project is licensed under the GPL-3.0 license. See the `LICENSE` file for details.
