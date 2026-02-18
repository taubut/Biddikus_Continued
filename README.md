# Biddikus_Continued

A raid loot bidding and DKP management addon for World of Warcraft Classic (TBC Anniversary). Provides a real-time bidding UI for master looters and a full DKP tracking system synchronized across your raid and guild.

**Original Author:** James "Gromph" Gardiner
**Continued by:** Srumar

## Features

### Live Bidding System
- Master looters shift-click an item to load it into the bidding frame, set a minimum bid, and start the auction
- All raid members see the item, countdown timer, and bid history in real time
- Bids are validated (must meet minimum, must exceed current highest)
- Timer auto-extends by 10 seconds on each new bid to prevent sniping
- Countdown sounds and optional screen flash during the final 5 seconds
- Bid increment auto-fills the bid box for quick one-click bidding

### Second-Price +1 Bidding
An optional auction mode where the winner pays the second-highest bid + 1 instead of their full bid. If there's only one bidder, they pay the minimum. This discourages overbidding while preventing lowball strategies.

### DKP Tracking
- **Compile Raid** — Scan the current raid roster and add any new players to the standings
- **Award Raid** — Award a set amount of DKP to all raid members at once
- **Boss Kill EKP** — Award configurable per-raid EKP amounts for boss kills (e.g. 1 for Karazhan, 10 for Magtheridon)
- **First Kill Bonus** — Extra EKP bonus for a guild's first kill of a boss
- **Individual Adjustments** — Add or subtract DKP from specific players with notes
- **Auto-Deduct** — When a bid ends, the winner's DKP is automatically deducted
- **Weekly Decay** — 10% weekly decay on positive balances, with overdue warnings on login
- **Lifetime vs Current** — Lifetime DKP only goes up (tracks total earned); Current DKP reflects spendable balance

### DKP Standings
- Sortable table with columns: Rank, Player (class-colored), Class, Current DKP, Lifetime DKP
- Scrollable with alternating row backgrounds and hover highlighting

### CSV Export
- Export all DKP standings as tab-separated values for pasting directly into spreadsheets
- Copyable text frame with auto-select — just Ctrl+A, Ctrl+C
- Accessible from both the options panel and the standings window

### Loot History
- Records up to 500 loot entries with player, item, DKP paid, date, and raid
- Filterable by raid instance and date
- Sortable columns with item tooltip on hover

### Personal Transaction History
- Each player can view their own DKP transactions: awards, deductions, decays, adjustments, boss kills
- Color-coded by type (green for awards, orange for deductions, red for decay, etc.)

### Sync System
- All DKP data syncs automatically across raid and guild members via addon communication
- Version-based conflict resolution — newer data always wins
- Non-officers automatically request sync when joining a raid
- Officers can broadcast to raid or guild on demand
- Syncs standings, log, loot history, settings, and boss kill configurations

### Raid Context
Officers select the active raid instance from a dropdown (Karazhan, Gruul's Lair, Magtheridon, SSC, TK, Black Temple, Sunwell Plateau). This tags all loot history and log entries and determines boss kill EKP values.

### Officer Permissions
Officer status is determined automatically by guild rank — Guild Master and the first officer rank have DKP management permissions. No manual officer list to maintain.

### Automatic Loot Posting
When the master looter opens a loot window, items at or above the configured quality threshold (default: Epic) are automatically posted to raid chat.

## Installation

1. Download or clone this repository
2. Place the `Biddikus_Continued` folder into your `Interface/AddOns/` directory
3. Restart WoW or `/reload` your UI

## Usage

Type `/biddikus` to open the configuration panel, or right-click the Biddikus frame header for quick access to standings, loot history, transactions, and settings.

### For Officers
1. Select a raid context from the dropdown in the frame footer
2. **Compile Raid** to add all current raid members to DKP standings
3. Shift-click items to load them, set a minimum bid, and click **Start**
4. Use **Boss Kill** and **First Kill** buttons after downing bosses
5. **Broadcast DKP** to sync data to the raid after changes

### For Raiders
1. When a bid starts, enter your bid amount and click **Bid**
2. View your DKP balance in the frame header
3. Open **DKP Standings** or **My Transactions** from the right-click menu
4. Use **Request Sync** if your data seems out of date

## Configuration

| Setting | Default | Description |
|---|---|---|
| Bid Timeout | 30s | Countdown duration for each auction (15-180s) |
| Minimum Bid | 1 | Default minimum bid amount |
| Bid Increment | 5 | Auto-increment added to bid box |
| Item Quality | Epic | Minimum quality for auto-posting loot |
| Second-Price +1 | Off | Winner pays 2nd highest bid + 1 |
| Starting DKP | 0 | DKP given to newly compiled players |
| First Kill Bonus | 5 | Extra EKP for first boss kills |
| Screen Flash | Off | Flash screen during final countdown |
| Auto Hide | Off | Hide frame when no bid is active |

Boss kill EKP is configurable per raid instance in the DKP settings.

## Libraries

Biddikus_Continued bundles the following Ace3 libraries:
- AceAddon, AceComm, AceConsole, AceConfig, AceDB, AceDBOptions
- AceEvent, AceGUI, AceHook, AceSerializer, AceTimer
- LibSharedMedia-3.0, LibStub, CallbackHandler

## License

This addon is a continuation of the original Biddikus by James "Gromph" Gardiner.
