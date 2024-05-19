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
    if (UI::BeginMenu(MENU_NAME)) {
        if (UI::MenuItem("Enabled", "", S_Enabled)) {
            S_Enabled = !S_Enabled;
        }
        if (UI::MenuItem("Sync to No-Respawn Time", "", S_Mode == Mode::SyncGhostToNoRespawnTime)) {
            S_Mode = S_Mode == Mode::SyncGhostToNoRespawnTime ? Mode::SyncGhostToCheckpoint : Mode::SyncGhostToNoRespawnTime;
        }
        if (UI::MenuItem("Sync to Checkpoints", "", S_Mode == Mode::SyncGhostToCheckpoint)) {
            S_Mode = S_Mode == Mode::SyncGhostToNoRespawnTime ? Mode::SyncGhostToCheckpoint : Mode::SyncGhostToNoRespawnTime;
        }
        UI::EndMenu();
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
    if (rd is null || gd is null) return;
    string playersName = MLFeed::LocalPlayersName;
    if (playersName == "") return;
    auto mapUid = GetApp().RootMap.EdChallengeId;
    if (rd.SortedPlayers_Race is null || gd.Ghosts_V2 is null) return;
    if (rd.SortedPlayers_Race.Length == 0) return;
    MLFeed::PlayerCpInfo_V2@ localPlayer = rd.SortedPlayers_Race[0];
    if (!localPlayer.IsLocalPlayer) warn("MLFeed doesn't think this is the local player");
    // main loop
    uint lastRespawns = localPlayer.NbRespawnsRequested;
    int lastCPs = localPlayer.CpCount;
    uint lastStartTime = localPlayer.StartTime;
    while (S_Enabled && !PlaygroundScriptNull && GetApp().RootMap !is null && mapUid == GetApp().RootMap.EdChallengeId) {
        yield();
        if (rd.SortedPlayers_Race.Length == 0) break;
        // we're always the 1st player in solo
        @localPlayer = rd.SortedPlayers_Race[0];
        // watch for respawns or CPs
        if (lastRespawns == localPlayer.NbRespawnsRequested && lastCPs == localPlayer.CpCount && lastStartTime == localPlayer.StartTime) continue;
        // we got a respawn or checkpoint
        lastRespawns = localPlayer.NbRespawnsRequested;
        lastCPs = localPlayer.CpCount;
        lastStartTime = localPlayer.StartTime;
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
    int ghostOffs = player.TimeLostToRespawns == 0 ? S_StartGhostEarlyBy : 0;
    // we want to set the ghosts start time according to the mode.
    if (S_Mode == Mode::SyncGhostToNoRespawnTime) {
        // in this mode, when the player loses X seconds to a respawn, we rewind the ghost by X seconds.
        ps.Ghosts_SetStartTime(ps.Now - ghostTime + S_StartGhostEarlyBy);
    } else if (S_Mode == Mode::SyncGhostToCheckpoint) {
        // in this mode, when the player passes through a checkpoint or respawns, we rewind the ghost to the point that it went through the same checkpoint.
        // we don't want to do anything if the player finished
        bool playerFinished = player.CpCount == int(MLFeed::GetRaceData_V2().CPsToFinish);
        if (playerFinished) return;
        // if the player reset, we want to set the ghost starting time
        if (player.CurrentRaceTime < 0) {
            ps.Ghosts_SetStartTime(player.StartTime + S_StartGhostEarlyBy);
        }
        // first, remove all previous temporary ghosts (note: this removes other ghosts too, but you probably only have the ones you care about actually on.)
        ps.Ghost_RemoveAll();
        // efficiently (O(n)) search ghosts for cp data and update
        if (GetApp().Network.ClientManiaAppPlayground is null) return;
        auto dfm = GetApp().Network.ClientManiaAppPlayground.DataFileMgr;
        if (dfm is null) return;
        // indexes for ghost info and ghosts. They might not line up exactly, but they will be in the same order.
        uint gi = 0, g = 0;
        bool foundPB = false;
        while (gi < gd.Ghosts_V2.Length && g < dfm.Ghosts.Length) {
            auto ghost = dfm.Ghosts[g];
            auto ghostInfo = gd.Ghosts_V2[gi];
            foundPB = foundPB || ghostInfo.IsPersonalBest;
            if (ghost.Id.Value < ghostInfo.IdUint) {
                g++;
                continue;
            } else if (ghost.Id.Value > ghostInfo.IdUint) {
                gi++;
                continue;
            } else {
                // the ghost offset is how far ahead behind it should be, relative to players race time.
                // so the offset is player.CRT - ghost.CRT (generally positive if player is behind ghost)
                // we only know the ghost CRT at a checkpoint (which is the checkpoint time)
                int ghostCpTime = player.CpCount == 0 ? 0 : ghostInfo.Checkpoints[player.CpCount - 1];
                int offset = player.LastCpOrRespawnTime - ghostCpTime + S_StartGhostEarlyBy;
                auto newGhostId = ps.Ghost_AddWithOffset(ghost, true, offset);
                // dev_print("Adding ghost: " + ghostInfo.Nickname + " ("+ghostInfo.IdName+"->"+newGhostId.GetName()+") at cp " + player.CpCount + " with offset (ms): " + offset);
                g++;
                gi++;
            }
        }
    }
}


void Notify(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    trace("Notified: " + msg);
}

void dev_print(const string &in msg) {
#if DEV
    print(msg);
#endif
}
