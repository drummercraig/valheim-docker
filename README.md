# Valheim Dedicated Server with Docker

Complete Docker setup for running a Valheim dedicated server with full environment variable configuration, including all world modifiers and game settings.

## Features

- ✅ Full environment variable configuration via `.env` file
- ✅ All Valheim world modifiers and presets
- ✅ Automatic server updates
- ✅ Automatic world backups
- ✅ Persistent world storage
- ✅ Crossplay support
- ✅ Safe shutdown with world save verification
- ✅ Multiple deployment options (docker-compose or docker run)

## Quick Start

### Option 1: Using Docker Compose (Recommended)

1. **Clone/download all files** to a directory

2. **Create your `.env` file** (copy and customize the provided `.env` template)

3. **Build the image:**
   ```bash
   docker compose build
   ```

4. **Start the server:**
   ```bash
   docker compose up -d
   ```

5. **View logs:**
   ```bash
   docker compose logs -f valheim-server
   ```

### Option 2: Using Docker Run Script

If you only have the Docker image and no docker-compose:

1. **Pull or build the image:**
   ```bash
   # If image is available on a registry:
   docker pull your-registry/valheim-server:latest
   
   # OR build it locally:
   docker build -t valheim-server:latest .
   ```

2. **Create your `.env` file** in your working directory

3. **Make the run script executable:**
   ```bash
   chmod +x run-valheim-server.sh
   ```

4. **Run the script:**
   ```bash
   ./run-valheim-server.sh
   ```

## Configuration

All configuration is done through the `.env` file. See the example `.env` file for all available options.

### Basic Settings

```bash
SERVER_NAME=My Valheim Server
WORLD_NAME=Dedicated
SERVER_PASS=secret123
SERVER_PUBLIC=true
SERVER_PORT=2456
```

### Crossplay Support

Enable crossplay to allow Steam and Xbox Game Pass players to join:

```bash
CROSSPLAY=true
```

### World Generation

Control your world's seed and size:

```bash
# Set a specific seed for reproducible worlds (leave empty for random)
WORLD_SEED=mysecretworld123

# Set world size in km radius (default: random 9000-10500)
# Recommended range: 100-20000
WORLD_SIZE=10000
```

**Note**: World seed and size can only be set when creating a NEW world. They have no effect on existing worlds.

### Installing Mods from Thunderstore

1. **Create a modlinks.txt file** in your project directory with mod download URLs:
   ```
   https://thunderstore.io/package/download/JereKuusela/Server_devcommands/1.102.0/
   https://thunderstore.io/package/download/ValheimModding/Jotunn/2.20.2/
   ```

2. **Make the install script executable:**
   ```bash
   chmod +x install-mods.sh
   ```

3. **Run the mod installer:**
   ```bash
   ./install-mods.sh
   ```

4. **Enable BepInEx in your .env file:**
   ```bash
   BEPINEX_ENABLED=true
   ```

5. **Restart the server:**
   ```bash
   docker compose restart valheim-server
   ```

The script will automatically:
- Download each mod from Thunderstore
- Extract and organize files into the correct BepInEx directories
- Handle various mod package structures
- Copy DLL files to plugins, configs to config, patchers to patchers

**To find mod URLs:**
1. Go to [Thunderstore Valheim](https://thunderstore.io/c/valheim/)
2. Find your desired mod
3. Click "Manual Download" button
4. Copy the download URL

### World Modifiers

#### Using Presets

Choose one preset that configures multiple settings at once:

```bash
PRESET=casual  # Options: normal, casual, easy, hard, hardcore, immersive, hammer
```

#### Individual Modifiers

Or set individual modifiers (these override preset values):

```bash
MODIFIER_COMBAT=easy           # veryeasy, easy, hard, veryhard
MODIFIER_DEATHPENALTY=casual   # casual, veryeasy, easy, hard, hardcore
MODIFIER_RESOURCES=more        # muchless, less, more, muchmore, most
MODIFIER_RAIDS=less            # none, muchless, less, more, muchmore
MODIFIER_PORTALS=casual        # casual, hard, veryhard
```

#### Special Game Modifiers

```bash
SETKEY_NOBUILDCOST=true      # No building material cost
SETKEY_PLAYEREVENTS=true     # Individual player raid progression
SETKEY_PASSIVEMOBS=true      # Enemies won't attack unless provoked
SETKEY_NOMAP=true            # Disable map/minimap
NOPORTALS=true               # Disable all portals
```

### Network Ports

```bash
GAME_PORT=2456      # Main game port (UDP)
QUERY_PORT=2457     # Query port (UDP)
CROSSPLAY_PORT=2458 # Crossplay port (UDP)
```

### Crossplay Support

To enable crossplay:

```bash
CROSSPLAY=true
```

**Note**: This is now a dedicated variable instead of being in SERVER_ARGS.

### Backup Configuration

```bash
BACKUPS_ENABLED=true
BACKUPS_INTERVAL=3600        # Backup every hour (in seconds)
BACKUPS_DIRECTORY=/userfiles/backups
BACKUPS_MAX_AGE=3            # Keep backups for 3 days
```

## Management Commands

### Using Docker Compose

```bash
# View logs
docker compose logs -f valheim-server

# Stop server safely
./safe-stop.sh

# Force a world save
docker exec valheim-server /usr/local/bin/force-save

# Check world save status
docker exec valheim-server /usr/local/bin/check-world-status

# Debug world files
docker exec valheim-server /usr/local/bin/debug-worlds

# Restart server
docker compose restart valheim-server

# Stop server
docker compose stop

# Start server
docker compose start
```

### Using Docker Run

```bash
# View logs
docker logs -f valheim-server

# Force a world save
docker exec valheim-server /usr/local/bin/force-save

# Check world save status
docker exec valheim-server /usr/local/bin/check-world-status

# Debug world files
docker exec valheim-server /usr/local/bin/debug-worlds

# Stop server
docker stop valheim-server

# Start server
docker start valheim-server

# Remove container
docker rm -f valheim-server
```

## Safe Shutdown

Always use safe shutdown procedures to ensure world saves:

```bash
# Check if it's safe to stop
docker exec valheim-server /usr/local/bin/check-world-status

# Force a save before stopping
docker exec valheim-server /usr/local/bin/force-save

# Use the safe-stop script (for docker-compose)
./safe-stop.sh

# Or force save first
./safe-stop.sh --force-save
```

## Understanding World Saves

Valheim saves worlds in two ways:
1. **Automatic saves**: Every 20 minutes while server is running
2. **Shutdown saves**: When server receives SIGTERM (graceful shutdown)

The server includes tools to verify saves:
- `check-world-status` - Check when world was last saved
- `force-save` - Trigger an immediate save by restarting
- `pre-stop-hook` - Automatically verifies save during shutdown

## Ports

The server requires these UDP ports to be open:

- **2456** - Game port (configurable)
- **2457** - Query port (game port + 1)
- **2458** - Crossplay port (game port + 2)

## File Structure

```
.
├── .env                        # Your configuration
├── docker-compose.yml          # Docker Compose configuration
├── Dockerfile                  # Container build file
├── run-valheim-server.sh       # Docker run script
├── safe-stop.sh                # Safe shutdown script
├── install-mods.sh             # Thunderstore mod installer
├── modlinks.txt                # Mod download URLs (create this)
├── valheim-server.sh           # Main server script
├── valheim-updater.sh          # Auto-update script
├── valheim-backup.sh           # Backup script
├── valheim-sync.sh             # World file sync script
├── debug-worlds.sh             # Debug script
├── force-save.sh               # Force save script
├── pre-stop-hook.sh            # Pre-stop verification
├── check-world-status.sh       # Status check script
├── supervisord.conf            # Supervisor configuration
├── userfiles/                  # Persistent data (auto-created)
│   ├── worlds_local/           # World saves
│   ├── backups/                # World backups
│   └── bepinex/                # BepInEx mod files
│       ├── plugins/            # Mod plugins
│       ├── patchers/           # Mod patchers
│       └── config/             # Mod configs
└── serverfiles/                # Server installation (auto-created)
```

## Troubleshooting

### World not saving

```bash
# Check save status
docker exec valheim-server /usr/local/bin/check-world-status

# Force a save
docker exec valheim-server /usr/local/bin/force-save

# Debug world file locations
docker exec valheim-server /usr/local/bin/debug-worlds
```

### Server not starting

```bash
# Check logs
docker logs valheim-server

# Or with docker-compose
docker compose logs valheim-server
```

### Port conflicts

If ports are already in use, change them in `.env`:

```bash
GAME_PORT=2466
QUERY_PORT=2467
CROSSPLAY_PORT=2468
```

### Check server status

```bash
# See if container is running
docker ps | grep valheim

# Check resource usage
docker stats valheim-server
```

## World Modifier Examples

### Easy Mode (Casual)

```bash
PRESET=casual
```

### Hard Mode

```bash
PRESET=hard
```

### Custom: Easy Combat, More Resources, No Raids

```bash
PRESET=""
MODIFIER_COMBAT=easy
MODIFIER_RESOURCES=more
MODIFIER_RAIDS=none
```

### Creative Mode (No Build Cost)

```bash
SETKEY_NOBUILDCOST=true
SETKEY_PASSIVEMOBS=true
```

### Hardcore Survival

```bash
PRESET=hardcore
```

### Starting a New World with Specific Seed and Size

```bash
WORLD_NAME=MyNewWorld
WORLD_SEED=VikingAdventure2024
WORLD_SIZE=15000
CROSSPLAY=true
```

**Important**: Seed and size only work when creating a NEW world. To use these settings:
1. Change `WORLD_NAME` to something new
2. Set `WORLD_SEED` and `WORLD_SIZE`
3. Start the server - it will generate a new world with these settings

## Performance Tuning

Adjust memory limits in `.env`:

```bash
MEMORY_LIMIT=8G          # Maximum memory
MEMORY_RESERVATION=4G    # Minimum reserved memory
```

## Support

For issues with the Valheim server itself, consult the [official Valheim documentation](https://valheim.fandom.com/wiki/Valheim_Wiki).

For Docker-specific issues, check the container logs and ensure your `.env` file is properly configured.