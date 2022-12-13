
[Setting hidden]
bool S_Enabled = true;

enum Mode {
    SyncGhostToNoRespawnTime,
    SyncGhostToCheckpoint
}

// disable second mode for the moment.
[Setting hidden]
Mode S_Mode = Mode::SyncGhostToNoRespawnTime;

[SettingsTab name="General" icon="SnapchatGhost"]
void RenderGeneralSettings() {
    UI::AlignTextToFramePadding();
    S_Enabled = UI::Checkbox("Enabled?", S_Enabled);
    UI::SameLine();
    UI::Text("\\$bbbNote: only works in Solo mode.");
    UI::Separator();
    UI::AlignTextToFramePadding();
    UI::Text("MODE");
    if (UI::BeginCombo("##mode", tostring(S_Mode))) {
        if (UI::Selectable("Sync Ghosts to No-Respawn Time", S_Mode == Mode::SyncGhostToNoRespawnTime)) {
            S_Mode = Mode::SyncGhostToNoRespawnTime;
        }
        if (UI::Selectable("Sync Ghosts to Checkpoints", S_Mode == Mode::SyncGhostToCheckpoint)) {
            S_Mode = Mode::SyncGhostToCheckpoint;
        }
        UI::EndCombo();
    }
    UI::AlignTextToFramePadding();
    UI::Text("Description");
    UI::TextWrapped(ModeDescription(S_Mode));
    UI::Separator();
}

const string ModeDescription(Mode m) {
    switch (m) {
        case Mode::SyncGhostToNoRespawnTime:
            return "When you respawn, ghosts will be rewound by the amount of time you lost. Basically, they'll be at the same point they were when you went through the last CP for the first time.";
        case Mode::SyncGhostToCheckpoint:
            return "When you pass through a CP or respawn, ghosts will be synchronized to your no-respawn checkpoint time. This means that, regardless of where the ghosts where before you pass through a CP, they will all be updated to pass through the CP at the same time as you. It's similar to the partial PB ghosts you sometimes get that last from the current CP to the next CP, except it works for all loaded ghosts.\n\nNote: although this plugin works for most ghosts (records, particularly), it will not work for medal ghosts, and your PB ghost will probably disappear too (so turn that on in records if you want it).";
    }
    return "Boop blop you found a bug.";
}
