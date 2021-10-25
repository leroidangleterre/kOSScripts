clearscreen.
print "Stabilizing altitude.".

set targetAlt to 1500.
print targetAlt.

set targetSpeed to 200.
print "target speed: " + targetSpeed.

set targetPitch to 0.
set targetCompass to 90.

set I to 0.
set dt to 0.5.
set Pprev to 0.
set kP to 0.09.
set kI to 0.005.
set kD to 0.003.

until ship:altitude > 25000 {
	
	// Set correct speed
	if ship:velocity:surface:mag < targetSpeed {
		lock throttle to 1.
	}
	else {
		lock throttle to 0.
	}
	
	
	set P to targetAlt - ship:altitude.
	
	set I to I + P*dt.
	set D to (P - Pprev)/dt.
	
	set targetPitch to kP * P + kI * I + kD * D.

	
	print "set pitch to " + targetPitch.
	
	lock steering to heading(targetCompass, targetPitch).
	
	set Pprev to P.
	// Wait
	set now to time:seconds.
	wait until time:seconds > now + dt.
}