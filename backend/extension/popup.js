(() => {
  "use strict";
  const extractYtBtn = document.getElementById("extract-youtube-music");
  const copyYtBtn = document.getElementById("copy-youtube-music");
  const ytResultArea = document.getElementById("youtube-music-result");
  const formatSelect = document.getElementById("format-select");
  const syncFrostifyBtn = document.getElementById("sync-frostify");
  const extractSpBtn = document.getElementById("extract-spotify");
  const copySpBtn = document.getElementById("copy-spotify");
  const spResultArea = document.getElementById("spotify-result");
  const statusEl = document.getElementById("status");

  const showStatus = (msg, isError = false) => {
    statusEl.textContent = msg;
    statusEl.className = isError ? "status error" : "status success";
    setTimeout(() => {
      statusEl.textContent = "";
      statusEl.className = "status";
    }, 4000);
  };

  const copyText = async (text) => {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch (err) {
      console.error("Failed to copy: ", err);
      return false;
    }
  };

  extractYtBtn.addEventListener("click", () => {
    ytResultArea.value = "Loading...";
    const fmt = formatSelect.value;
    const action = fmt === "netscape" ? "getYouTubeMusicCookiesNetscape" : "getYouTubeMusicCookies";
    chrome.runtime.sendMessage({ action: action }, (resp) => {
      if (chrome.runtime.lastError) {
        showStatus(`Error: ${chrome.runtime.lastError.message}`, true);
      } else if (resp && resp.success && resp.data) {
        if (fmt === "netscape") {
          if ("netscapeFormat" in resp.data && resp.data.netscapeFormat) {
            ytResultArea.value = resp.data.netscapeFormat;
            copyYtBtn.disabled = false;
            showStatus("YouTube Music cookies extracted in Netscape format!");
          } else {
            ytResultArea.value = "No YouTube Music cookies found";
          }
        } else if ("youtubeMusic" in resp.data && resp.data.youtubeMusic && Object.keys(resp.data.youtubeMusic).length > 0) {
          const cookieStr = Object.entries(resp.data.youtubeMusic).map(([k, v]) => `${k}=${v}`).join("; ");
          ytResultArea.value = cookieStr;
          copyYtBtn.disabled = false;
          showStatus("YouTube Music cookies extracted successfully!");
        } else {
          ytResultArea.value = "No YouTube Music cookies found";
        }
      } else {
        ytResultArea.value = "";
        showStatus(`Failed to extract cookies: ${resp?.error || "Unknown error"}`, true);
      }
    });
  });

  if (syncFrostifyBtn) {
    syncFrostifyBtn.addEventListener("click", () => {
      showStatus("Connecting to Frostify Local...");
      chrome.runtime.sendMessage({ action: "getYouTubeMusicCookies" }, async (resp) => {
        if (chrome.runtime.lastError) {
          showStatus(`Error: ${chrome.runtime.lastError.message}`, true);
          return;
        }
        if (resp && resp.success && resp.data && resp.data.youtubeMusic && Object.keys(resp.data.youtubeMusic).length > 0) {
          const cookieStr = Object.entries(resp.data.youtubeMusic).map(([k, v]) => `${k}=${v}`).join("; ");
          try {
            const res = await fetch("http://127.0.0.1:17890/api/auth/cookies", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ cookies: cookieStr })
            });
            const data = await res.json();
            if (data.success) {
              showStatus("Synced to Frostify successfully! Home feed refreshed.");
            } else {
              showStatus(`Frostify error: ${data.error || "Failed"}`, true);
            }
          } catch (err) {
            showStatus("Cannot reach Frostify. Ensure Frostify is running.", true);
          }
        } else {
          showStatus("No YouTube Music cookies found. Log in on music.youtube.com first.", true);
        }
      });
    });
  }

  extractSpBtn.addEventListener("click", () => {
    spResultArea.value = "Loading...";
    chrome.runtime.sendMessage({ action: "getSpotifyCookies" }, (resp) => {
      if (chrome.runtime.lastError) {
        showStatus(`Error: ${chrome.runtime.lastError.message}`, true);
      } else if (resp && resp.success && resp.data && "spotify" in resp.data) {
        const sp_dc = resp.data.spotify?.sp_dc;
        if (sp_dc) {
          spResultArea.value = sp_dc;
          copySpBtn.disabled = false;
          showStatus("Spotify cookies extracted successfully!");
        } else {
          spResultArea.value = "sp_dc cookie not found";
        }
      } else {
        spResultArea.value = "";
        showStatus(`Failed to extract Spotify cookies: ${resp?.error || "Unknown error"}`, true);
      }
    });
  });

  formatSelect.addEventListener("change", () => {
    ytResultArea.value = "";
    copyYtBtn.disabled = true;
  });

  copyYtBtn.addEventListener("click", async () => {
    const ok = await copyText(ytResultArea.value);
    showStatus(ok ? "YouTube Music cookies copied!" : "Failed to copy", !ok);
  });

  copySpBtn.addEventListener("click", async () => {
    const ok = await copyText(spResultArea.value);
    showStatus(ok ? "Spotify cookie copied!" : "Failed to copy", !ok);
  });

  document.addEventListener("DOMContentLoaded", () => {
    ytResultArea.value = "";
    spResultArea.value = "";
    copyYtBtn.disabled = true;
    copySpBtn.disabled = true;
  });
})();