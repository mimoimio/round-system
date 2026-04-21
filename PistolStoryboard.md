### Storyboard 2: "Pistol" (Simultaneous Turn-Based Strategy)
**Core Concept:** A mathematical, turn-based Mexican standoff where players simultaneously allocate actions (Load, Shield, Shoot) and the server resolves the math.

* **Phase 1: Lobby & Waiting**
    * Player joins and is placed in the lobby.
    * Player waits for the round to start.
* **Phase 2: Match Start**
    * Players are teleported into the map. The match officially starts.
* **Phase 3: Action Input (Simultaneous)**
    * Player uses the keyboard to select a "Mode":
        * **Q:** Shield Mode
        * **E:** Aim (Gun) Mode
        * **R:** Load (Bullet) Mode
    * **If in Shield Mode:** Left-Click increases Shield. Right-Click decreases Shield.
    * **If in Aim Mode:** Camera locks. Move the cursor to aim at a specific player. Left-Click on a player to increase bullets allocated to them. Right-Click on a player to remove an allocated bullet.
    * **If in Load Mode:** The mouse does nothing. (Just queues a load action).
* **Phase 4: Resolution (Math Execution)**
    * Player target actions are all revealed and executed simultaneously.
    * **Rule 1 (Clashing Bullets):** *N* amount of shot bullets towards a guy will block *N* amount of incoming bullets from that specific guy. 
    * **Rule 2 (Death by Bullets):** If the amount of shot bullets is *more* than the amount of incoming bullets from an opposing guy, the opposing guy dies.
    * **Rule 3 (Strict Shielding):** *N* amount of Shield will block **ONLY *N* (equal, not more, not less)** amount of bullets from the *total* of all directions.
        * *Example A:* Guy1 shields 2. Guy2 and Guy3 each shoot 1 bullet at Guy1. (Total incoming = 2). Guy1 survives.
        * *Example B (Over-shielding):* Guy1 shields 3. Guy2 and Guy3 each shoot 1 bullet at Guy1. (Total incoming = 2). Guy1 dies.
    * **Rule 4 (Loading):** A "Load" action adds 1 bullet to the player's own inventory for future turns.
* **Phase 5: Scoring & Rewards**
    * **Kill (number):** Awarded when a player's bullet is the *only* one that kills a target.
    * **Assist (number):** Awarded whenever a player's bullet is involved in killing a target alongside others (resulting in everyone getting an assist, no one gets the kill).
* **Phase 6: End Game**
    * The last standing player is rewarded and awarded a "Win".
    * Players are sent back to the lobby, and the loop repeats.