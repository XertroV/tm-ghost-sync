void Main() {
    startnew(MainCoro);
}

void MainCoro() {
    while (true) {
        yield();
        while (!S_Enabled || PlaygroundScriptNull) yield();
        OnEnteredPlayground();
    }
}

// light / mid-light / mid gray
const string lg = "\\$ddd";
const string mlg = "\\$bbb";
const string mg = "\\$999";
const string MENU_NAME = lg + Icons::User + mlg + Icons::ArrowsH + mg + Icons::SnapchatGhost + " \\$z" + Meta::ExecutingPlugin().Name;

/** Render function called every frame intended only for menu items in `UI`. */
void RenderMenu() {
    if (UI::MenuItem(MENU_NAME, "", S_Enabled)) {
        S_Enabled = !S_Enabled;
    }
}


bool PlaygroundScriptNull {
    get {
        return GetApp().PlaygroundScript is null;
    }
}

void OnEnteredPlayground() {
    if (GetApp().RootMap is null) return;
    auto rd = MLFeed::GetRaceData_V2();
    auto gd = MLFeed::GetGhostData();
    string playersName = MLFeed::LocalPlayersName;
    while (playersName == "") {
        yield();
        playersName = MLFeed::LocalPlayersName;
    }
    auto mapUid = GetApp().RootMap.MapInfo.MapUid;
    if (rd.SortedPlayers_Race.Length == 0) return;
    auto localPlayer = rd.SortedPlayers_Race[0];
    if (!localPlayer.IsLocalPlayer) warn("MLFeed doesn't think this is the local player");
    // need ghosts to do anything
    while (!PlaygroundScriptNull && gd.Ghosts_V2.Length == 0) yield();
    // main loop
    uint lastRespawns = localPlayer.NbRespawnsRequested;
    uint lastCPs = localPlayer.CpCount;
    uint lastStartTime = localPlayer.StartTime;
    while (S_Enabled && !PlaygroundScriptNull && GetApp().RootMap !is null && mapUid == GetApp().RootMap.MapInfo.MapUid) {
        yield();
        if (rd.SortedPlayers_Race.Length == 0) break;
        @localPlayer = rd.SortedPlayers_Race[0];
        // watch for respawns or CPs
        if (lastRespawns == localPlayer.NbRespawnsRequested && lastCPs == localPlayer.CpCount && lastStartTime == localPlayer.StartTime) continue;
        // we got a respawn or checkpoint
        lastRespawns = localPlayer.NbRespawnsRequested;
        lastCPs = localPlayer.CpCount;
        lastStartTime = localPlayer.StartTime;
        // ignore if we're setting back to 0 -- server handles ghost sync
        // if (lastRespawns == 0 && lastCPs == 0) continue;
        // when a player respawns, sync ghosts
        SyncGhosts(localPlayer);
    }
}

void SyncGhosts(const MLFeed::PlayerCpInfo_V2@ player) {
    yield();
    auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    if (ps is null) return;
    auto gd = MLFeed::GetGhostData();
    // Notify("Syncing ghosts.");

    int ghostTime = player.CurrentRaceTime - player.TimeLostToRespawns;
    // we want to set the ghosts start time according to the mode.
    if (S_Mode == Mode::SyncGhostToNoRespawnTime) {
        // in this mode, when the player loses X seconds to a respawn, we rewind the ghost by X seconds.
        ps.Ghosts_SetStartTime(ps.Now - ghostTime);
        // Notify("Start time: " + (ps.Now - ghostTime));
    } else if (S_Mode == Mode::SyncGhostToCheckpoint) {
        // in this mode, when the player passes through a checkpoint or respawns, we rewind the ghost to the point that it went through the same checkpoint.
        // mode disabled atm b/c can't be selected via settings
        throw('todo');
        if (GetApp().Network.ClientManiaAppPlayground is null) return;
        auto dfm = GetApp().Network.ClientManiaAppPlayground.DataFileMgr;
        if (dfm is null) return;
        // indexes for ghost info and ghosts. They might not line up exactly, but they will be in the same order.
        uint gi = 0, g = 0;
        while (gi < gd.Ghosts_V2.Length && g < dfm.Ghosts.Length) {
            auto ghost = dfm.Ghosts[g];
            auto ghostInfo = gd.Ghosts_V2[gi];
            if (ghost.Id.Value < ghostInfo.IdUint) {
                g++;
                continue;
            } else if (ghost.Id.Value > ghostInfo.IdUint) {
                gi++;
                continue;
            } else {
                // match
                // ps.Ghost_Remove(ghost.Id);
                // ghostOffset = player.CurrentRaceTime
                // ps.Ghost_AddWithOffset(ghost, true, )
            }
        }
        for (uint g = 0; g < gd.Ghosts_V2.Length; g++) {

            auto ghost = gd.Ghosts_V2[g];
            ghostTime = player.CpCount > 0 ? ghost.Checkpoints[player.CpCount - 1] : 0;
            // todo, need to set ghost offset -- do we tho? why?
            // yes b/c we set the start time for all ghosts
            // todo: introduce lookup by ID in MLFeed (so we can go from CGhost -> GhostInfo)
            // wait: ghosts are in same order!

            // that way we can get CP times
            // then we can set the offset for that particular ghost

        }
    }
}


void Notify(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    trace("Notified: " + msg);
}
