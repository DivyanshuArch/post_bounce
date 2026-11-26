class_name PhysicsConstants
extends RefCounted

## Physics constants matching the original HTML5 simulation.

const BALL_RADIUS: float = 11.0
const MAX_PULL: float = 170.0
const MIN_PULL: float = 12.0
const MAX_LAUNCH_SPEED: float = 980.0
const MIN_LAUNCH_SPEED: float = 140.0
const RESTITUTION: float = 0.85       ## Crisp energy retention per bounce
const DAMPING: float = 1.05           ## Smooth exponential rolling drag
const LINEAR_DRAG: float = 38.0       ## Crisp linear deceleration to come to a clean stop
const STOP_SPEED: float = 14.0        ## Clean dead-stop threshold
const MAX_SUB_STEP_DIST: float = 3.5  ## Guarantees zero tunneling even at max speed
