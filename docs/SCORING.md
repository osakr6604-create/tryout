# How Tryout scores a run

This page is written by `dev/scoring_doc.gd` from the numbers in `core/tuning.gd` and `core/rating.gd`. CI fails if it falls out of step with the game, so what you read here is what the game does.

Each of the eight drills gives 0 to 100. The total is the sum times 12.5, so a run scores 0 to 10,000. "From A to B" below means a straight line: A scores 0, B scores 100, and anything past either end is capped.

## The drills

| Drill | Length | Score |
| --- | --- | --- |
| Flick | 6 s | Hits from 2 to 14, times (0.55 + 0.45 x accuracy). Targets are 88 px across. |
| Track | 6 s | Share of time on target from 12% to 93%. The first 0.55 s do not count. The target speeds up from 380 to 660 px a second. |
| React | 3 trials | Each trial from 430 ms to 165 ms; the drill is the average. An early click or no click within 0.9 s scores 0 for that trial. |
| Hold fire | 8 shapes | Enemies hit out of 5, times (70 + 30 x speed), where speed runs from 0.64 s to 0.34 s average. Minus 30 for each teammate shot and 3 for each click on nothing. |
| Last hit | 6.2 s | Last hits out of 7, as a percentage, minus 4 for each early click. The bar is gold under 20% health. |
| Skillshot | 6.2 s | Runners hit out of 4, times (88 + 12 x hits per shot). Shots travel 1900 px a second. |
| Map check | 6.6 s | Pings found out of 6, times (70 + 30 x speed), where speed runs from 4.4 s to 1.9 s of recall. |
| Clutch | 4 opponents, 5 bullets | 80 x share downed x (0.8 + 0.2 x speed), where speed runs from 0.64 s to 0.32 s per opponent, plus 20 for all 4. |

## Grades

| Grade | Total at least |
| --- | --- |
| S+ | 9,000 |
| S | 8,000 |
| A | 6,800 |
| B | 5,400 |
| C | 3,800 |
| D | 0 |

The two digit overall on the card is the total divided by 100.

## Attributes and roles

Each attribute is a weighted average of drill scores, shown as 0 to 99.

| Attribute | Made from | Role when it is the strongest |
| --- | --- | --- |
| Reflex | React 75%, Clutch 25% | Entry |
| Precision | Flick 70%, Clutch 30% | Marksman |
| Tracking | Track 80%, Skillshot 20% | Rifler |
| Timing | Last hit 65%, Skillshot 35% | Playmaker |
| Discipline | Hold fire 100% | Anchor |
| Awareness | Map check 75%, Last hit 25% | Shotcaller |

Each early click in the reaction drill also takes 12 off Discipline. When all six attributes are within 10 points of each other the role is Flex.

## Fairness

- Everyone plays the same eight drills in the same order, for the same lengths.
- Layouts and delays come from a fresh seed each run, so watching the player ahead of you does not help. Within a run the hard parts are balanced: flick distances come from a shuffled set, reaction delays are the same three in a new order.
- A tie keeps the earlier run ahead. A score has to be beaten, not matched.
- Reaction times are measured from the frame the target is drawn to the frame the click arrives, so they include the screen's and the mouse's own delay. They are fair between players on the same station and are not lab measurements.
- The balance was tuned against a simulated player at six skill levels (`dev/balance.gd`). It has not been tuned on a crowd yet.
