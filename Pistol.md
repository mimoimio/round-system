| Current Phase | Duration / Timeout Trigger | Core Action (During / On Exit) | Responsible Service(s) | Next Phase |
| :--- | :--- | :--- | :--- | :--- |
| **`WaitingForPlayers`** | Continues until `AliveParticipants >= 2` | Wait for players. Wipe previous round data. | **`RoundService`** (State clearing, Phase transition) | ➔ **`Intermission`** |
| **`Intermission`** | `serverTimeNow >= TimeEnd` (e.g., 10 seconds) | Pull players into the arena. Reset everyone's `Bullets` to 0, and `IsAlive` to true. | **`RoundService`** (Phase transition)<br>**`TeleportService`** (Arena pull)<br>**`ParticipantService`** (Stats reset) | ➔ **`ActionInput`** |
| **`ActionInput`** | `serverTimeNow >= TimeEnd` (e.g., 10s) **OR** All alive players have locked in | Listen for client intent remotes. Clear previous `PendingActions` at the start of this phase. | **`RoundService`** (Phase/Lock-in checks)<br>**`InputService`** (Receiving remotes) | ➔ **`Resolution`** |
| **`Resolution`** | `workspace:GetServerTimeNow() >= TimeEnd` (e.g., 4s for animations) | Run the math. Deduct ammo, check shields vs bullets, execute kills. Check win condition. | **`RoundService`** (Phase/Win condition)<br>**`ResolutionService`** (Math/Ammo/Kills) | ➔ **`ActionInput`** (If > 1 alive)<br>➔ **`Ended`** (If <= 1 alive) |
| **`Ended`** | `workspace:GetServerTimeNow() >= TimeEnd` (e.g., 5 seconds) | Dispatch `awardWinnerCash()`. | **`RoundService`** (Phase transition)<br>**`RewardService`** (Cash distribution) | ➔ **`WaitingForPlayers`** |


"Server-Authoritative" approach. By removing the local draft state, you guarantee that the client and server never fall out of sync, even if it means the player has to wait for network ping to see their UI update. 

Here is the exact breakdown of how the controls, network, server, and rendering flow together under this strict synchronization model

### 1. The Client Input (Context Only)
The client script no longer stores what the player *plans* to do. It only stores what "tool" the player is currently holding. 

* **Keyboard (Mode Toggling):**
  * Pressing `Q`, `E`, or `R` simply changes the client's local "Cursor Mode." This does not send anything to the server yet. It just tells the mouse what to do when clicked.
* **Mouse Clicks (The Triggers):**
  * **If in Shield Mode (Q):** Left-clicking anywhere fires a remote to the server requesting `AddShield`. Right-clicking fires `RemoveShield`.
  * **If in Aim Mode (E):** The camera is locked. Hovering over Player B and left-clicking fires a remote requesting `AddTargetBullet(Player_B)`. Right-clicking fires `RemoveTargetBullet(Player_B)`.
  * **If in Load Mode (R):** Pressing this instantly fires a remote requesting `SetActionToLoad`.

### 2. The Server Validator (`InputService`)
The server receives every single click as a separate request. Because the client isn't keeping track of ammo or rules, the server must act as a strict bouncer.

When the server receives a request:
1. **Gatekeeping:** It checks if the `CurrentRound.Phase` is `ActionInput` and if the requesting player is `IsAlive`. If not, it ignores the request.
2. **Processing `AddTargetBullet(Target_ID)`:** * The server looks at the player's true state in Reflex. 
   * It counts how many bullets the player has already allocated in `PendingTargets`. 
   * If `Allocated < Total Bullets Owned`, it dispatches an action to Reflex to increment the bullet count on that specific Target_ID. 
   * It also strictly sets the player's `PendingAction` to `"Shoot"`.
3. **Processing `AddShield`:**
   * Dispatches an action to Reflex to increment `PendingShields` by 1. 
   * Sets `PendingAction` to `"Shield"`.
4. **Processing `Remove` Requests:**
   * Checks if the pending value is greater than 0 before dispatching a Reflex action to decrement it. If the value drops to 0, it clears the `PendingAction` back to `"None"`.

### 3. The Client Render (Strict Observation)
Because the client doesn't trust itself, the UI only updates when the server tells it to.

* The client has an observer listening to its own `ParticipantEntity` state broadcasted from Reflex.
* When the player clicks, nothing happens visually. 
* A fraction of a second later, the Reflex state arrives from the server. The state says `PendingShields = 1`. 
* The UI observer sees this change and draws one shield icon on the screen. 
* *Note: If a player spam-clicks 5 times but only has 2 bullets, the server will only validate 2. The UI will correctly only ever show 2 bullets allocated, completely ignoring the 3 invalid clicks.*

### 4. The Optional Lock-In
Because the server is recording every click live, locking in is no longer required to submit data. It is now just a "Ready Up" mechanic.

* **The Trigger:** The player presses Spacebar (or clicks a Ready button).
* **The Network:** The client fires a remote requesting `ToggleReadyStatus`.
* **The Server:** The server dispatches an action to Reflex setting a boolean `IsReady = true` for that player.
* **The Orchestrator:** Your `RoundService` loop, which is ticking every second, checks the state. If `TimeEnd` is reached, it moves to `Resolution`. However, if it checks the state and sees that *every* alive player has `IsReady == true`, it immediately cuts the timer short and jumps straight to `Resolution`.

This architecture is incredibly safe. It makes cheating impossible because the client is reduced to a dumb terminal that simply asks the server for permission every time the mouse is clicked.


Animations
