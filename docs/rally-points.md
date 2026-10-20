# Rally point attribution

`rally_rules.gd` attributes a point without introducing match scores or serving turns. Home is the positive-Z side, Away the negative-Z side, relative to the active net. Contact events track the touching athlete's team, including blocks; debug feeds begin as Away serves.

An in-bounds floor landing awards the opposite side. Boundary lines count as in, including the visual ball radius. Out balls and obstacle strikes award the opponent of the last toucher. A block touch therefore changes who loses an eventual out ball. Net, serve-block, under-net, outside-antenna and fourth-contact faults award the opponent of the offending side. Net tape/webbing contact alone remains playable.

The rally-end message includes HOME POINT or AWAY POINT. `rally_rules.last_result` exposes winner, loser, reason and last-touch side for a future scoreboard. Manual stops, resets, drills and Pepper do not award rally points.

Consecutive contacts by the same athlete are permitted; the team still has three ordinary contacts. Blocks do not count against those three. There are no back-row/attack-line restrictions. Serving rotation remains deferred: create one serving order per side when the rally starts; athletes entering later append to their side's order. Match progression and service-order enforcement are not introduced by point attribution.
