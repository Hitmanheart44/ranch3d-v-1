# Version Negative: bug report

Bugs found while playtesting version negative, one per entry. "Origin" is where it happens; "Trigger" is how to make it happen. Where the owner has not yet given a detail, the entry says so.

## B1. Entrance camera is wrong at the start of a new game

- **Origin:** the version negative build, in the new-game flow: title screen, New Game, then the ranch entrance (`world/flow/title.gd` starts the game, `world/zones/ranch_v2.gd` places the trainer and camera).
- **Trigger:** with a save already in place, choose **NEW GAME** on the title screen, confirm **YES, START A NEW RANCH**, and play on to the ranch. The camera at the entrance is wrong (broken framing). The owner reproduced it this way.
- **Not yet known:** exactly how the camera looks when it is wrong, and whether it also happens when no save exists. A headless run that skipped the title could not reproduce it, so it needs a run through the real title screen.
- **Note:** this is the camera at the entrance of the ranch, not necessarily an opening scene.

## B2. An adventure ended abruptly

- **Origin:** the version negative build, during an adventure (the mountain trail and its cave rooms).
- **Trigger:** not yet recorded. It happened during a normal playthrough and the adventure ended with no clear reason. No error was logged.
- **Not yet known:** which adventure room it was, what the owner was doing, and what screen appeared when it ended.
