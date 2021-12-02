clearscreen.

sas off.

set targetAlt to 700.
set targetSpeed to 150.
set targetCompass to 90.


print "Target alt: " + targetAlt + "; target speed: " + targetSpeed.

set targetPitch to 0.

set currentSpeed to 0.

set maxPitch to 20.
set minPitch to -5.
set targetRoll to 0.
set rollCommand to 0.

set dt to 0.5.

// PID for altitude
// 0.085, 0.007, 0.050 not bad but with significant overshoot
set kPalt to 0.085.
set kIalt to 0.007.
set kDalt to 0.050.
set Ialt to 0.
set Dalt to 1.
set prevAlt to 0.
set tuneLimitAltitude to 100.

// PID for speed
// 0.120, 0.010, 0.005 not bad but with significant overshoot
set kPspeed to 0.010.
set kIspeed to 0.001.
set kDspeed to 0.200.
set Ispeed to 0.
set Dspeed to 0.
set prevSpeed to 0.

// PID for roll
set kProll to 0.030.
set kIroll to 0.001.
set kDroll to 0.000.
set Iroll to 0.
set Droll to 0.
set prevRoll to 0.


list engines in myEnginesList.

set exit to false.
until exit = true{


	set totalFuelFlow to 0.
	for eng in myEnginesList {
		set totalFuelFlow to totalFuelFlow + eng:fuelFlow.
	}
//	print "fuel flow: " + totalFuelFlow.
	
	
	list resources in resourcesList.
	for res in resourcesList {
		if res:name = "LiquidFuel" {
//			print "resource: " + res.
			set remainingFuel to res:amount.
		}
	}
	if totalFuelFlow <> 0 {
		set remainingFlightDuration to remainingFuel / totalFuelFlow.
//		print "currentSpeed: " + ship:velocity:surface:mag.
		set range to remainingFlightDuration * ship:velocity:surface:mag.
//		print "Flight duration: " + remainingFlightDuration + ", expected range: " + (range/1000) + "km".
	}

	// PID for altitude
	set PaltPrev to targetAlt - prevAlt.
	set Palt to targetAlt - ship:altitude.
	set Ialt to Ialt + Palt*dt.
	// set Dalt to (Palt - prevAlt)/dt.
	set Dalt to (Palt - PaltPrev)/dt.
	set prevAlt to ship:altitude.
	if kIalt * Ialt > tuneLimitAltitude { set Ialt to tuneLimitAltitude/kIalt. } // Limit kI*i to [-1, 1] * tuneLimitAltitude
	if kIalt * Ialt < -tuneLimitAltitude { set Ialt to -tuneLimitAltitude/kIalt. }

	// print "kIalt = " + kIalt + ", Ialt = " + Ialt + ", kIalt * Ialt = " + kIalt * Ialt.
	
	set targetPitch to kPalt * Palt + kIalt * Ialt + kDalt * Dalt.

	set targetPitchTrimmed to targetPitch.
	//set infoPitch to "".
	//if targetPitchTrimmed > maxPitch {
	//	set targetPitchTrimmed to maxPitch.
	//	set infoPitch to "target pitch: " + targetPitch + ", trimmed pitch: " + targetPitchTrimmed.
	//}
	//else if targetPitchTrimmed < minPitch {
	//	set targetPitchTrimmed to minPitch.
	//	set infoPitch to "target pitch: " + targetPitch + ", trimmed pitch: " + targetPitchTrimmed.
	//}
	//else {
	//	set infoPitch to "target pitch: " + targetPitch.
	//}
	//// print infoPitch.


	lock steering to heading(targetCompass, targetPitchTrimmed, rollCommand).

	// PID for speed
	set PspeedPrev to targetSpeed - prevSpeed.
	set Pspeed to targetSpeed - ship:velocity:surface:mag.
	set Ispeed to Ispeed + Pspeed*dt.
	set Dspeed to (Pspeed - PspeedPrev)/dt.
	set prevSpeed to ship:velocity:surface:mag.
	//if kIspeed * Ispeed > 1 { set Ispeed to 1/kIspeed. } // Limit kI*i to [-1, 1]
	//if kIspeed * Ispeed < -1 { set Ispeed to -1/kIspeed. }
	
	// print "Ispeed: " + Ispeed + ", Dspeed: " + Dspeed.

	set targetThrottle to kPspeed * Pspeed + kIspeed * Ispeed + kDspeed * Dspeed.

	lock throttle to targetThrottle.


	// PID for roll
	// print "roll: " + ship:facing:roll.
	set Proll to targetRoll - ship:facing:roll.
	set Iroll to Iroll + Proll*dt.
	set Droll to (Proll - prevRoll)/dt.
	set prevRoll to ship:facing:roll.
	if kIroll * Iroll > 1 { set Iroll to 1/kIroll. } // Limit kI*i to [-1, 1]
	if kIroll * Iroll < -1 { set Iroll to -1/kIroll. }

	set rollCommand to kProll * Proll + kIroll * Iroll + kDroll * Droll.
	// print "roll command: " + rollCommand+ ", current: " + ship:facing:roll.
	
	
	// Speed and Altitude control:
	// left, right: heading
	// up, down: altitude
	// Keypad plus, keypad minus: speed

	// Read input from keyboard
	if terminal:input:haschar {
		set ch to terminal:input:getchar().
		if ch = terminal:input:LEFTCURSORONE {
			set targetCompass to targetCompass - 10.
			if targetCompass < 0 {
				set targetCompass to targetCompass + 360.
			}
			print "New heading: " + targetCompass.
		}
		if ch = terminal:input:RIGHTCURSORONE {
			set targetCompass to targetCompass + 10.
			if targetCompass >= 360 {
				set targetCompass to targetCompass - 360.
			}
			print "New heading: " + targetCompass.
		}

		set altitudeIncrement to 100.
		
		set altiOrSpeedChanged to false.
		if ch = terminal:input:DOWNCURSORONE {
		
			if targetAlt <= 400 {
				set altitudeIncrement to 50.
			}
			if targetAlt <= 200 {
				set altitudeIncrement to 10.
			}
		
			set targetAlt to targetAlt - altitudeIncrement.
			set altiOrSpeedChanged to true.
		}
		if ch = terminal:input:UPCURSORONE {

			if targetAlt < 400 {
				set altitudeIncrement to 50.
			}
			if targetAlt < 200 {
				set altitudeIncrement to 10.
			}

			set targetAlt to targetAlt + altitudeIncrement.
			set altiOrSpeedChanged to true.
		}
		if ch = "+" {
			if targetSpeed < 50 {
				set targetSpeed to targetSpeed + 1.
			}
			else {
				set targetSpeed to targetSpeed + 10.
			}
			set altiOrSpeedChanged to true.
		}
		if ch = "-" {
			if targetSpeed <= 50 {
				set targetSpeed to targetSpeed - 1.
			}
			else {
				set targetSpeed to targetSpeed - 10.
			}
			set altiOrSpeedChanged to true.
		}
		
		if altiOrSpeedChanged {
			print "Target altitude : " + targetAlt + "m; target speed: " + targetSpeed + "m/s.".
		}
		
		if ch = "l" {
			print "Current latitude: " + ship:latitude.
		}
		
		if ch = "q" {
			print "Exit.".
			sas on.
			set exit to true.
		}
	}
	
	
	// Wait
	set now to time:seconds.
	wait until time:seconds > now + dt.
}