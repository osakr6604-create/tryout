# Running Tryout at a booth

Everything a booth crew needs, in the order they will need it.

## What you need

- A Windows 10 or 11 PC or laptop. Anything that can play a video will do; the game draws simple shapes.
- A mouse and a mouse mat. A touch screen should work too, because taps arrive as clicks, but it has not been tried on touch hardware yet.
- Optional: a second screen facing the crowd for the leaderboard.
- No internet. Nothing in the game talks to a network.

## Start it

1. Copy the `windows` folder anywhere on the PC.
2. Double-click `Tryout.exe`. It opens full screen on the attract screen.
3. If a second screen is plugged in, the leaderboard opens on it by itself. If it does not, press F1 and pick the screen under "Leaderboard window".

Windows may warn about an unknown publisher the first time, because the build is not code signed. Choose "More info", then "Run anyway".

## What players do

Click to start, follow the word on screen, type a tag at the end. A turn takes about a minute and a half: roughly a minute of play, then the tag and the scouting report. One station gets through about 35 to 40 players an hour.

The game looks after itself between players:

- The report returns to the attract screen after 25 seconds (you can change this).
- The tag screen saves on its own after 20 seconds, with a neutral tag such as `ROOKIE-417` if nothing was typed.
- A run with no mouse movement for 12 seconds is dropped and nothing is saved.
- Tags are limited to letters, digits, dash and underscore, 10 characters, and pass a word filter before they reach the big screen.

## The booth menu

Press **F1** or **Esc**. Opening the menu ends any run in progress, so use it between players.

| Button | What it does |
| --- | --- |
| Sound, Music | Steps through volume levels. |
| Full screen | Switches between full screen and a window. F11 does the same. |
| Leaderboard window | Auto (second screen when there is one), off, or a screen you pick. |
| Low latency mode | Turns V-Sync off and raises the frame cap. Reaction times read a few milliseconds tighter on a fast monitor. |
| Export scores to a spreadsheet | Writes every score to a CSV file and shows where it went. |
| Clear today's board | Removes today's scores. Needs a second click. |
| Clear every score | Empties the board. Needs a second click. |
| Quit | Closes the game. Hidden when `kiosk=true`. |

## Settings without the menu

Copy `booth.example.cfg` to `booth.cfg` next to `Tryout.exe` and edit it in Notepad. You can set the event name and logo shown on screen, the lead colour, how long the report stays up, whether the QR code is shown and where it points, and kiosk mode. The file explains each line.

## The leaderboard

- "Today" is the PC's local calendar day. The crowd screen swaps between today and all-time when both have scores.
- Ties keep the earlier run ahead, so a score has to be beaten, not matched.
- Scores live in one small file in the user folder: `%APPDATA%\Tryout\leaderboard.json`. A copy of the previous save sits beside it as `leaderboard.json.bak`. To move a board to another PC, copy that file.
- If the file is ever unreadable, the game sets it aside under a new name and starts an empty board instead of failing.

## The QR code

The report shows a QR code. A player scans it with their phone and gets their own scouting card on a web page they can keep and share. The booth PC needs no connection for this: the whole card travels inside the link, and the page draws it on the phone. Nothing about the player is stored on a server.

To use your own page, set `card_url` in `booth.cfg`. To hide the code, set `show_qr=false`.

## For a long day

- Turn off sleep and screen saver in Windows power settings.
- Turn on Do Not Disturb so notifications stay off the screen.
- Plug the laptop in.
- The game cannot block Alt+Tab or the Windows key. For a station nobody is watching, use Windows assigned access (kiosk mode) with Tryout as the app.
- At the end of the day, use "Export scores to a spreadsheet" if you run a prize draw.

## Trying it before the event

Start the game with a filled board to see how it looks on your screens:

```
Tryout.exe -- --demo-board=14
```

The scores are real runs played by the built-in demo player. Clear them from the booth menu before the doors open.

## What is stored

Only the tag a player types, their score and the time. No names, no email, no photos.
