

clearscreen.
print "Starting.".


// Computation of integral term: memorize a table of the latest n values, and give less weight to the oldest ones.
// Test if that principle can prevent a long overshot, as when the command altitude is way higher than the current one.


// Use telemachus to map the ground altitude around Kerbin's equator (can we get the sea depth ?), and the altitude and speed of the aircraft.
// Map at least one meridian as well; detect the poles to change the target heading.
// Export also the current fuel amount, fuel consumption and estimated range.


// Top perf: 6200m 640m/s

set takeoffSpeed to 80.
set altitudeIncrement to 10.
set targetVerticalSpeed to 10.
set speedIncrement to 10.
// Cruise speed, targetAlt and heading are set after the PID coefficients.
set terrainLatitude to -0.08726.
set cruiseAltitudeMargin to 100.

set dHeading to 5.


// set phase to "climb".
set phase to "cruise".
// set phase to "takeoff".

sas off.

set targetPitch to 90.

set currentSpeed to 0.

set minPitch to -5.
set targetRoll to 270.

set remainingFuel to 0.

set dt to 0.3.

// Jumbo90: 0.05 - 0.005 - 0.2
// Concorde: 0.005 - 0.005 - 0.12
// Mig: .04 .003 .07 stable at 1936m for 2000m

// Jumbo90p: (.015 .0 .060 stable at 271m for target 1000m; kI .0001 very slow climb)
// Jumbo90: .012 .0004 .060

// Mig-4: .050 .001 .120; ceiling: 6000m; top speed: mach 4

// A320:
// .01 .000 .08 stable
// .015 .0  .15 stable at 1100m for 2000m


// PID for altitude

// Tanker with extended payload bay
// set kPalt to 0.04. set kIalt to 0.0003. set kDalt to 1.0.

// Mach 1
// set kPalt to 0.05. set kIalt to 0.001. set kDalt to 0.1.

// Bullet
// set kPalt to 0.027. set kIalt to 0.0008. set kDalt to 0.6.

// Concorde
// set kPalt to 0.020. set kIalt to 0.0001. set kDalt to 0.05.

// Tanker
//set kPalt to 0.01. set kIalt to 0.002. set kDalt to 0.9.

// Water 300
// set kPalt to 0.15. set kIalt to 0.005. set kDalt to 0.2.

// Generic Airliner and Tanker (Cruise: 6000m, 290m/s)
// set kPalt to 0.08. set kIalt to 0.0006. set kDalt to 0.08.

// Quick
set kPalt to 0.2. set kIalt to 0.003. set kDalt to 0.8.

set targetCompass to 90.
set targetCruiseSpeed to 220. // 1400
set targetAlt to 700.

set mustPrintPalt to false.

set targetSpeed to targetCruiseSpeed.
print "Target alt: " + targetAlt + "; speed: " + targetSpeed + "; heading: " + targetCompass.

set Ialt to 0.
set Dalt to 0.
set PaltPrev to targetAlt - ship:altitude.
set prevAlt to 0.
set tuneLimitAltitude to 100. // 12.
set targetPitchTrimmed to 0.
set maxPitch to 70.

// PID for horizontal speed
set kPspeed to 0.060.
set kIspeed to 0.010.
set kDspeed to 0.200.
set Ispeed to 0.
set Dspeed to 0.
set prevSpeed to 0.
set tuneSpeedLimit to 1.3.


// Concorde: 0.8 - 0.05 - 0.0
// PID for vertical speed
set kPvSpeed to 0.900.
set kIvSpeed to 0.080.
set kDvSpeed to 0.000.
set IvSpeed to 0.
set DvSpeed to 0.
set prevVspeed to 0.


// PID for roll
set kProll to 0.000.
set kIroll to 0.000.
set kDroll to 0.000.
set Iroll to 0.
set Droll to 0.
set prevRoll to 0.


set prevHeading to ship:heading.
set altitudeList to list().
set maxLength to 200.

list engines in myEnginesList.


declare function next {
	parameter x.
	if x >= 10 {
		if(x >= 10000){
			set newX to x + 1000.
		}else{
			set newX to x*2.
		}
		print "log x: " + log10(x) + ", log(newX): " + log10(newX).
		set fx to floor(log10(x)).
		set fxNext to floor(log10(newX)).
		print "floors: " + fx + ", " + fxNext.
		if(fx <> fxNext) {
			set newX to 10^floor(log10(newX)).
		}
	}
	else {
		set newX to x+1.
	}
	return newX.
}

declare function previous {
	parameter x.
	if x = 0 {
		return x.
	}
	if x >= 10 {
		if(x >= 10000){
			set newX to x - 1000.
		}else{
			set newX to x/2.
		}
		print "log x: " + log10(x) + ", log(newX): " + log10(newX).
		set fx to floor(log10(x)).
		set fxNext to floor(log10(newX)).
		print "floors: " + fx + ", " + fxNext.
		if(fx <> fxNext) {
			set newX to 0.8*x.
		}
	}
	else {
		set newX to x-1.
	}
	return newX.
}


set exit to false.
until exit = true{


	//if alt:radar > 300 {
	//	gear off.
	//	lights off.
	//}
	//else{
	//	gear on.
	//	lights on.
	//}

	set totalFuelFlow to 0.
	for eng in myEnginesList {
		set totalFuelFlow to totalFuelFlow + eng:fuelFlow.
	}
	
	
	list resources in resourcesList.
	for res in resourcesList {
		if res:name = "LiquidFuel" {
			set remainingFuel to res:amount.
		}
	}
	if totalFuelFlow <> 0 {
		set remainingFlightDuration to remainingFuel / totalFuelFlow.
		set range to remainingFlightDuration * ship:velocity:surface:mag.
	}

	if phase = "climb" and ship:altitude > targetAlt - cruiseAltitudeMargin {
		print "Target altitude almost reached, starting cruise phase; target altitude: " + targetAlt + " m, target speed: " + targetCruiseSpeed + " m/s.".
		set phase to "cruise".
		set targetSpeed to targetCruiseSpeed.
	}
	else if phase = "takeoff" {
		// Gain speed
		brakes off.
		print "Takeoff, speed " + ship:velocity:surface:mag + ", aiming for " + takeoffSpeed.
		if ship:velocity:surface:mag > takeoffSpeed {
			print "Reaching almost takeoff speed".
			set phase to "climb".
		}
	}
	else if phase = "climb" {
		print "climb".
		// PID for vertical speed
		set PvSpeedPrev to targetVerticalSpeed - prevVspeed.
		set PvSpeed to targetVerticalSpeed - ship:verticalSpeed.
		set IvSpeed to IvSpeed + PvSpeed*dt.
		set DvSpeed to (PvSpeed - PvSpeedPrev)/dt.
		set prevVspeed to ship:verticalSpeed.
		// TODO: if kIalt * Ialt > tuneLimitAltitude { set Ialt to tuneLimitAltitude/kIalt.} // Limit kI*i to [-1, 1] * tuneLimitAltitude
		// TODO: if kIalt * Ialt < -tuneLimitAltitude { set Ialt to -tuneLimitAltitude/kIalt.}
		set targetPitch to kPvSpeed * PvSpeed + kIvSpeed * IvSpeed + kDvSpeed * DvSpeed.
	}
	else {
	
		// PID for altitude
		set Palt to targetAlt - ship:altitude.
		
		// Initial way to compute integral term:
		set Ialt to Ialt + Palt*dt.
		
		
		set Dalt to (Palt - PaltPrev)/dt.
		
		
		if kIalt * Ialt > tuneLimitAltitude { set Ialt to tuneLimitAltitude/kIalt.} // Limit kI*i to [-1, 1] * tuneLimitAltitude
		if kIalt * Ialt < -tuneLimitAltitude { set Ialt to -tuneLimitAltitude/kIalt.}
		

		if mustPrintPalt {
			print "Palt: " + Palt + ", PaltPrev: " + PaltPrev + ", Dalt: " + Dalt.
		}
		
		set targetPitch to kPalt * Palt + kIalt * Ialt + kDalt * Dalt.
		
		set prevAlt to ship:altitude.
		set PaltPrev to targetAlt - ship:altitude.
	}
	set targetPitchTrimmed to targetPitch.
	// if targetPitchTrimmed > maxPitch {
	// 	set targetPitchTrimmed to maxPitch.
	// 	print "targetPitch = " + targetPitch + ", targetPitchTrimmed = " + targetPitchTrimmed.
	// }
	// if targetPitchTrimmed < -maxPitch {
	// 	set targetPitchTrimmed to -maxPitch.
	// 	print "targetPitch = " + targetPitch + ", targetPitchTrimmed = " + targetPitchTrimmed.
	// }
	
	


	// PID for speed
	set PspeedPrev to targetSpeed - prevSpeed.
	set Pspeed to targetSpeed - ship:velocity:surface:mag.

	set Ispeed to Ispeed + Pspeed*dt.


	set Dspeed to (Pspeed - PspeedPrev)/dt.
	set prevSpeed to ship:velocity:surface:mag.
	if kIspeed * Ispeed > tuneSpeedLimit { set Ispeed to tuneSpeedLimit/kIspeed. } // Limit kI*i to [-1, 1]
	if kIspeed * Ispeed < -tuneSpeedLimit { set Ispeed to -tuneSpeedLimit/kIspeed. }
	
//	print "Ispeed: " + Ispeed + ", Dspeed: " + Dspeed + ", Pspeed: " + Pspeed.

	set targetThrottle to kPspeed * Pspeed + kIspeed * Ispeed + kDspeed * Dspeed.

	lock throttle to targetThrottle.


	// PID for roll
	// print "roll: " + ship:facing:roll.
	set ProllPrev to targetRoll - prevRoll.
	set Proll to targetRoll - ship:facing:roll.
	set Iroll to Iroll + Proll*dt.
	set Droll to (Proll - ProllPrev)/dt.
	set prevRoll to ship:facing:roll.
	// if kIroll * Iroll > 1 { set Iroll to 1/kIroll. } // Limit kI*i to [-1, 1]
	// if kIroll * Iroll < -1 { set Iroll to -1/kIroll. }

	set rollCommand to kProll * Proll + kIroll * Iroll + kDroll * Droll.
	// print "roll command: " + rollCommand+ ", current: " + ship:facing:roll.
	
	lock steering to heading(targetCompass, targetPitchTrimmed). //, rollCommand).
	
	// Speed and Altitude control:
	// left, right: heading
	// up, down: altitude
	// Keypad plus, keypad minus: speed

	// Read input from keyboard
	if terminal:input:haschar {
		set ch to terminal:input:getchar().
		if ch = terminal:input:LEFTCURSORONE {
			set targetCompass to targetCompass - dHeading.
			if targetCompass < 0 {
				set targetCompass to targetCompass + 360.
			}
			print "New heading: " + targetCompass.
		}
		if ch = terminal:input:RIGHTCURSORONE {
			set targetCompass to targetCompass + dHeading.
			if targetCompass >= 360 {
				set targetCompass to targetCompass - 360.
			}
			print "New heading: " + targetCompass.
		}
		
		
		if ch = "9" {
			set speedIncrement to 2*speedIncrement.
			print "speed increment: " + speedIncrement.
		}
		if ch = "3" {
			set speedIncrement to speedIncrement/2.
			print "speed increment: " + speedIncrement.
		}
		if ch = "8" {
			set altitudeIncrement to 2*altitudeIncrement.
			print "altitude increment: " + altitudeIncrement.
		}
		if ch = "2" {
			set altitudeIncrement to altitudeIncrement/2.
			print "altitude increment: " + altitudeIncrement.
		}
		
		set altiOrSpeedChanged to false.
		if ch = terminal:input:DOWNCURSORONE {
		
			// set targetAlt to previous(targetAlt).
			set targetAlt to targetAlt - altitudeIncrement.
			set altiOrSpeedChanged to true.
		}
		if ch = terminal:input:UPCURSORONE {

			// set targetAlt to next(targetAlt).
			set targetAlt to targetAlt + altitudeIncrement.
			set altiOrSpeedChanged to true.
		}
		
		if ch = "+" {
			// set targetSpeed to next(targetSpeed).
			set targetSpeed to targetSpeed + speedIncrement.
			set altiOrSpeedChanged to true.
		}
		if ch = "-" {
			// set targetSpeed to previous(targetSpeed).
			set targetSpeed to targetSpeed - speedIncrement.
			set altiOrSpeedChanged to true.
		}
		
		
		if altiOrSpeedChanged {
			print "Target altitude : " + targetAlt + "m; target speed: " + targetSpeed + "m/s.".
		}
		
		if ch = "l" {
			print "Current latitude: " + ship:latitude.
		}
		
		if ch = "d" {
			print "Estimated flight duration: " + remainingFlightDuration + ", expected range: " + (range/1000) + "km".
		}
		if ch = "f" {
			// print "engine consumption".
			set currentSpeed to ship:velocity:surface:mag. // speed in m/s
			set instantFuelConsumption to 0.
			list engines in engineList.
			for engine in engineList{
				set instantFuelConsumption to instantFuelConsumption + engine:fuelFlow.
				// print "Engine: " + engine:uid + ": flow " + engine:fuelFlow.
			}
			if instantFuelConsumption > 0 {
				set fuelEfficiency to (currentSpeed/instantFuelConsumption).
			}
			else {
				set fuelEfficiency to 42000000000.
			}
			// Remove non-significant digits
			if(fuelEfficiency >= 1000) {
				set fuelEfficiency to fuelEfficiency/1000. // (km/L)
				set dotIndex to (fuelEfficiency+""):findLast(".").
				set fuelEfficiencyTrimmed to (fuelEfficiency+""):substring(0, dotIndex+3).
				print "Fuel efficiency: " + fuelEfficiencyTrimmed + " km/L".
			}
			else{
				set dotIndex to (fuelEfficiency+""):findLast(".").
				set fuelEfficiencyTrimmed to (fuelEfficiency+""):substring(0, dotIndex+3).
				print "Fuel efficiency: " + fuelEfficiencyTrimmed + " m/L".
			}
		}
		
		if ch = "w" {
			// Align on the runway facing west in preparation for landing.
			
		}
		
		if ch = "i" {
			// Display the current value of the integral term.
			print "Ialt: " + Ialt + ", kIalt * Ialt : " + kIalt * Ialt.
			print "Ispeed: " + Ispeed + ", kIspeed * Ispeed: " + kIspeed * Ispeed.
			// print "Iroll: " + Iroll+ ", kIroll* Iroll: " + kIroll* Iroll.
		}
		
		if ch = "p" {
			set mustPrintPalt to not mustPrintPalt.
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