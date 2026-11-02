foreach p {route.enableHoldFixing route.enableHoldExpnBailout route.enableHoldFix} {
    if {[catch {set v [get_param $p]} e]} { puts "$p: unavailable" } else { puts "$p=$v" }
}
exit
