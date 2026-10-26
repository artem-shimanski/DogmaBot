# DogmaBot

A Discord bot that calculates EVE Online fits. Paste a fit in EFT, DNA or in-game XML format and get its
damage, tank, capacitor, navigation, targeting and fitting resources, calculated by the
[DogmaKit](https://github.com/artem-shimanski/DogmaKit) engine with all skills at level V.

## Commands

| Command | What it does |
|---|---|
| `/fit` | Opens a form to paste a fit and replies with its stats. |
| `/compare` | Opens a form to paste two fits and replies with their stats side by side. |
| **Apps → Analyze fit** (message context menu) | Calculates the fit contained in the selected message. |

The bot needs no privileged intents: message text reaches it only through the context menu command the user
invokes. It can be installed to a server or to a user account; in the latter case the commands work in any chat.

## Requirements

* Swift 6.4.
* macOS 26+ or Linux.

## Running

1. Create an application in the [Discord Developer Portal](https://discord.com/developers/applications) and copy
   the bot token. For the install link, enable the `applications.commands` and `bot` scopes.
2. Run the bot:

   ```
   DISCORD_TOKEN=<token> swift run -c release DogmaBot
   ```

| Variable | |
|---|---|
| `DISCORD_TOKEN` | Bot token. Required. |
| `DISCORD_GUILD_ID` | Registers the commands on this server only. Server commands update instantly, which is convenient during development; without the variable the commands are registered globally. |
| `DOGMA_WEB_URL` | Address of the fit page (see below). When set, fit cards link to it. |

## Fit page

`Web/` holds a page that runs the same calculation in the browser: `FitAnalysis` and DogmaKit compiled to
WebAssembly. The fit travels in the URL fragment (`#eft=<base64url of the EFT text>`), which browsers do not send
to the server, so any static hosting works. `Web/serve.py` serves the directory locally, sending pre-compressed
files when the browser accepts gzip.

```
Scripts/build-web.sh        # builds Web/build; needs swiftly with the Swift toolchain and its Wasm SDK
python3 Web/serve.py 8080
```

## Command-line tool

`dogma-cli` prints the same stats in the terminal, which is handy for checking the calculation without Discord:

```
swift run dogma-cli fit.txt
pbpaste | swift run dogma-cli --json
```

## Package layout

| Target | Purpose |
|---|---|
| `FitAnalysis` | Library: fit text in, `Codable` stat summaries out. Independent of Discord. |
| `dogma-cli` | Command-line front end for `FitAnalysis`. |
| `DogmaBot` | The Discord bot, built on [DiscordBM](https://github.com/DiscordBM/DiscordBM). |

Tests: `swift test`.
