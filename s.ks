
// Create the GUI

LOCAL my_gui IS GUI(300,150).
set isGuiVisible to true.

// Add widgets to the GUI

LOCAL airSpeedBox is my_gui:addHBox().

LOCAL label IS airSpeedBox:ADDLABEL("Airspeed").
SET label:STYLE:ALIGN TO "LEFT".

LOCAL speedTextField TO airSpeedBox:ADDTEXTFIELD("").
SET speedTextField:STYLE:ALIGN TO "RIGHT".
SET speedTextField:STYLE:HSTRETCH TO True.
set speedTextField:style:width to 60.

set speedTextField:onConfirm to {
	parameter str.
	set convertedVal to str:toNumber(-9999).
	if convertedVal = -9999 {
		print "error in speed conversion, setting speed to " + requestedCruiseSpeed.
		set convertedVal to requestedCruiseSpeed.
	}
	print "speed confirmation: " + convertedVal.
	set requestedCruiseSpeed to convertedVal.
	set speedTextField:text to "" + requestedCruiseSpeed.
}.


LOCAL altitudeBox is my_gui:addHBox().

LOCAL label IS altitudeBox:ADDLABEL("Altitude").
SET label:STYLE:ALIGN TO "LEFT".
LOCAL altitudeTextField TO altitudeBox:ADDTEXTFIELD("").
SET altitudeTextField:STYLE:ALIGN TO "RIGHT".
SET altitudeTextField:STYLE:HSTRETCH TO True.
set altitudeTextField:style:width to 60.
set altitudeTextField:onConfirm to {
	parameter str.
	set convertedVal to str:toNumber(-9999).
	if convertedVal = -9999 {
		print "error in altitude conversion, setting altitude to " + requestedAlt.
		set convertedVal to requestedAlt.
	}
	print "altitude confirmation: " + convertedVal.
	set requestedAlt to convertedVal.
	set altitudeTextField:text to "" + requestedAlt.
}.

LOCAL headingBox is my_gui:addHBox().

LOCAL label IS headingBox:ADDLABEL("Heading").
SET label:STYLE:ALIGN TO "LEFT".

local headingLeftButton to headingBox:addButton("Left").
SET headingLeftButton:STYLE:ALIGN TO "LEFT".
SET headingLeftButton:STYLE:HSTRETCH TO False.
set headingLeftButton:style:width to 60.
set headingLeftButton:onClick to {
	increaseHeading(-5).
}.

LOCAL headingTextField TO headingBox:ADDTEXTFIELD("").
SET headingTextField:STYLE:ALIGN TO "CENTER".
SET headingTextField:STYLE:HSTRETCH TO False.
set headingTextField:style:width to 60.

local headingRightButton to headingBox:addButton("Right").
SET headingRightButton:STYLE:ALIGN TO "RIGHT".
SET headingRightButton:STYLE:HSTRETCH TO False.
set headingRightButton:style:width to 60.
set headingRightButton:onClick to {
	increaseHeading(5).
}.


// Show the GUI.
my_gui:SHOW().

// Handle GUI widget interactions.
LOCAL isDone IS FALSE.





// END GUI

set standardMaxVario to 45.
set extendedMaxVario to 70.
set speedForExtendedVario to 200.
set currentMaxVario to 0.
set varioSmoothingRate to 2.

clearscreen.
print "Starting.".

// Increase the loading distance.
set KUNIVERSE:DEFAULTLOADDISTANCE:FLYING:load to 5000.

set takeoffSpeed to 80.
set altitudeIncrement to 10.
//set targetVerticalSpeed to 10.
set speedIncrement to 10.
// Cruise speed, requestedAlt and heading are set after the PID coefficients.
set terrainLatitude to -0.08726.
set terrainLongitude to -74.623. // west; east: -74.580
set terrainAltitude to 70.
set cruiseAltitudeMargin to 100.
set isDriving to false.
set isGoingHome to false.

set dHeading to 5.

set phase to "cruise".

sas off.
brakes off.

set targetPitch to 90.

set currentSpeed to 0.

set minPitch to -5.
set targetRoll to 270.

set remainingFuel to 0.

set dt to 0.3.

// this PID controls vertical speed, or vario
set kPvario to 0.5. set kIvario to 0.1. set kDvario to 0.5.

set requestedHeading to 90.
set headingTextField:text to "" + requestedHeading.
set requestedCruiseSpeed to 150.
set speedTextField:text to "" + requestedCruiseSpeed.
set requestedAlt to 1000.
set altitudeTextField:text to "" + requestedAlt.
set requestedVario to 0.
// set isSmoothing to false.

set isFollowingTarget to false.
set distanceToTarget to 0.

set mustPrintPalt to false.

set timeSinceLastDisplay to 0.
set timeBetweenDisplays to 3.

print "Target alt: " + requestedAlt + "; speed: " + requestedCruiseSpeed + "; heading: " + requestedHeading.


// PID to control vario
set Ivario to 0.
set Dvario to 0.
set PvarioPrev to requestedVario - ship:verticalspeed.
set prevVario to 0.
set tuneLimitVario to 100.
set targetPitchTrimmed to 0.
set maxPitch to 70.


// PID for horizontal speed
set kPspeed to 0.035.
set kIspeed to 0.0035.
set kDspeed to 0.12. // 0.07.
set Ispeed to 0.
set Dspeed to 0.
set prevSpeed to 0.
set tuneSpeedLimit to 1.3.


// PID for roll
set kProll to 0.000.
set kIroll to 0.000.
set kDroll to 0.000.
set Iroll to 0.
set Droll to 0.
set prevRoll to 0.


set prevHeading to ship:heading.
set maxLength to 200.

list engines in myEnginesList.
set remainingFlightDuration to 0.
set currentRange to 0.

set goingToNewVario to false.
set previousChangeInTargetVario to 0.

declare function computeSmoothedVario {
	parameter currentAltitude.
	parameter requestedAltitude.
	parameter requestedVarioOld.

	set roughVario to computeVario(currentAltitude, requestedAltitude).
	
	set isVarioNew to false.
	
	if roughVario > requestedVarioOld + varioSmoothingRate {
		set varioSmoothed to requestedVarioOld + varioSmoothingRate.
	}
	else if roughVario < requestedVarioOld - varioSmoothingRate {
		set varioSmoothed to requestedVarioOld - varioSmoothingRate.
	}
	else {
		set varioSmoothed to roughVario.
		if roughVario <> requestedVarioOld and abs(roughVario) >= 1{
			print "final vario: " + varioSmoothed.
		}
	}
	
	if abs(varioSmoothed) > 1 and varioSmoothed <> roughVario {
		print "smoothed vario: " + varioSmoothed.
	}
	return varioSmoothed.
}

declare function computeVario {
	parameter currentAltitude.
	parameter requestedAltitude.
	
	set currentError to currentAltitude - requestedAltitude.

	set resultingVario to 0.
	
	// 	error:		-200	-100	- 50	- 10	+ 10	+ 50	+100	+200
	//	Vario:	+30     +15     +5       +2        0      -2     -5      -15      -30
	set varioA to 1.
	set varioB to 5.
	set varioC to 10.
	set varioD to 15.
	set varioE to 30.
//	set varioF to 70.
	
	
	if ship:velocity:surface:mag > speedForExtendedVario {
		set varioF to extendedMaxVario.
	}
	else {
		set varioF to standardMaxVario.
	}
	
	if currentError < -2000 {
		set resultingVario to varioF.
	}
	else if currentError < -1000 {
		set resultingVario to varioE.
	}
	else if -1000 < currentError and currentError < -400 {
		set resultingVario to varioD.
	}
	else if -400 < currentError and currentError < -200 {
		set resultingVario to varioC.
	}
	else if -200 < currentError and currentError < -50 {
		set resultingVario to varioB.
	}
	else if -50 < currentError and currentError < -10 {
		set resultingVario to varioA.
	}
	else if -10 < currentError and currentError < 10 {
		set resultingVario to -0.1 * currentError.
	}
	else if 10 < currentError and currentError < 50 {
		set resultingVario to -varioA.
	}
	else if 50 < currentError and currentError < 200 {
		set resultingVario to -varioB.
	}
	else if 200 < currentError and currentError < 400 {
		set resultingVario to -varioC.
	}
	else if 400 < currentError and currentError < 1000 {
		set resultingVario to -varioD.
	}
	else if 1000 < currentError and currentError < 2000 {
		set resultingVario to -varioE.
	}
	else{
		set resultingVario to -varioF.
	}
	
	// Requested vario will not excess limit.
	if resultingVario > varioF {
		set resultingVario to varioF.
		print "excess vario (l.198)".
	}
	return resultingVario.
}

declare function increaseHeading {
	parameter dHeading.

	set requestedHeading to requestedHeading + dHeading.
	if requestedHeading < 0 {
		set requestedHeading to requestedHeading + 360.
	}
	if requestedHeading >= 360 {
		set requestedHeading to requestedHeading - 360.
	}
	set requestedHeading to floor(requestedHeading/5) * 5.
	print "New heading: " + requestedHeading.
	set headingTextField:text to "" + requestedHeading.
}

declare function getHeadingForTarget {

	if hastarget {
		
		set lambdaA to ship:longitude.
		set phiA to ship:latitude.
		set lambdaB to target:longitude.
		set phiB to target:latitude.
		
		set TAX to V(-sin(lambdaA), cos(lambdaA), 0).
		set TAY to V(-sin(phiA)*cos(lambdaA), -sin(phiA)*sin(lambdaA), cos(phiA)).
		
		set Rt to 600000.
		
		set PNx to 0.
		set PNy to Rt*cos(phiA).
		
		set PBx to -Rt*cos(lambdaB)*cos(phiB)*sin(lambdaA) + Rt*sin(lambdaB)*cos(phiB)*cos(lambdaA).
		set PBy to -Rt*cos(lambdaB)*cos(phiB)*sin(phiA)*cos(lambdaA) - Rt*sin(lambdaB)*cos(phiB)*sin(phiA)*sin(lambdaA) + Rt*sin(phiB)*cos(phiA).
		
		
		set K to PBX / sqrt( PBx*PBx + PBy*PBy).
		
		if PBx > 0 and PBy > 0 {
			set targetHeading to arcsin(K).
		}
		else if PBx > 0 and PBy < 0 {
			set targetHeading to arcsin(-K) + 180.
		}
		else if PBx < 0 and PBy > 0 {
			set targetHeading to arcsin(K).
		}
		else {
			// PBx < 0 and PBy < 0
			set targetHeading to 180 - arcsin(K).
		}
		
		// print "Target heading: " + targetHeading.
		return targetHeading.
		
	}
	else {
		print "No target. Ship current heading: " + (-ship:bearing).
		return -ship:bearing.
	}
}

declare function computeSpeedFromTarget {
//	TODO need to compute speed for landed, driving and flying targets.
	set resultSpeed to 0.
	if hastarget {
		set prevDistanceToTarget to distanceToTarget.
		set distanceToTarget to (target:position - ship:position):mag.

		set targetGroundSpeed to target:groundspeed.
		
		print "targetGroundSpeed : " + targetGroundSpeed.
		if targetGroundSpeed < 1 {
			set targetIsGrounded to true.
		}
		else {
			set targetIsGrounded to false.
		}
		
		if ship.status = "LANDED" or targetIsGrounded{
		
			print "follow landed target".
			set resultSpeed to requestedCruiseSpeed.
		}
		else {	// MOVING TARGET or FLYING SHIP
			
			print "follow flying target".
			
			if distanceToTarget < 100 {
				// We now are close to target
				if not targetIsGrounded {
					set resultSpeed to targetGroundSpeed.
				}

				if prevDistanceToTarget > distanceToTarget {
					brakes on.
				}
				else {
					brakes off.
				}
			}
			else if distanceToTarget < 300 {
				set resultSpeed to targetGroundSpeed + 5.
			}
			else {
				set resultSpeed to targetGroundSpeed + 10.
			}
			// print "	target ground speed: " + resultSpeed.
		}
		// print "requested speed: " + resultSpeed.
	}
	else {
		// Default speed requested by user.
		set resultSpeed to requestedCruiseSpeed.
	}
	
	return resultSpeed.
}

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

// Set the wheel steer to turn the aircraft toward 'requestedHeading'.
declare function computeSteerFromHeading {
	
	if isFollowingTarget and HASTARGET {
		// print "following target".
		set requiredBearing to target:bearing.
	}
	else {
		set requiredBearing to requestedHeading + ship:bearing.
		if requiredBearing > 180 {
			set requiredBearing to requiredBearing - 360.
		}
	}	

	//print "requested heading: " + requestedHeading.
	//print "currentHeading: " + (-ship:bearing).
	// print "requiredBearing: " + requiredBearing.
	return -requiredBearing / 100.
}


// Determine in which sector the plane currently is, relative to a given runway.
declare function getApproachSector {
	
	return "E".
}


set exit to false.
until exit = true{

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
		set currentRange to remainingFlightDuration * ship:velocity:surface:mag.
	}
	
	set requestedVarioOld to requestedVario.
	set requestedVario to computeSmoothedVario(ship:altitude, requestedAlt, requestedVarioOld).

	
	//if phase = "climb" and ship:altitude > requestedAlt - cruiseAltitudeMargin {
	//	print "Target altitude almost reached, starting cruise phase; target altitude: " + requestedAlt + " m, requested speed: " + requestedCruiseSpeed + " m/s.".
	//	set phase to "cruise".
	//	// set requestedCruiseSpeed to requestedCruiseSpeed.
	//}
	//else if phase = "takeoff" {
	//	// Gain speed
	//	brakes off.
	//	print "Takeoff, speed " + ship:velocity:surface:mag + ", aiming for " + takeoffSpeed.
	//	if ship:velocity:surface:mag > takeoffSpeed {
	//		print "Reaching almost takeoff speed".
	//		set phase to "climb".
	//	}
	//}
	//else if phase = "climb" {
	//	print "climb".
	//	// PID for vertical speed
	//	set PvSpeedPrev to targetVerticalSpeed - prevVspeed.
	//	set PvSpeed to targetVerticalSpeed - ship:verticalSpeed.
	//	set IvSpeed to IvSpeed + PvSpeed*dt.
	//	set DvSpeed to (PvSpeed - PvSpeedPrev)/dt.
	//	set prevVspeed to ship:verticalSpeed.
	//	// TODO: if kIalt * Ialt > tuneLimitAltitude { set Ialt to tuneLimitAltitude/kIalt.} // Limit kI*i to [-1, 1] * tuneLimitAltitude
	//	// TODO: if kIalt * Ialt < -tuneLimitAltitude { set Ialt to -tuneLimitAltitude/kIalt.}
	//	set targetPitch to kPvSpeed * PvSpeed + kIvSpeed * IvSpeed + kDvSpeed * DvSpeed.
	//}
	//else {
		
	set Pvario to requestedVario - ship:verticalSpeed.
	set Ivario to Ivario + Pvario*dt.
	set Dvario to (Pvario - PvarioPrev)/dt.
	set targetPitch to kPvario*Pvario + kIvario*Ivario + kDvario*Dvario.
	
	set prevVario to ship:verticalSpeed.
	set PvSpeedPrev to requestedVario - ship:verticalSpeed.

	//}
	set targetPitchTrimmed to targetPitch.

	// PID for speed
	set PspeedPrev to requestedCruiseSpeed - prevSpeed.
	set Pspeed to requestedCruiseSpeed - ship:velocity:surface:mag.

	set Ispeed to Ispeed + Pspeed*dt.


	set Dspeed to (Pspeed - PspeedPrev)/dt.
	set prevSpeed to ship:velocity:surface:mag.
	if kIspeed * Ispeed > tuneSpeedLimit { set Ispeed to tuneSpeedLimit/kIspeed. } // Limit kI*i to [-1, 1]
	if kIspeed * Ispeed < -tuneSpeedLimit { set Ispeed to -tuneSpeedLimit/kIspeed. }

	set targetThrottle to kPspeed * Pspeed + kIspeed * Ispeed + kDspeed * Dspeed.

	lock throttle to targetThrottle.


	// PID for roll
	set ProllPrev to targetRoll - prevRoll.
	set Proll to targetRoll - ship:facing:roll.
	set Iroll to Iroll + Proll*dt.
	set Droll to (Proll - ProllPrev)/dt.
	set prevRoll to ship:facing:roll.

	set rollCommand to kProll * Proll + kIroll * Iroll + kDroll * Droll.
	
	if isFollowingTarget {
		set requestedHeading to getHeadingForTarget().
		set requestedCruiseSpeed to computeSpeedFromTarget().
	}
	else {
		// Simply apply requested heading.
	}

	// When changing directions on land, we must act on the wheel
	if ship:status = "LANDED" {
		// print "ship must turn on the ground.".
		if ship:groundspeed < 50 {
			// print "current yaw: " + ship:control:yaw.
			set commandSteer to computeSteerFromHeading().
			// print "	command steer: " + commandSteer.
			set ship:control:wheelsteer to commandSteer.
		}
		else {
			set ship:control:wheelsteer to 0.
		}
	}

	if isDriving {
		unlock steering.
	}
	else {
		lock steering to heading(requestedHeading, targetPitchTrimmed).
	}
	
	// Speed and Altitude control:
	// left, right: heading
	// Keyboard 'T': set heading to target
	// up, down: altitude
	// Keypad plus, keypad minus: speed

	// Read input from keyboard
	if terminal:input:haschar {
		set ch to terminal:input:getchar().
		if ch = terminal:input:LEFTCURSORONE {
			decreaseHeading().
		}
		if ch = terminal:input:RIGHTCURSORONE {
			set requestedHeading to requestedHeading + dHeading.
			if requestedHeading >= 360 {
				set requestedHeading to requestedHeading - 360.
			}
			set requestedHeading to floor(requestedHeading/5) * 5.
			print "New heading: " + requestedHeading.
			set headingTextField:text to "" + requestedHeading.
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
		if ch = "0" {
			set isDriving to not isDriving.
			if isDriving {
				print "driving mode.".
			}
			else {
				print "flying mode.".
			}
		}
		
		set altiOrSpeedChanged to false.
		if ch = terminal:input:DOWNCURSORONE {
		
			set requestedAlt to requestedAlt - altitudeIncrement.
			set altiOrSpeedChanged to true.
			set altitudeTextField:text to ""+ requestedAlt.
		}
		if ch = terminal:input:UPCURSORONE {

			set requestedAlt to requestedAlt + altitudeIncrement.
			set altiOrSpeedChanged to true.
			set altitudeTextField:text to "" + requestedAlt.
		}
		
		if ch = "+" {
			set requestedCruiseSpeed to requestedCruiseSpeed + speedIncrement.
			set altiOrSpeedChanged to true.
			set speedTextField:text to "" + requestedCruiseSpeed.
		}
		if ch = "-" {
			set requestedCruiseSpeed to requestedCruiseSpeed - speedIncrement.
			set altiOrSpeedChanged to true.
			set speedTextField:text to "" + requestedCruiseSpeed.
		}
		
		
		if altiOrSpeedChanged {
			print "Target altitude : " + requestedAlt + "m; target speed: " + requestedCruiseSpeed + "m/s.".
		}
		
		
		if ch = "v" {
			print "Current vario: " + ship:verticalSpeed + ", target vario: " + requestedVario.
		}
		
		if ch = "t" {
			// Compute custom heading to go straight to target, following a great circle of the planet.
			if HASTARGET and not isFollowingTarget {
				// set requestedHeading to getHeadingForTarget().
				set isFollowingTarget to true.
				print "Follow target: " + target.
			}
			else {
				// Go back to a keypad-controlled heading
				set isFollowingTarget to false.
				set requestedHeading to -ship:bearing.
				set requestedHeading to floor(requestedHeading/5) * 5.
				print "No target. Requested heading : " + requestedHeading.
				// print "current heading : " + requestedHeading.
			}
		}
		
		if ch = "d" {
			print "Estimated flight duration: " + remainingFlightDuration + ", expected currentRange: " + (currentRange/1000) + "km".
		}
		if ch = "f" {
			set currentSpeed to ship:velocity:surface:mag. // speed in m/s
			set instantFuelConsumption to 0.
			list engines in engineList.
			for engine in engineList{
				set instantFuelConsumption to instantFuelConsumption + engine:fuelFlow.
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
		
		if ch = "h" {
			set isGoingHome to not isGoingHome.
			
			if isGoingHome {
				// Align on the runway facing west in preparation for landing.
				print "going home.".
			}
			else {
				print "Not going home yet.".
			}
		}
		
		if isGoingHome {
			// override altitude and heading commands
			set currentSector to getApproachSector().
			
			if currentSector = "A" {
				set latitudeDifference to ship:latitude - terrainLatitude.
				set targetHeading to 90 + latitudeDifference.
				set requestedAlt to terrainAltitude + 200.
			}
			else if currentSector = "B" {
				if ship:latitude > terrainLatitude {
					// B north
					set targetHeading to 135.
				}
				else {
					// B south
					set targetHeading to 45.
				}
				set requestedAlt to terrainAltitude + 400.
			}
			else if currentSector = "C" {
				set targetHeading to 270.
				set requestedAlt to terrainAltitude + 600.
			}
			else if currentSector = "D" {
				if ship:latitude > terrainLatitude {
					// D north
					set targetHeading to 0.
				}
				else {
					// D south
					set targetHeading to 180.
				}
				set requestedAlt to terrainAltitude + 600.
			}
			else if currentSector = "E" {
				// go for landing
			}
		}
		
		if ch = "l" {
			print "Current latitude: " + ship:latitude.
			print "Current longitude: " + ship:longitude.
		}
		
		if ch = "w" {
			// Toggle GUI
			if isGuiVisible {
				my_gui:HIDE().
			}
			else {
				my_gui:SHOW().
			}
			set isGuiVisible to not isGuiVisible.
		}
		
		if ch = "q" {
			print "Exit.".
			my_gui:HIDE().
			sas on.
			set exit to true.
		}
	}
	
	
	// Wait
	set now to time:seconds.
	wait until time:seconds > now + dt.
	
	set timeSinceLastDisplay to timeSinceLastDisplay + dt.
	
	if timeSinceLastDisplay > timeBetweenDisplays {
		set timeSinceLastDisplay to 0.
		// display stuff
		// print "altitude: " + ship:altitude + ", target: " + requestedAlt + ", requested vario: " + requestedVario + ", currentError: " + currentError.
	}
}


set ship:control:wheelsteer to 0.