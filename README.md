# DogmaBot

A Discord bot that calculates EVE Online fits. Paste a fit in EFT, DNA or in-game XML format and get its
damage, tank, capacitor, navigation, targeting and fitting resources, calculated by the
[DogmaKit](https://github.com/artem-shimanski/DogmaKit) engine with all skills at level V.

[![Add to Discord](https://img.shields.io/badge/Add_to-Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.com/oauth2/authorize?client_id=1564010332286885978)

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
   DISCORD_TOKEN=<token> DOGMA_WEB_URL=<fit page address> swift run -c release DogmaBot
   ```

| Variable | |
|---|---|
| `DISCORD_TOKEN` | Bot token. Required. |
| `DISCORD_GUILD_ID` | Registers the commands on this server only. Server commands update instantly, which is convenient during development; without the variable the commands are registered globally. |
| `DOGMA_WEB_URL` | Address of the fit page (see below). Required: `/fit` and `/compare` cards link to each fit on the page instead of printing it. |

## Deploying

Every push to `main` runs the tests on Linux and publishes the bot's image to GitHub Container Registry as
`ghcr.io/artem-shimanski/dogmabot` (tags `latest` and `sha-<commit>`, `linux/amd64`). A platform that runs Docker
images (Railway, Render, Koyeb, DigitalOcean App Platform and the like) pulls it ready-made, so it does not compile
anything:

1. Create a service from the image `ghcr.io/artem-shimanski/dogmabot:latest`.
2. Choose a background worker if the platform asks: the bot keeps a connection to Discord and serves no HTTP, so
   it needs neither a port nor a public address.
3. Set `DISCORD_TOKEN` and `DOGMA_WEB_URL` (the fit page, `https://artem-shimanski.github.io/DogmaBot/`).

One instance is enough, and only one should run: each running copy would answer every command.

To redeploy on every push, put the platform's deploy hook URL into the repository secret `DEPLOY_HOOK_URL`; the
workflow calls it once the new image is published. To go back to an earlier version, deploy its `sha-<commit>` tag.

On a server of your own:

```
docker run -d --restart unless-stopped --name dogmabot \
    -e DISCORD_TOKEN=<token> -e DOGMA_WEB_URL=https://artem-shimanski.github.io/DogmaBot/ \
    ghcr.io/artem-shimanski/dogmabot:latest
```

and to update it, pull the new image and start the container again:

```
docker pull ghcr.io/artem-shimanski/dogmabot:latest
docker rm -f dogmabot
```

followed by the same `docker run`. A platform that builds from the repository instead finds the `Dockerfile`;
`docker build -t dogmabot .` builds the same image locally.

## Fit page

`Web/` holds a page that runs the same calculation in the browser: `FitAnalysis` and DogmaKit compiled to
WebAssembly. The fit travels in the URL fragment (`#eft=<base64url of the fit text>` in EFT, DNA or in-game XML, or
`#dna=<DNA string>`), which browsers do not send to the server, so any static hosting works. The page shows what the fit carries rack by rack and its full stats:
tank against a chosen damage pattern, repair, damage by source, capacitor, navigation, targeting, resources and cost at
CCP's average prices (fetched from ESI). On a wide screen the fit and the stats sit side by side; on a phone they
are two tabs. Both layouts have buttons that copy the fit in EFT and as a DNA link for the game's chat; DNA has no room for implants and
boosters. `Web/serve.py` serves the directory locally, sending pre-compressed
files when the browser accepts gzip.

```
Scripts/build-web.sh        # builds Web/build; needs the Swift 6.4.1 toolchain (via swiftly or in PATH) and its Wasm SDK
python3 Web/serve.py 8080
```

`.github/workflows/pages.yml` builds the page on every push to `main` and publishes it on GitHub Pages; enable Pages
in the repository settings with "GitHub Actions" as the source. The published address is the `DOGMA_WEB_URL` for
the bot.

## Command-line tool

`dogma-cli` prints the same stats in the terminal, which is handy for checking the calculation without Discord:

```
swift run dogma-cli fit.txt
pbpaste | swift run dogma-cli --json
swift run dogma-cli --sheet fit.txt   # full sheet as JSON, what the fit page reads
```

## Package layout

| Target | Purpose |
|---|---|
| `FitAnalysis` | Library: fit text in, `Codable` stat summaries out. Independent of Discord. |
| `dogma-cli` | Command-line front end for `FitAnalysis`. |
| `DogmaBot` | The Discord bot, built on [DiscordBM](https://github.com/DiscordBM/DiscordBM). |

Tests: `swift test`.
