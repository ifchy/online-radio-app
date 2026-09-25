# API Coverage — Phase 1 platform SDK surfaces

> Full coverage by default; every opt-out below is an explicit, reasoned decision.
> Phase 1 integrates no third-party web API. The Radio Browser API is Phase 2 (CAT-05), and station streams are media endpoints, not an API. What it does integrate is the Android media stack through three plugins: audio_service (AudioHandler / MediaSession / MediaBrowserService), audio_session (audio focus) and connectivity_plus (network state). Their capability surfaces are recorded here so that every capability not built in Phase 1 is a visible decision. The just_audio player surface sits behind the `StreamPlayer` port and is covered by the explicit-source and no-seek rules in the plans.

## audio_service — AudioHandler / MediaSession (0.18.19)

| capability | decision | reason |
|---|---|---|
| audio_service.play | INTEGRATE | |
| audio_service.pause | INTEGRATE | |
| audio_service.stop | INTEGRATE | |
| audio_service.click (media button) | INTEGRATE | |
| audio_service.playFromMediaId | INTEGRATE | |
| audio_service.skipToNext | INTEGRATE | |
| audio_service.skipToPrevious | INTEGRATE | |
| audio_service.onTaskRemoved | INTEGRATE | |
| audio_service.onNotificationDeleted | INTEGRATE | |
| audio_service.playbackState | INTEGRATE | |
| audio_service.mediaItem | INTEGRATE | |
| audio_service.getChildren | OPT-OUT | not needed yet: the Android Auto browse tree is v1.1 (AUTO-01); the media-ID scheme it will use is shaped in 01-01 |
| audio_service.getMediaItem | OPT-OUT | not needed yet: Android Auto browse (v1.1) |
| audio_service.subscribeToChildren | OPT-OUT | not needed yet: Android Auto browse (v1.1) |
| audio_service.search | OPT-OUT | not needed yet: voice/car search is v1.1 and will reuse the Phase 2 search index |
| audio_service.playFromSearch | OPT-OUT | not needed yet: "play <station>" voice commands are v1.1 |
| audio_service.prepareFromSearch | OPT-OUT | not needed yet: voice search is v1.1 |
| audio_service.prepare | OPT-OUT | not needed: pre-buffering a live stream before a user play holds a socket and battery and gives stale audio (live-edge rule, PLAY-11) |
| audio_service.prepareFromMediaId | OPT-OUT | not needed: same live-edge and battery reason as prepare |
| audio_service.prepareFromUri | OPT-OUT | explicitly out of scope: the app plays only curated stations by id, never arbitrary URIs from other apps (official streams only) |
| audio_service.playFromUri | OPT-OUT | explicitly out of scope: same content-rights reason as prepareFromUri |
| audio_service.playMediaItem | OPT-OUT | not needed: playFromMediaId is the single entry path for UI, Bluetooth and notification |
| audio_service.queue (add/insert/update/remove/skipToQueueItem/queueTitle) | OPT-OUT | not needed yet: exposing the station order to system UIs comes with favourites order and PLAY-04 in Phase 3 |
| audio_service.updateMediaItem | OPT-OUT | not needed: MediaItems are produced only by the engine from station and ICY data |
| audio_service.seek / seekForward / seekBackward | OPT-OUT | explicitly out of scope: live radio has no seek bar (PLAY-11) |
| audio_service.fastForward / rewind | OPT-OUT | explicitly out of scope: live radio (PLAY-11) |
| audio_service.setSpeed | OPT-OUT | explicitly out of scope: live radio plays at 1x |
| audio_service.setRepeatMode / setShuffleMode | OPT-OUT | not applicable: a live stream has no track list to repeat or shuffle |
| audio_service.setRating / ratingStyle | OPT-OUT | not needed: favourites (Phase 3) are an in-app library feature, not a MediaSession rating |
| audio_service.setCaptioningEnabled | OPT-OUT | not applicable: audio-only content |
| audio_service.customAction / customEvent / customState | OPT-OUT | not needed yet: Phase 1 notification shows Play/Pause + Stop only (D-12) |
| audio_service.remote volume (androidSet/AdjustRemoteVolume, androidPlaybackInfo) | OPT-OUT | not needed yet: local playback only; Chromecast is a later milestone (SURF-03) |

## audio_session — focus and routing (0.2.4)

| capability | decision | reason |
|---|---|---|
| audio_session.configure (music) | INTEGRATE | |
| audio_session.setActive(false) (abandon focus) | INTEGRATE | |
| audio_session.interruptionEventStream | INTEGRATE | |
| audio_session.becomingNoisyEventStream | INTEGRATE | |
| audio_session.devicesChangedEventStream | OPT-OUT | not needed: becoming-noisy already covers unplug and Bluetooth disconnect (PLAY-06); per-device routing is not a v1 feature |

## connectivity_plus — network state (7.3.1)

| capability | decision | reason |
|---|---|---|
| connectivity_plus.onConnectivityChanged | INTEGRATE | |
| connectivity_plus.checkConnectivity | INTEGRATE | |
