extends RefCounted
## The one shared instance of the session-wide timing knobs. Execution's statics
## read and write through it, so collision, animation, preview, bots and the
## timeline cannot see different windups. The instance is process-wide on purpose:
## the title backdrop's hidden session shares it with the one being played.
static var shared := new()
var spike_windup_enabled := true
var spike_windup_seconds := 0.25
