
[Setting category="General" name="Enabled"]
bool S_Enabled = true;



enum Mode {
    SyncGhostToNoRespawnTime,
    SyncGhostToCheckpoint
}

// disable second mode for the moment.
// [Setting category="General" name="Mode"]
Mode S_Mode = Mode::SyncGhostToNoRespawnTime;
