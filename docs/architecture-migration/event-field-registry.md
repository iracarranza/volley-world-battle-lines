# Event field registry

Migration stage MS-01 (documents) and MS-04 (schema and order). Companion to the Behavioural Divergence Register. This file documents the published contact event. It changes no field, no value and no name.

## `event.charge` has two senses (BDR-15, FC-22)

| Sense (documented name, not a code name) | Who sets it | Where |
|---|---|---|
| `input_charge`: the effort the actor chose (player: `locked_charge`) | the player's contact | `contact_lab.gd` `_emit_contact_impact` overwrites `event.charge = locked_charge` |
| `delivered_pressure`: the pressure the ball carries (`ball_shot.charge`) | bots, Pepper, Serve | `contact_lab.gd` `_impact_event` default |

No field is renamed. A rename or an additive `input_charge` / `delivered_pressure` field is allowed only after the reader audit in `event-schema.md` section 4 shows consumers unaffected, and then as its own commit.

Registry changes for fields with documented drift (SADR-25) are limited to this entry; the schema of every other field is recorded in `event-schema.md`.
