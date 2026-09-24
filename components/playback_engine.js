// Nutsty Playback & Browse Engine (Artist Shuffle, Album/Playlist Loader, Queue & Radio Helpers)
// Extracted from shell.qml for CodeGraph AST indexing while preserving 100% QML scope compatibility.

function startRadioFromTrack(win, trk) {
    if (!trk) return;
    if (win.listeningAlongFriend && !win.isSyncingFromFriend && !win.guestCanControlHost) {
        win.suggestTrackToHost(trk);
        return;
    }
    var rVid = trk.videoId || (trk.path && trk.path.startsWith("ytdl://") ? trk.path.replace("ytdl://", "") : "");
    if (!rVid) {
        console.warn("Nutsty: startRadioFromTrack called without valid videoId", JSON.stringify(trk));
        return;
    }
    win.currentTracks = [trk];
    win.playingPlaylistId = "";
    win.playingSourceTitle = "";
    win.playOnlineTrack(trk, true);
}

function playFriendTrack(win, trk) {
    if (!trk) return;
    if (win.listeningAlongFriend && !win.isSyncingFromFriend && !win.guestCanControlHost) {
        win.suggestTrackToHost(trk);
        return;
    }
    var rVid = trk.id || trk.videoId || (trk.path && trk.path.startsWith("ytdl://") ? trk.path.replace("ytdl://", "") : "");
    if (rVid) {
        win.currentTracks = [trk];
        win.playingPlaylistId = "";
        win.playingSourceTitle = I18n.tr("Nghe cùng bạn bè", "Listening with friend");
        win.playOnlineTrack(trk, true);
    } else {
        var q = (trk.title || "") + " " + (trk.artist || "");
        if (q.trim()) {
            win.executeSearch(q.trim());
        }
    }
}

function playArtistShuffle(win, artistItem, candidateTracks) {
    if (!artistItem) return;
    if (win.listeningAlongFriend && !win.isSyncingFromFriend && !win.guestCanControlHost) {
        win.showToast(I18n.tr("Host đã khóa quyền chuyển bài hát", "Host disabled track skipping"));
        return;
    }
    var aName = artistItem.name || artistItem.title || artistItem.artist || "";
    var bId = artistItem.browseId || artistItem.channelId || "";
    win.mainSectionTitle = aName;

    var pool = [];
    if (candidateTracks && Array.isArray(candidateTracks) && candidateTracks.length > 0) {
        pool = candidateTracks.slice();
    } else if (artistItem.top_tracks && Array.isArray(artistItem.top_tracks) && artistItem.top_tracks.length > 0) {
        pool = artistItem.top_tracks.slice();
    } else if (artistItem.popular && Array.isArray(artistItem.popular) && artistItem.popular.length > 0) {
        pool = artistItem.popular.slice();
    }

    pool = pool.filter(function(t) {
        if (!t) return false;
        var vid = t.videoId || (t.path && t.path.startsWith("ytdl://") ? t.path.replace("ytdl://", "") : "");
        return (typeof ytNowPlayingView !== "undefined" && ytNowPlayingView) ? !ytNowPlayingView.isTrackDisliked(vid) : true;
    });

    if (pool.length > 0) {
        var randIdx = Math.floor(Math.random() * pool.length);
        var chosen = pool[randIdx];
        var rest = pool.filter(function(_, idx) { return idx !== randIdx; });
        for (var i = rest.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var tmp = rest[i];
            rest[i] = rest[j];
            rest[j] = tmp;
        }
        win.currentTracks = [chosen].concat(rest);
        win.playingPlaylistId = "";
        win.playingSourceTitle = aName;
        win.playOnlineTrack(chosen, false);
    }

    win.isNowPlayingOpen = true;
    if (typeof ytNowPlayingView !== "undefined" && ytNowPlayingView) {
        ytNowPlayingView.activeTab = "up_next";
    }

    var xhr = new XMLHttpRequest();
    var url = "http://127.0.0.1:17890/api/artist_shuffle?name=" + encodeURIComponent(aName) + "&browseId=" + encodeURIComponent(bId);
    xhr.open("GET", url, true);
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
            try {
                var res = JSON.parse(xhr.responseText);
                var fullTracks = (res && res.tracks) ? res.tracks : (Array.isArray(res) ? res : []);
                if (fullTracks && fullTracks.length > 0) {
                    var cur = win.currentTrack;
                    if (cur) {
                        var curVid = cur.videoId || (cur.path && cur.path.startsWith("ytdl://") ? cur.path.replace("ytdl://", "") : "");
                        var filtered = fullTracks.filter(function(t) {
                            if (!t) return false;
                            var tVid = t.videoId || (t.path && t.path.startsWith("ytdl://") ? t.path.replace("ytdl://", "") : "");
                            if (curVid && tVid && curVid === tVid) return false;
                            return (typeof ytNowPlayingView !== "undefined" && ytNowPlayingView) ? !ytNowPlayingView.isTrackDisliked(tVid) : true;
                        });
                        win.currentTracks = [cur].concat(filtered);
                    } else {
                        var rIdx = Math.floor(Math.random() * fullTracks.length);
                        var ch = fullTracks[rIdx];
                        var rRest = fullTracks.filter(function(_, idx) { return idx !== rIdx; });
                        win.currentTracks = [ch].concat(rRest);
                        win.playingPlaylistId = "";
                        win.playOnlineTrack(ch, false);
                    }
                }
            } catch (e) {
                console.warn("Nutsty: parse error in artist_shuffle", e);
            }
        }
    };
    xhr.send();
}

function addTracksToQueue(win, tracks) {
    if (!tracks || tracks.length === 0) return;
    var cur = win.currentTracks ? win.currentTracks.slice() : [];
    for (var i = 0; i < tracks.length; i++) {
        cur.push(tracks[i]);
    }
    win.currentTracks = cur;
}

function downloadEntireAlbum(win, tracks) {
    if (!tracks || tracks.length === 0) return;
    for (var i = 0; i < tracks.length; i++) {
        var t = tracks[i];
        if (typeof downloadManager !== "undefined" && downloadManager) {
            downloadManager.enqueueDownload(t);
        }
    }
}

function loadArtistDetails(win, artistNameOrId) {
    if (!artistNameOrId) return;
    var artTarget = String(artistNameOrId).trim();
    if (!artTarget) return;

    if (win.currentView !== "artist") {
        win.artistHistoryStack = [{ view: win.currentView, artist: null }];
    } else if (win.currentArtistData && win.currentArtistData.metadata) {
        win.artistHistoryStack.push({ view: "artist", artist: win.currentArtistData });
    }

    win.previousView = (win.currentView !== "artist") ? win.currentView : win.previousView;
    win.currentView = "artist";
    win.isLoadingArtist = true;
    win.currentArtistData = null;

    artistDetailsProc.running = false;
    artistDetailsProc.targetArtist = artTarget;
    artistDetailsProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "artist", artTarget];
    artistDetailsProc.running = true;
}

function goBackFromArtist(win) {
    if (win.artistHistoryStack && win.artistHistoryStack.length > 0) {
        var prev = win.artistHistoryStack.pop();
        if (prev && prev.view === "artist" && prev.artist) {
            win.currentArtistData = prev.artist;
            win.currentView = "artist";
            return;
        } else if (prev && prev.view) {
            win.currentView = prev.view;
            return;
        }
    }
    win.currentView = win.previousView || "home";
}

function loadAlbumDetails(win, alb) {
    if (!alb) return;
    if (typeof alb === "string") alb = { browseId: alb };
    var albId = alb.browseId || alb.playlistId || alb.id || "";
    win.activePlaylistId = albId;
    if (win.currentView !== "search" && win.currentView !== "playlist") {
        win.previousView = win.currentView;
    }
    win.currentView = "playlist";
    win.mainSectionTitle = alb.title || alb.name || "Album";
    mainGrid.sectionTitle = win.mainSectionTitle;

    if (alb.isLocal || (alb.tracks && alb.tracks.length > 0 && String(albId).startsWith("local_alb_"))) {
        win.currentAlbumMetadata = alb;
        mainGrid.albumMetadata = alb;
        win.browsingTracks = alb.tracks || [];
        win.isSearchingYT = false;
        return;
    }

    win.currentAlbumMetadata = null;
    mainGrid.albumMetadata = null;
    win.browsingTracks = [];
    win.isSearchingYT = true;

    albumDetailsProc.running = false;
    albumDetailsProc.targetTitle = alb.title || alb.name || "Album";
    albumDetailsProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "album", albId];
    albumDetailsProc.running = true;
}

function loadPlaylistTracks(win, pl) {
    if (!pl) return;
    var pid = pl.playlistId || pl.id || pl.browseId || "";
    if (!pid) return;

    if (pl.type === "artist" || String(pid).startsWith("UC") || String(pid).startsWith("FEmusic_library_privately_owned_artist_detail")) {
        win.loadArtistDetails(pid || pl.name || pl.title);
        return;
    }

    if (String(pid).startsWith("MPREb_") || pl.type === "album" || (pl.isLocal && String(pid).startsWith("local_alb_"))) {
        win.loadAlbumDetails(pl);
        return;
    }

    win.currentAlbumMetadata = null;
    mainGrid.albumMetadata = null;
    win.activePlaylistId = pid;
    if (win.currentView !== "search" && win.currentView !== "playlist") {
        win.previousView = win.currentView;
    }
    win.currentView = "playlist";
    win.mainSectionTitle = pl.title || pl.name || "Playlist";
    mainGrid.sectionTitle = pl.title || pl.name || "Playlist";

    var isCustomPl = !!pl.isCustom || String(pid).startsWith("custom_pl_") || (pl.tracks && pl.tracks.length >= 0 && pl.isLocal);
    if (isCustomPl) {
        var foundTracks = pl.tracks || [];
        if (win.customPlaylists) {
            for (var i = 0; i < win.customPlaylists.length; i++) {
                if (win.customPlaylists[i].id === pid) {
                    foundTracks = win.customPlaylists[i].tracks || [];
                    break;
                }
            }
        }
        win.browsingTracks = foundTracks;
        win.isSearchingYT = false;
        return;
    }

    win.browsingTracks = [];
    win.isSearchingYT = true;
    playlistTracksProc.running = false;
    playlistTracksProc.targetTitle = pl.title || "Playlist";
    playlistTracksProc.command = ["python3", "-u", win.appDir + "/backend/ytmusic_helper.py", "playlist", pid];
    playlistTracksProc.running = true;
}

function deleteCustomPlaylist(win, plId) {
    if (!plId) return;
    Quickshell.execDetached([
        "python3", win.appDir + "/backend/playlist_manager.py", "delete", plId
    ]);
    refreshPlaylistsTimer.restart();
    if (win.activePlaylistId === plId && win.currentView === "playlist") {
        win.currentView = "home";
    }
}
