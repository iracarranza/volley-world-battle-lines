> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# Laning, Nets and objectives: accepted rules

Design record, from the conversation of 2026-10-18. It extends `docs/map-spec.md`. Status: **accepted by the designer unless marked
"reading"** (my interpretation, to confirm) or "open". Nothing here is implemented in the Contact Lab yet. Winded / Exhausted is being
implemented separately.

## 1. Lane identity comes from the Net

| Lane | Net height | Net width (court) | Favours |
|---|---|---|---|
| Top | tallest | narrowest | height and power duels, blocking; easy to cover |
| Middle | between | between | balanced, blocking and transition |
| Bottom | shortest | widest | easy to attack over, hard to cover; control and coverage |

- Each Net's dimensions start at its lane values and move toward the **Pit Net standard** as players join. A team has only 5 members, so
  the standard is reached at **5 per side**; the earlier "up to 6 per side" is dropped as unnecessary.
- Dimensions change **only when a player joins a Rally**, and a player joins only when the ball enters their side of the court. The playing
  area follows the highest count on either side and does not shrink during a Rally (handoff rule).
- Consequence: lane differences matter most in small fights, and numbers erase them.

## 2. What laners do

Move, do and contest Drills and Energy Drinks, Pepper opposing laners, and start Rallies at the Net. A Rally can start with no opposing
players present; then the serving team just earns the Point.

## 3. Serve cost

- A strong Serve costs a non-negligible amount of HP. A weak, slow Serve costs very little.
- There is **no** "server ends at minimum HP" rule. A cheap low-charge Serve on an open Net is free, so the Point it earns is the cost.
- Confirmed: a weak Serve is slow, which gives defenders time to reach the court. Serve speed, defender reaction time and HP cost are the
  same dial.

## 4. HP after a Rally, trading and ganks

- After a Rally ends, every participant's HP drops to their current HP Minimum (levels and Traits raise it).
- So a trade leaves both players at minimum, and a lone player who Serves greedily on an open Net is exposed to a gank.
- A multi-player Pepper lets players pass to an ally. In a 2v1 with good play the lone player is always spiked at.
- Losing a Pepper transfers HP to the winner. The loss is capped by what the loser has above their floor; **the shortfall becomes
  Exhaustion**.

## 5. Winded, Exhausted and Benching

- **Winded**: at 0 STA. Slows STA regeneration for **10.5 s**.
- Reaching 0 STA while Winded makes the player **Exhausted**. STA regeneration is paused at 0 for **7 s**, after which the player is
  Winded again.
- One status: the HP shortfall from a lost Pepper also causes Exhausted. If a player is already Exhausted at the end of a Pepper, the
  status refreshes.
- An Exhausted player is **Benched** when they are *forced into* a Pepper or a Rally:
  - **Pepper:** by being struck by a Pepper.
  - **Rally:** by being inside their team's section of a Net when a valid Serve enters that Net's area.
  Nothing happens when the Pepper or Serve is merely initiated, so an Exhausted player can still dodge the Pepper or leave the Net's
  section during the 7 s.
- A Benched player returns to their base and cannot play for a time that rises with level. **Provisional: 5 s at level 1, plus 4/3 s per
  level.** That is about 10 s at level 5, 17 s at level 10, 23.7 s at level 15 and 30.3 s at level 20 (the level cap).
- Benching gives the benching players XP, **most of it to the player who Served** (reading: the player who initiated).
- A lost Pepper: the winners steal some HP from the losers and gain some XP. If the losers have no HP above their floor the winners gain
  only XP, and the loser's shortfall still becomes Exhaustion.

## 6. Points, sets and Nets falling

**Sets.** Win by two applies at every Net in every set. Points reset when a set ends. A set's size and the wins needed depend on the Net:

| Net | To fall | Rewarded with (global AP to **each** member of the winning team) |
|---|---|---|
| Primary (one per lane) | 2 set wins of 15 (best of 3) | 2 |
| Secondary (one per lane, closer to the losing base) | 1 set win of 21 | 3 |
| Tertiary | 3 set wins of 21 at first. Each *additional* secondary that falls (the first one is what exposes it) lowers it by one, to 2 and then 1 | 4 |
| Coach | not yet designed | not yet designed |

**Who can make a Net fall.**
- At the **primary** Net either side can win sets. Whoever wins pushes the fight toward the loser's base.
- From the secondary Net on, **only the attacking team can make a Net fall**. If the defenders win a set it has no effect: the Net is not
  replaced and no attacker win is removed. The only way a successor Net falls is the attackers winning the required sets there.
- The tertiary Net and the Coach that become exposed belong to the team that lost the secondary. A falling Net favours the winner with more
  access to the map, Drills and central routes.

**Rewards.**
- **Global AP:** every member of the winning team gets the Net's value, so 10, 15 or 20 AP across the five players.
- **Local AP:** the allied players *nearby for the fall* share **double the Net's value**, split evenly and rounded down. The first Net of the
  match to fall adds **2** to that pool.

| Net | Global (each) | Local pool | With 1 / 2 / 3 / 4 / 5 players nearby (each) |
|---|---|---|---|
| Primary | 2 | 4 | 4 / 2 / 1 / 1 / 0 |
| First Net to fall (a Primary) | 2 | 6 | 6 / 3 / 2 / 1 / 1 |
| Secondary | 3 | 6 | 6 / 3 / 2 / 1 / 1 |
| Tertiary | 4 | 8 | 8 / 4 / 2 / 2 / 1 |

- **XP per Point** goes only to the players in the Rally who scored it, split **unevenly between the server and the other players**.
  The split ratio is open.

**The Coach.** Nothing designed yet beyond the earlier description: a stationary NPC exposed once the tertiary Net falls, struck by Serves
and Attacks until the Whistle ends the match.

## 7. Confirmed readings, and what is still open

Confirmed:
1. A weak Serve is slow, so it is cheap and contestable (section 3).
2. The pushing rules stack on purpose.
3. A lost secondary or tertiary Net cannot be won back by the defenders (section 6). The primary Net is the only two-way fight.
4. Set counts are wins needed. The primary Net is 2 set wins. A primary Net needs at least 30 points and a tertiary Net can need up to
   63 plus any win-by-two extensions.
5. Benching happens on forced entry, not on initiation (section 5).

Open:
- What counts as "nearby for the fall": inside the Net's court area when the deciding point lands, or within some distance?
- The server's share of per-point XP, and the benching XP split, since "most to the Server" needs a number.
- Coach: everything (hit points, minimum power that counts, regeneration, where Serves at it are taken from).
- Whether the first-Net AP bonus is for the first Net to fall in the match, as written, or the first for each team.
- Should the primary Net's winner always become the attacker for that lane's later Nets? (Implied by section 6.)
