# Food Maze Adventure — integration brief

Continue the existing Flutter Android / iOS project. First read the real source, identify the renderer, level configuration, gesture ownership and both update loops. Do not start a new project or restore the arrow puzzle. The existing code was not supplied with this kit; treat suggested causes as hypotheses, not verified bugs. Save a baseline and preserve unlocked levels, saves, joystick behavior and the working maze path drawing.

## 1. Assign 50 identities by level, not 5 identities by district

Use `level_roster.csv` as the explicit list of levels 1–50 and their art files, gait and attack targets. Districts control setting, not enemy identity. No integer division by 10 for choosing a monster. Add a data test: exactly 50 levels, 50 distinct primary model IDs and 50 valid asset paths. Use the pose and silhouette in the board, not one generic model recolored 50 ways. Keep normal monster IDs and boss IDs separate. The three `03_Boss_Studies` assets are examples, not the full set of 50 final bosses. Do not silently cycle these three across all levels as a completed boss campaign.

## 2. Repair finger-drawn movement in the road battle

Reproduce on a touch device: reach Truck Defense, wait for a boss attack, start a drag near the visible Courier, draw a curved route past the truck, release. The reported regression is road-specific; the maze already works. Inspect gesture ownership (road overlay vs gameplay layer), stage gating, whether a route is stored, whether the road update loop consumes it, and whether hit/attack/escort AI clears or overwrites it each tick. Trace stage, pointer id, coordinate conversion, accepted waypoints, route index, cancellation reason and movement owner.

Share the route follower, not the maze collision map. Give the road its own walkable boundaries and obstacles. Convert each touch sample into road-world coordinates with the current camera (inverse camera transform or ground-plane hit test, depending on the renderer). Store world waypoints so a moving camera cannot move the route. Draw the remaining path from the same world data. Start drags on the Courier with some touch tolerance; keep joystick and action buttons out of route capture. A second pointer on Attack must not end the initial drawing pointer.

Truck autopilot and boss targeting must not commandeer the Courier's movement. A normal attack plays without clearing a legal route. A real stun/knockback temporarily suspends movement; retain the route, then safely rejoin the next reachable segment or show that a new route is needed. Never teleport, cross the truck, or substitute an unrelated shortcut. Joystick input cancels auto-follow; a new drawing replaces the old route. Pause freezes it; resume continues it. If the truck blocks the path, stop at the last safe point or resume when clear. Do not freeze the truck or boss during dragging.

Regression tests: (1) two-turn maze route before/after patch; (2) same road route with static then scrolling camera; (3) draw before and during a boss attack; (4) attack, stun and recover while following; (5) second finger on Attack; (6) joystick override, pause, invalid route, and stage exit. Record one Android or iOS gameplay clip demonstrating the fix; report only tests actually performed.

## 3. Replace generic fighting, not only the graphics

The GLB files include starting node-keyframe clips named Travel, Attack, and HitReact (static props are excluded). They are illustrative blocking, not final motion-capture or finished combat. Look at poses in motion, then refine character-specific Idle, Travel, Wind-up, Strike/Release, Recovery, HitReact and Defeated states. The roster lists intended movement and attack, not proof of finished gameplay behavior.

Courier: plant feet or maintain moving legs, raise bow, draw with the opposite hand, release visibly, recover. Arc and travel of a projectile must be visible; damage on confirmed collision, not when the shot button is pressed. Dock Worker: peaceful loading model before escape; switch to the blade version after escape. Turn shoulder and hips, swing through a clearly readable arc, return to guard. Thorn Ravager: heavy steps, raised fists and a warned ground slam; Lantern Leviathan: stagger the three heads; Ironbell Colossus: slower piston-arm strikes and a long recovery. These are distinct target performances that need in-game implementation. A damage event must fire only once per valid connection. Avoid a shared forward-lean loop for every monster. Confirm in normal-speed and slow-motion capture.

## 4. Give the whole screen a coherent 3D toy-diorama look

Use the two full-screen reference compositions in `04_Style_Boards/Gameplay_Screens.png`. Raised hedges with a lighter top, grounded soft shadows, visibly rounded fruit, consistent 3/4 viewpoint, and distinct silhouettes. Keep the HUD simple and readable instead of beveling every label. Maze and road occupy the large center viewport; avoid one cramped screen for both phases. Keep floor routes, pickups and threats visible behind taller objects. Use transparent 3D renders / directional sprite atlases if the current game is 2D, or animated GLBs only after confirming renderer support. Do not introduce a 3D engine just to show the mockup. A single PNG is not an animation. Treat the boards as art references, not templates to hard-code into the game.

Deliver a source diff, an asset-to-level mapping, before/after gameplay captures, test results and a short list of unfinished work. Check portrait screens 360×640 and 360×800. Profile on an actual target device before increasing draw calls or shipping many models; load only currently required assets. Do not claim 50 bespoke boss fights or finished animation from the existence of these assets.
