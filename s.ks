clearscreen.

set targetAlt to 1000.
set targetSpeed to 150.


print "Stabilizing altitude to " + targetAlt + "; target speed: " + targetSpeed.

set targetPitch to 0.
set targetCompass to 90.

set currentSpeed to 0.

set maxPitch to 20.
set minPitch to -5.
set targetRoll to 0.

set I to 0.
set dt to 0.5.
set Pprev to 0.
set kP to 0.09.
set kI to 0.005.
set kD to 0.003.


set Ispeed to 0.
set PspeedPrev to 0.
set kPspeed to 0.09.
set kIspeed to 0.002.
set kDspeed to 0.003.


list engines in myEnginesList.


until ship:altitude > 25000 {

	set totalFuelFlow to 0.
	for eng in myEnginesList {
		set totalFuelFlow to totalFuelFlow + eng:fuelFlow.
	}
	print "fuel flow: " + totalFuelFlow.
	
	
	list resources in resourcesList.
	for res in resourcesList {
		if res:name = "LiquidFuel" {
			print "resource: " + res.
			set remainingFuel to res:amount.
		}
	}
	set remainingFlightDuration to remainingFuel / totalFuelFlow.
	print "Flight duration: " + remainingFlightDuration.
	set range to remainingFlightDuration * currentSpeed.
	print "expected range: " + (range/1000) + "km".

	set P to targetAlt - ship:altitude.

	set I to I + P*dt.
	set D to (P - Pprev)/dt.

	set targetPitch to kP * P + kI * I + kD * D.

	set targetPitchTrimmed to targetPitch.
	set infoPitch to "".
	if targetPitchTrimmed > maxPitch {
		set targetPitchTrimmed to maxPitch.
		set infoPitch to "target pitch: " + targetPitch + ", trimmed pitch: " + targetPitchTrimmed.
	}
	else if targetPitchTrimmed < minPitch {
		set targetPitchTrimmed to minPitch.
		set infoPitch to "target pitch: " + targetPitch + ", trimmed pitch: " + targetPitchTrimmed.
	}
	else {
		set infoPitch to "target pitch: " + targetPitch.
	}
//	print infoPitch.


	lock steering to heading(targetCompass, targetPitchTrimmed, targetRoll).


	set currentSpeed to ship:velocity:surface:mag.
	set Pspeed to targetSpeed - currentSpeed.
	set Ispeed to Ispeed + Pspeed*dt.
	set Dspeed to (Pspeed - PspeedPrev)/dt.

	set targetThrottle to kPspeed * Pspeed + kIspeed * Ispeed + kDspeed * Dspeed.

	lock throttle to targetThrottle.

	set Pprev to P.
	// Wait
	set now to time:seconds.
	wait until time:seconds > now + dt.
}