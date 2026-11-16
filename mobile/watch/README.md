# HitnScore for Apple Watch

Personal Plus users can score Squash, Racketball, Tennis and Padel from
Apple Watch once the match is live. Create the match in HitnScore on a phone,
tablet or laptop, then open it in the paired iPhone’s live scorer. Complete
any warm-up and opening serve or receive selection on the iPhone. Keep that
scoring screen open and launch HitnScore on the watch.

Tap a player or team’s score to award a point. The watch also shows the
server and game or set totals and offers Undo when available, Squash and
Racketball let/stroke decisions, and the Padel Golden Point receiver choice.
A Personal Plus identity can use the watch in a club context where it
already has permission to operate the match. The paired iPhone needs internet
access for the Personal Plus check and must stay reachable from the watch.
After a lost connection, check the refreshed score before repeating a tap.

## Build and device check

Open [RcktScoreMobile.xcodeproj](../ios/RcktScoreMobile/RcktScoreMobile.xcodeproj)
in Xcode. Build the `RcktScoreMobile` scheme to embed the companion, or select
the `HitnScoreWatch` scheme and a paired Apple Watch to debug it. The watch
target supports watchOS 10.6 and later. Device installation requires signing
for both app targets.

On a paired iPhone and Apple Watch, run a live match and confirm both devices
show wrist-awarded points. Check a phone-awarded point, Undo, a timed break,
match completion, then repeat with the iPhone screen locked. Confirm that
Personal Free, a view-only club membership and a disconnected watch cannot
send points. For Padel Golden Point, verify that the two receiver court
choices appear before the next point can be scored.
