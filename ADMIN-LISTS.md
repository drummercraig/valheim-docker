# Admin, Ban, and Permitted Lists

This Valheim server automatically syncs admin, ban, and permitted (whitelist) lists between the container and host.

## How It Works

The three list files are stored in `./userfiles/` on your host and symlinked into the container:

```
./userfiles/adminlist.txt     → /root/.config/unity3d/IronGate/Valheim/adminlist.txt
./userfiles/bannedlist.txt    → /root/.config/unity3d/IronGate/Valheim/bannedlist.txt  
./userfiles/permittedlist.txt → /root/.config/unity3d/IronGate/Valheim/permittedlist.txt
```

Changes to these files take effect **immediately** without restarting the server.

## File Format

Each file contains one Steam ID per line:

```
76561198012345678
76561198087654321
76561198123456789
```

## Managing Lists from Host

### Method 1: Using the Helper Script (Recommended)

Make the script executable:
```bash
chmod +x manage-lists.sh
```

**Show a list:**
```bash
./manage-lists.sh show admin
./manage-lists.sh show banned
./manage-lists.sh show permitted
```

**Add a Steam ID:**
```bash
./manage-lists.sh add admin 76561198012345678
./manage-lists.sh add banned 76561198087654321
./manage-lists.sh add permitted 76561198123456789
```

**Remove a Steam ID:**
```bash
./manage-lists.sh remove admin 76561198012345678
```

**Clear all entries:**
```bash
./manage-lists.sh clear banned
```

### Method 2: Direct File Editing

Edit the files directly:
```bash
nano ./userfiles/adminlist.txt
nano ./userfiles/bannedlist.txt
nano ./userfiles/permittedlist.txt
```

Or use command line:
```bash
# Add
echo "76561198012345678" >> ./userfiles/adminlist.txt

# Remove (using sed)
sed -i '/76561198012345678/d' ./userfiles/adminlist.txt

# View
cat ./userfiles/adminlist.txt
```

## Managing Lists from Inside Container

You can also manage lists from inside the container:

```bash
# Access container
docker exec -it valheim-server bash

# Edit files (they're symlinked to /userfiles/)
nano /root/.config/unity3d/IronGate/Valheim/adminlist.txt

# Or directly
nano /userfiles/adminlist.txt

# Exit
exit
```

## Finding Steam IDs

### Method 1: Steam Profile URL
1. Go to player's Steam profile
2. Look at the URL:
   - **Custom URL**: `steamcommunity.com/id/customname` 
   - **Numeric ID**: `steamcommunity.com/profiles/76561198012345678`
3. If custom URL, use [steamid.io](https://steamid.io/) to convert

### Method 2: In-Game
1. Make yourself admin first
2. Connect to server
3. Press F5 to open console
4. Type: `lodbias` (shows player list with Steam IDs)

### Method 3: Server Logs
When a player connects, their Steam ID appears in logs:
```bash
docker compose logs -f | grep "Got connection SteamID"
```

## List Types Explained

### Admin List (`adminlist.txt`)
- Grants admin privileges
- Can use console commands
- Can kick/ban players
- **Recommendation**: Only add trusted players

### Ban List (`bannedlist.txt`)
- Prevents players from connecting
- Immediate effect (kicks if currently connected)
- Use for disruptive players

### Permitted List (`permittedlist.txt`)
- Server whitelist
- Only listed Steam IDs can connect
- Leave empty to allow anyone
- **Note**: Admins should also be in this list if using whitelist

## Examples

### Set up initial admins
```bash
./manage-lists.sh add admin 76561198012345678  # Your Steam ID
./manage-lists.sh add admin 76561198087654321  # Friend's Steam ID
```

### Enable whitelist (private server)
```bash
./manage-lists.sh add permitted 76561198012345678  # You
./manage-lists.sh add permitted 76561198087654321  # Friend 1
./manage-lists.sh add permitted 76561198123456789  # Friend 2
```

### Ban a griefer
```bash
# Get their Steam ID from logs
docker compose logs | grep "Got connection" | tail -5

# Add to ban list
./manage-lists.sh add banned 76561198999999999
```

### View all lists
```bash
./manage-lists.sh show admin
./manage-lists.sh show banned
./manage-lists.sh show permitted
```

## Troubleshooting

### Changes not taking effect
1. Check file contents:
   ```bash
   cat ./userfiles/adminlist.txt
   ```

2. Verify symlink inside container:
   ```bash
   docker exec valheim-server ls -la /root/.config/unity3d/IronGate/Valheim/
   ```

3. Check sync script is running:
   ```bash
   docker exec valheim-server supervisorctl status valheim-sync
   ```

### Permission denied editing files
```bash
# Fix permissions
sudo chown $(id -u):$(id -g) ./userfiles/*.txt
chmod 644 ./userfiles/*.txt
```

### Symlink broken
The `valheim-sync` service monitors and repairs broken symlinks automatically. Check logs:
```bash
docker compose logs valheim-sync | tail -20
```

## Backup

These files are automatically backed up with your world files if backups are enabled. They're included in:
```
./userfiles/backups/worlds_backup_*.zip
```

Manual backup:
```bash
cp ./userfiles/adminlist.txt ./userfiles/adminlist.txt.backup
cp ./userfiles/bannedlist.txt ./userfiles/bannedlist.txt.backup
cp ./userfiles/permittedlist.txt ./userfiles/permittedlist.txt.backup
```

## Security Notes

- **Never share your admin list publicly**
- Keep admin list minimal (only trusted players)
- Review ban list periodically
- If using whitelist, ensure all admins are included
- Lists persist across container restarts/rebuilds