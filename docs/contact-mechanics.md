# Contact framework and Receive response

Implemented slice: shared framework and Receive Conditioning. Set, Attack, Block
and Serve still use their existing execution rules; their future handling curves
are not advertised as working trait effects. Ball flight remains ballistic.

## Shared named stages

`scripts/contact/mechanic_registry.gd` owns the ordered stages and supported trait
effect definitions, including labels, units, applicable actions and descriptions.
The Trait Tree editor uses this registry; runtime rejects unregistered effect
lookups. Unsupported saved effects remain visible with an explanatory tooltip.

Geometry → Timing → Potency → Incoming Handling → Pressure Control → Redirection
→ Intent Transfer → Consequences.

The shared resolver records each stage under `assessment.mechanics`. Player,
court helper and Pepper events publish the same recursively immutable evidence.
Existing Platform Quality, Timing, Ball Control, Cushioning, Charge Tolerance,
Work Rate, Flow and recovery rules retain their ownership.

## Receive Conditioning

Charge matching remains strict for serves/attacks, with a gradual severity ramp.
The old incoming-velocity carry-through shank formula has been removed. Once the
contact is legal, the new response curves use the actual incoming velocity,
normalized intersection height/side/reach, charge mismatch and preparation age.
The existing intended pass supplies the controlled endpoint. Increasing mismatch
moves output toward a damped, geometry-dependent deflection rather than through
velocity unchanged. Small charge near-misses still have small errors.

The effective platform is a gameplay surface, not the outside wall of the broad
hurtbox. Low contacts absorb strongly; upper contacts retain more tangential
motion. Early preparation loses follow-through/cushioning away from the low-catch
exception. Late preparation increases placement-sensitive normal/direction error.
A short confirmation age is late preparation; an age beyond the sweet window is
early preparation. The nominal bot/preview lead remains 200 ms. Sweet windows are doubled around
their original midpoints: Receive 120–440 ms (320 ms total), and Set/Attack/Block
155–335 ms (180 ms total). Early/late response curves follow these actual bounds.

Variation is deterministic from the recorded response seed. It is bounded and
biased by contact location and incoming pace. Mirrored contacts with the same
seed mirror their response. Preview evaluation never advances an RNG.

Every actual Receive response includes surface separation and a short departure
check against a conservative athlete envelope. Balls starting within that envelope
are moved to clearance; inward trajectories are redirected to depart. A high or
sideways shank may escape around/above the athlete, but a confirmed platform touch
cannot simply continue through the body. This adds no always-on ball/body collider.
Near-floor responses cannot launch downward into the floor. When surface, body
and floor constraints conflict, the closest permitted departure is selected
without adding energy; a dead stop is allowed. Oblique and rising contacts are
covered as well as the descending drill feeds.

## Action charge versus ball charge

Receive metadata now records `action_charge` separately from resultant `charge`.
Resultant ball charge is calibrated from incoming charge, pace actually retained
and a small successful follow-through contribution. A minimum reference pace and
bounded retained fraction prevent slow/stopped balls from amplifying old metadata.
It does not multiply outgoing velocity again.

`delivery_quality` records how well conditioned the pass is, with source action,
actor, retained pressure, reference speed and response seed. This is the contract
for future Set/Attack transfer work; it does not yet impose new attack penalties
or setter trait bonuses. Other action metadata retains its existing behavior.

With contact volumes enabled (`K`), the persistent lab readout shows input charge,
resulting ball charge and delivery quality. Full receive evidence includes early/
late preparation, normalized intersection, mismatch severity, retained pace,
restitution, scatter, trait modifiers and departure correction.

## New selectable traits (provisional tuning)

- **Steady Platform:** +10% Receive Control; ACC 70, after Platform Quality.
  Reduces the uncontrolled fraction, without granting matching or sweetness.
- **Soft Platform:** +12% Receive Absorption; END 70, after Charge Tolerance.
  Damps residual impact pace, especially low contacts.
- **Guided Dig:** +12% Receive Redirection; ACC 72, after Steady Platform.
  Reduces late placement error and directional scatter.

These effects are also available for authored traits in the Trait Tree editor.
Each modifier is bounded to a combined 65% effect per mechanic; it does not replace geometry, charge matching or DI.
The existing corrective DI changes penalties before this response resolves.
Bot setter targeting and aiming happen before the response, so they cannot repair
an underpowered shank afterward. Final departure safety runs after those modifiers.

## Validation and testing in the drill

`receive_response_test` sweeps speed, intersection, preparation and charge, checking
finite bounded output and body departure. It also covers mirrored/reproducible
variation, low dead digs, trait effects, ordered immutable evidence and resultant
ball charge. `receive_charge_test` preserves strict matching and near-miss tests.
`render_receive_responses` captures low/side/high/matched contacts against the
actual Serve Receive drill feed. Existing rally, Pepper, preview, fatigue and
animation suites cover integration.

Enter the Contact Lab, walk to Serve Receive, press I, and compare deliberately
low charges at different heights with a matching input. Keep K enabled for the
readout. Scoring remains landing-based: shanks stay live, and the opposite half
scores one/two points as before. Numerical response curves and the three new
trait amounts are provisional and should be tuned from these trials.

Validation record: the full workspace run passed 76 suites, followed by eight
affected suites after the final departure-cone correction and five release checks
covering the final trace contract, receive response, charge, MoC, Flow and editor. The full run includes
concurrent bot-pad work, which is outside this change. Machine-readable results:
`checks/receive-framework.json`. Render captures are in the ignored
`artifacts/receive-final-graphics/renders/` directory.

The staged contact change was also checked independently of concurrent bot-pad
and animation edits: Receive response, charge and prototype suites all passed
from an isolated copy of the Git index (`artifacts/receive-index-proof`).
