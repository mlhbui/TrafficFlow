globals
[
  grid-x-inc               ;; the amount of patches in between two roads in the x direction
  grid-y-inc               ;; the amount of patches in between two roads in the y direction
  acceleration             ;; the constant that controls how much a car speeds up or slows down by if
                           ;; it is to accelerate or decelerate
  phase                    ;; keeps track of the phase
  num-cars-stopped         ;; the number of cars that are stopped during a single pass thru the go procedure
  current-light            ;; the currently selected light

  ;; patch agentsets
  intersections ;; agentset containing the patches that are intersections
  roads         ;; agentset containing the patches that are roads
  
  dynamic-lights?          ;; NEW variable to make adjustments to lights?
]

turtles-own
[
  speed     ;; the speed of the turtle
  up-car?   ;; true if the turtle moves downwards and false if it moves to the right
  wait-time ;; the amount of time since the last time a turtle has moved
]

patches-own
[
  intersection?   ;; true if the patch is at the intersection of two roads
  green-light-up? ;; true if the green light is above the intersection.  otherwise, false.
                  ;; false for a non-intersection patches.
  my-row          ;; the row of the intersection counting from the upper left corner of the
                  ;; world.  -1 for non-intersection patches.
  my-column       ;; the column of the intersection counting from the upper left corner of the
                  ;; world.  -1 for non-intersection patches.
  my-phase        ;; the phase for the intersection.  -1 for non-intersection patches.
  auto?           ;; whether or not this intersection will switch automatically.
                  ;; false for non-intersection patches.
  waiting-cars    ;; NEW variable to track the number of waiting cars at the intersection

]


;;;;;;;;;;;;;;;;;;;;;;
;; Setup Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;

;; Initialize the display by giving the global and patch variables initial values.
;; Create num-cars of turtles if there are enough road patches for one turtle to
;; be created per road patch. Set up the plots.
to setup
  clear-all
  setup-globals

  ;; First we ask the patches to draw themselves and set up a few variables
  setup-patches
  make-current one-of intersections
  label-current

  set-default-shape turtles "car"

  if (num-cars > count roads)
  [
    user-message (word "There are too many cars for the amount of "
                       "road.  Either increase the amount of roads "
                       "by increasing the GRID-SIZE-X or "
                       "GRID-SIZE-Y sliders, or decrease the "
                       "number of cars by lowering the NUMBER slider.\n"
                       "The setup has stopped.")
    stop
  ]

  ;; Now create the turtles and have each created turtle call the functions setup-cars and set-car-color
  create-turtles num-cars
  [
    setup-cars
    set-car-color
    record-data
  ]

  ;; give the turtles an initial speed
  ask turtles [ set-car-speed ]

  reset-ticks
end

;; Initialize the global variables to appropriate values
to setup-globals
  set current-light nobody ;; just for now, since there are no lights yet
  set phase 0
  set num-cars-stopped 0
  set grid-x-inc world-width / grid-size-x
  set grid-y-inc world-height / grid-size-y

  ;; don't make acceleration 0.1 since we could get a rounding error and end up on a patch boundary
  set acceleration 0.099
end

;; Make the patches have appropriate colors, set up the roads and intersections agentsets,
;; and initialize the traffic lights to one setting
to setup-patches
  ;; initialize the patch-owned variables and color the patches to a base-color
  ask patches
  [
    set intersection? false
    set auto? false
    set green-light-up? true
    set my-row -1
    set my-column -1
    set my-phase -1
    set pcolor brown + 3
  ]

  ;; initialize the global variables that hold patch agentsets
  set roads patches with
    [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0) or
    (floor((pycor + max-pycor) mod grid-y-inc) = 0)]
  set intersections roads with
    [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0) and
    (floor((pycor + max-pycor) mod grid-y-inc) = 0)]

  ask roads [ set pcolor white ]
  setup-intersections
end

;; Give the intersections appropriate values for the intersection?, my-row, and my-column
;; patch variables.  Make all the traffic lights start off so that the lights are red
;; horizontally and green vertically.
to setup-intersections
  ask intersections
  [
    set intersection? true
    set green-light-up? true
    set my-phase 0
    set auto? true
    set my-row floor((pycor + max-pycor) / grid-y-inc)
    set my-column floor((pxcor + max-pxcor) / grid-x-inc)
    set-signal-colors
  ]
end

;; Initialize the turtle variables to appropriate values and place the turtle on an empty road patch.
to setup-cars  ;; turtle procedure
  set speed 0
  set wait-time 0
  put-on-empty-road
  ifelse intersection?
  [
    ifelse random 2 = 0
    [ set up-car? true ]
    [ set up-car? false ]
  ]
  [
    ; if the turtle is on a vertical road (rather than a horizontal one)
    ifelse (floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0)
    [ set up-car? true ]
    [ set up-car? false ]
  ]
  ifelse up-car?
  [ set heading 180 ]
  [ set heading 90 ]
end

;; Find a road patch without any turtles on it and place the turtle there.
to put-on-empty-road  ;; turtle procedure
  move-to one-of roads with [not any? turtles-on self]
end


;;;;;;;;;;;;;;;;;;;;;;;;
;; Runtime Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;;;

;; Run the simulation
to go

  update-current

  ;; have the intersections change their color
  set-signals
  set num-cars-stopped 0

  ;; set the turtles speed for this time thru the procedure, move them forward their speed,
  ;; record data for plotting, and set the color of the turtles to an appropriate color
  ;; based on their speed
  ask turtles [
    set-car-speed
    fd speed
    record-data
    set-car-color
  ]

  ;; update the phase and the global clock
  next-phase
  tick
end

to choose-current
  if mouse-down?
  [
    let x-mouse mouse-xcor
    let y-mouse mouse-ycor
    if [intersection?] of patch x-mouse y-mouse
    [
      update-current
      unlabel-current
      make-current patch x-mouse y-mouse
      label-current
      stop
    ]
  ]
end

;; Set up the current light and the interface to change it.
to make-current [light]
  set current-light light
  set current-phase [my-phase] of current-light
  set current-auto? [auto?] of current-light
end

;; update the variables for the current light
to update-current
  ask current-light [
    set my-phase current-phase
    set auto? current-auto?
  ]
end

;; label the current light
to label-current
  ask current-light
  [
    ask patch-at -1 1
    [
      set plabel-color black
      set plabel "current"
    ]
  ]
end

;; unlabel the current light (because we've chosen a new one)
to unlabel-current
  ask current-light
  [
    ask patch-at -1 1
    [
      set plabel ""
    ]
  ]
end

;; have the traffic lights change color if phase equals each intersections' my-phase
to set-signals
  ask intersections with [auto? and phase = floor ((my-phase * ticks-per-cycle) / 100)]
  [
    set green-light-up? (not green-light-up?)
    set-signal-colors
  ]
end

;; This procedure checks the variable green-light-up? at each intersection and sets the
;; traffic lights to have the green light up or the green light to the left.
to set-signal-colors  ;; intersection (patch) procedure
  ifelse power?
  [
    ifelse green-light-up?
    [
      ask patch-at -1 0 [ set pcolor red ]
      ask patch-at 0 1 [ set pcolor green ]
    ]
    [
      ask patch-at -1 0 [ set pcolor green ]
      ask patch-at 0 1 [ set pcolor red ]
    ]
  ]
  [
    ask patch-at -1 0 [ set pcolor white ]
    ask patch-at 0 1 [ set pcolor white ]
  ]
end

;; set the turtles' speed based on whether they are at a red traffic light or the speed of the
;; turtle (if any) on the patch in front of them
to set-car-speed  ;; turtle procedure
  ifelse pcolor = red
  [ set speed 0 ]
  [
    ifelse up-car?
    [ set-speed 0 -1 ]
    [ set-speed 1 0 ]
  ]
end

;; set the speed variable of the car to an appropriate value (not exceeding the
;; speed limit) based on whether there are cars on the patch in front of the car
to set-speed [ delta-x delta-y ]  ;; turtle procedure
  ;; get the turtles on the patch in front of the turtle
  let turtles-ahead turtles-at delta-x delta-y

  ;; if there are turtles in front of the turtle, slow down
  ;; otherwise, speed up
  ifelse any? turtles-ahead
  [
    ifelse any? (turtles-ahead with [ up-car? != [up-car?] of myself ])
    [
      set speed 0
    ]
    [
      set speed [speed] of one-of turtles-ahead
      slow-down
    ]
  ]
  [ speed-up ]
end

;; decrease the speed of the turtle
to slow-down  ;; turtle procedure
  ifelse speed <= 0  ;;if speed < 0
  [ set speed 0 ]
  [ set speed speed - acceleration ]
end

;; increase the speed of the turtle
to speed-up  ;; turtle procedure
  ifelse speed > speed-limit
  [ set speed speed-limit ]
  [ set speed speed + acceleration ]
end

;; set the color of the turtle to a different color based on how fast the turtle is moving
to set-car-color  ;; turtle procedure
  ifelse speed < (speed-limit / 2)
  [ set color blue ]
  [ set color cyan - 2 ]
end

;; keep track of the number of stopped turtles and the amount of time a turtle has been stopped
;; if its speed is 0
to record-data  ;; turtle procedure
  ifelse speed = 0
  [
    set num-cars-stopped num-cars-stopped + 1
    set wait-time wait-time + 1
  ]
  [ set wait-time 0 ]
end

to change-current
  ask current-light
  [
    set green-light-up? (not green-light-up?)
    set-signal-colors
  ]
end

;; cycles phase to the next appropriate value
to next-phase
  ;; The phase cycles from 0 to ticks-per-cycle, then starts over.
  set phase phase + 1
  if phase mod ticks-per-cycle = 0
    [ set phase 0 ]
end




to count-waiting-cars

 ;; Loop through all the turtles (cars)
 ask turtles [
   ;; Check if the car is stopped and is near an intersection
   if speed = 0 and distance patch-here < grid-y-inc [
     set waiting-cars waiting-cars + 1  ;; Increment the counter if conditions are met
   ]
 ]

 ;; Report the number of waiting cars
 show waiting-cars
end

to label-intersections-with-waiting-cars
 ask intersections [
   set plabel (word "Waiting: " waiting-cars)
 ]
end


;; observer procedure to count cars in proximity to patch (intersection), OLD BUT WORKS?
to count-waiting-cars-at-intersection-1 [target-x target-y]
 let specific-patch patch target-x target-y  ;; input coordinates for the specific patch
 let waiting-cars-count 0
 let threshold-distance 10  ;; CHANGE depending on grid size (distance = proximity)
 ;; Loop through all cars
 ask turtles [
   ;; Check if the car is near the specific patch and is stopped
   if (distance specific-patch < threshold-distance) and (speed = 0) [
     set waiting-cars-count waiting-cars-count + 1  ;; Increment
   ]
 ]

 ;; Report the number of waiting cars near the specific patch
 show (word "Waiting cars near patch (" target-x ", " target-y "): " waiting-cars-count)
end

to update-waiting-cars
  ;; Loop through each intersection to count waiting cars
  ask intersections [
    let count1 0
    ;; Loop through all turtles (cars) to count those that are waiting at this intersection
    ask turtles with [speed = 0 and distance patch-here < grid-y-inc] [
      set count1 count1 + 1
    ]
    set waiting-cars count1 ;; Update the intersection's waiting cars count
  ]
end

to set-signals-REF
 ask intersections with [auto? and phase = floor ((my-phase * ticks-per-cycle) / 100)]
 [
   set green-light-up? (not green-light-up?)
   set-signal-colors
 ]
end

;; WORKS!! YAY so essentially define distance to account for (arbitrarily 10) 
;; adjust light timing based on waiting counts in vertical and horizontal direction
to set-signals-1
  ask intersections with [auto? and phase = floor ((my-phase * ticks-per-cycle) / 100)] [
    let threshold-distance 10  ;; Distance threshold to count cars as "waiting"
    let intersection-patch patch pxcor pycor  ;; The patch of this intersection

    ;; x-axis tracking (up-down)
    let waiting-cars-x count turtles with [
      speed = 0 and distance intersection-patch <= threshold-distance and pxcor = [pxcor] of intersection-patch
    ]

    ;; y-axis tracking (L->R)
    let waiting-cars-y count turtles with [
      speed = 0 and distance intersection-patch <= threshold-distance and pycor = [pycor] of intersection-patch
    ]

    ;; Switch the light if one side exceeds set car number (arbitrarily 5_
    if green-light-up? and waiting-cars-y >= 5 [
      set green-light-up? false  
      set-signal-colors
    ] 
    if not green-light-up? and waiting-cars-x >= 5 [
      set green-light-up? true 
      set-signal-colors
    ]
  ]
end




;; Prints all cars at a specific intersection based on target's coorginates
to-report count-waiting-cars-at-intersection [target-row target-column]
  ;; Find the specific patch based on the row and column
  let specific-patch patch (target-column * grid-x-inc) (target-row * grid-y-inc)
  let waiting-cars-count 0
  let threshold-distance 10  ;; Distance threshold 

  ;; Loop cars and checks distance to the intersection
  ask turtles [
    if (distance specific-patch < threshold-distance) and (speed = 0) [ ;; Check if stopped and near the intersection
      set waiting-cars-count waiting-cars-count + 1
    ]
  ]

  ;; Report the number of waiting cars near the intersection
  report waiting-cars-count
end

;; Helper: Prints all cars at intersections on a 2x2 grid NOT dynamic
to check-intersection-counts
  let waiting-at-1-1 count-waiting-cars-at-intersection 1 1
  let waiting-at--1-1 count-waiting-cars-at-intersection -1 1
  let waiting-at--1--18 count-waiting-cars-at-intersection -1 -18
  let waiting-at-18--18 count-waiting-cars-at-intersection 18 -18
  
  ;; Display 
  show (word "Waiting cars at intersection (1, 1): " waiting-at-1-1)
  show (word "Waiting cars at intersection (-1, 1): " waiting-at--1-1)
  show (word "Waiting cars at intersection (-1, -18): " waiting-at--1--18)
  show (word "Waiting cars at intersection (18, -18): " waiting-at-18--18)
end

;; Helper: Ask all intersection patches to print location
to show-intersection-list
 ask patches with [intersection?] [
   show (word "intersection (" my-row ", " my-column ") ")
 ]
end

;; Helper: Num for all cars stopped 
to count-stopped-cars-all
 let stopped-cars count turtles with [speed = 0]
 show stopped-cars
end

;; Currently the same as above use later??
to-report count-waiting-cars-all-2
 ;; MIGHT USE FOR PROXIMITY
 report count turtles with [
   speed = 0 and distance patch-here < grid-y-inc
 ]
end
