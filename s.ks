

clearscreen.
print "Starting.".


// Computation of integral term: memorize a table of the latest n values, and give less weight to the oldest ones.
// Test if that principle can prevent a long overshot, as when the command altitude is way higher than the current one.


// Use telemachus to map the ground altitude around Kerbin's equator (can we get the sea depth ?), and the altitude and speed of the aircraft.
// Map at least one meridian as well; detect the poles to change the target heading.
// Export also the current fuel amount, fuel consumption and estimated range.


// Top perf: 6200m 640m/s

set takeoffSpeed to 80.
set targetAlt to 2000.
set altitudeIncrement to 10.
set targetVerticalSpeed to 10.
set targetCruiseSpeed to 200.
set speedIncrement to 10.
set targetSpeed to targetCruiseSpeed.
set targetCompass to 90.
set terrainLatitude to -0.08726.
set cruiseAltitudeMargin to 100.

set dHeading to 5.

print "Target alt: " + targetAlt + "; target speed: " + targetSpeed.

// set phase to "climb".
set phase to "cruise".
// set phase to "takeoff".

sas off.

set targetPitch to 0.

set currentSpeed to 0.

set minPitch to -5.
set targetRoll to 270.

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
// Mach 2 Aircraft
// set kPalt to 0.2. set kIalt to 0.005. set kDalt to 3.0.
// Mach 3 Aircraft (3300m, 820m/s)
// set kPalt to 0.28. set kIalt to 0.008. set kDalt to 0.8.
// Tanker
// set kPalt to 0.2. set kIalt to 0.005. set kDalt to 0.9.
// old tanker: set kPalt to 0.2. set kIalt to 0.005. set kDalt to 0.9.
// Whiplash Mach 3
set kPalt to 0.03. set kIalt to 0.0006. set kDalt to 0.5.
// Airliner 6 segments
// set kPalt to 0.1. set kIalt to 0.003. set kDalt to 1.0.


set Ialt to 0.
set Dalt to 0.
set PaltPrev to targetAlt - ship:altitude.
set prevAlt to 0.
set tuneLimitAltitude to 9. // 12.
set targetPitchTrimmed to 0.
set maxPitch to 60.

// PID for horizontal speed
set kPspeed to 0.070.
set kIspeed to 0.004.
set kDspeed to 0.080.
set Ispeed to 0.
set Dspeed to 0.
set prevSpeed to 0.
set tuneSpeedLimit to 0.8.


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
		
		// set Dalt to (Palt - prevAlt)/dt.
		set Dalt to (Palt - PaltPrev)/dt.
		if kIalt * Ialt > tuneLimitAltitude { set Ialt to tuneLimitAltitude/kIalt.} // Limit kI*i to [-1, 1] * tuneLimitAltitude
		if kIalt * Ialt < -tuneLimitAltitude { set Ialt to -tuneLimitAltitude/kIalt.}
		set targetPitch to kPalt * Palt + kIalt * Ialt + kDalt * Dalt.
		
		// print "kPalt*Palt: " + (kPalt*Palt) + ", kIalt*Ialt: " + (kIalt*Ialt) + ", kDalt*Dalt: " + (kDalt*Dalt).
		set prevAlt to ship:altitude.
		set PaltPrev to targetAlt - ship:altitude.
	}
	set targetPitchTrimmed to targetPitch.
	if targetPitchTrimmed > maxPitch { set targetPitchTrimmed to maxPitch.}
	if targetPitchTrimmed < -maxPitch { set targetPitchTrimmed to -maxPitch.}
	// print "targetPitch = " + targetPitch + ", targetPitchTrimmed = " + targetPitchTrimmed.
	


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

		
		set altiOrSpeedChanged to false.
		if ch = terminal:input:DOWNCURSORONE {
		
			set targetAlt to previous(targetAlt).
			set altiOrSpeedChanged to true.
		}
		if ch = terminal:input:UPCURSORONE {

			set targetAlt to next(targetAlt).
			set altiOrSpeedChanged to true.
		}
		
		if ch = "+" {
			set targetSpeed to next(targetSpeed).
			set altiOrSpeedChanged to true.
		}
		if ch = "-" {
			set targetSpeed to previous(targetSpeed).
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
			print "engine consumption".
			set currentSpeed to ship:velocity:surface:mag. // speed in m/s
			set instantFuelConsumption to 0.
			list engines in engineList.
			for engine in engineList{
				set instantFuelConsumption to instantFuelConsumption + engine:fuelFlow.
				// print "Engine: " + engine:uid + ": flow " + engine:fuelFlow.
			}
			print "Liters per 100 km: " + (1000 * instantFuelConsumption/currentSpeed) + " (L/100km)".
			print "Kilometers per unit fuel: " + (currentSpeed/instantFuelConsumption) + " (meters per liter)".
		}
		
		if ch = "w" {
			// Align on the runway facing west in preparation for landing.
			
		}
		
		if ch = "i" {
			// Display the current value of the integral term.
			print "Ialt: " + Ialt + ", kIalt * Ialt : " + kIalt * Ialt.
			// print "Ispeed: " + Ispeed + ", kIspeed * Ispeed: " + kIspeed * Ispeed.
			// print "Iroll: " + Iroll+ ", kIroll* Iroll: " + kIroll* Iroll.
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