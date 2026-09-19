/**
 * Nutsty Friends Pulse & 24h Ephemeral Music Notes
 * Cloudflare Worker Backend
 * 
 * Features:
 * - POST /api/notes: Publish note with expirationTtl: 86400 (24h)
 * - GET  /api/notes?friends=a@gmail.com,b@gmail.com: Retrieve active notes of friends
 * - GET  /: Mobile Web Companion to post note directly from phone
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // CORS Headers for Desktop App & Web
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    // 1. POST /api/notes - Publish or update daily note
    if (request.method === "POST" && url.pathname === "/api/notes") {
      try {
        const body = await request.json();
        const { user_email, user_name, avatar_url, note_text, track } = body;

        if (!user_email || !note_text) {
          return new Response(JSON.stringify({ error: "Missing required fields: user_email, note_text" }), {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
          });
        }

        const cleanEmail = user_email.trim().toLowerCase();
        const nowMs = Date.now();
        const ttlSeconds = 86400; // Exactly 24 hours

        const noteData = {
          user_email: cleanEmail,
          user_name: (user_name || "Anonymous").substring(0, 40),
          avatar_url: avatar_url || "",
          note_text: note_text.substring(0, 80),
          track: track ? {
            id: track.id || "",
            title: (track.title || "").substring(0, 80),
            artist: (track.artist || "").substring(0, 80),
            cover: track.cover || ""
          } : null,
          now_playing: body.now_playing || null,
          created_at: new Date(nowMs).toISOString(),
          expires_at: new Date(nowMs + ttlSeconds * 1000).toISOString()
        };

        if (env && env.NUTSTY_NOTES) {
          await env.NUTSTY_NOTES.put(`note:${cleanEmail}`, JSON.stringify(noteData), {
            expirationTtl: ttlSeconds
          });
        }

        return new Response(JSON.stringify({ success: true, note: noteData }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      } catch (err) {
        return new Response(JSON.stringify({ error: err.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
    }

    // 2. GET /api/notes - Fetch active notes for given friend emails
    if (request.method === "GET" && url.pathname === "/api/notes") {
      const friendsParam = url.searchParams.get("friends") || "";
      const friendEmails = friendsParam
        .split(",")
        .map(e => e.trim().toLowerCase())
        .filter(Boolean);

      const notes = [];
      if (env && env.NUTSTY_NOTES) {
        for (const email of friendEmails) {
          const raw = await env.NUTSTY_NOTES.get(`note:${email}`);
          if (raw) {
            try {
              const parsed = JSON.parse(raw);
              notes.push(parsed);
            } catch (_) {}
          }
        }
      }

      return new Response(JSON.stringify({ count: notes.length, notes }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // 3. GET / or /web - Mobile Web Companion Test UI
    if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/web")) {
      const html = `<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Nutsty Friends Pulse Companion</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: #08090d; color: #f1f5f9; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; }
  .card { background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.12); border-radius: 20px; padding: 28px; max-width: 420px; width: 100%; backdrop-filter: blur(24px); box-shadow: 0 20px 40px rgba(0,0,0,0.6); }
  h1 { font-size: 20px; font-weight: 700; margin-bottom: 6px; display: flex; align-items: center; gap: 8px; }
  p.desc { font-size: 13px; color: #94a3b8; margin-bottom: 20px; line-height: 1.4; }
  .field { margin-bottom: 14px; text-align: left; }
  label { display: block; font-size: 11px; font-weight: 600; text-transform: uppercase; color: #64748b; margin-bottom: 6px; letter-spacing: 0.05em; }
  input, textarea { width: 100%; padding: 12px 14px; border-radius: 10px; border: 1px solid rgba(255,255,255,0.14); background: rgba(0,0,0,0.4); color: #fff; font-size: 14px; outline: none; transition: border 0.2s; }
  input:focus, textarea:focus { border-color: #3b82f6; }
  button { background: #3b82f6; color: #fff; border: none; padding: 14px; border-radius: 12px; font-weight: 700; font-size: 14px; cursor: pointer; width: 100%; margin-top: 8px; transition: transform 0.1s, background 0.2s; }
  button:hover { background: #2563eb; transform: scale(1.02); }
  .bubble { background: rgba(59,130,246,0.15); border: 1px solid #3b82f6; border-radius: 12px; padding: 14px; margin-top: 16px; font-size: 13px; color: #93c5fd; }
</style>
</head>
<body>
  <div class="card">
    <h1>✦ Nutsty Note 24h</h1>
    <p class="desc">Đăng ghi chú từ điện thoại để xuất hiện trực tiếp trên màn hình máy tính của bạn bè trong 24h!</p>
    
    <div class="field">
      <label>Email Google Của Bạn</label>
      <input id="email" type="email" placeholder="ví dụ: friend@gmail.com" value="friend@gmail.com"/>
    </div>
    <div class="field">
      <label>Tên Hiển Thị</label>
      <input id="name" placeholder="Tên của bạn" value="Bạn Thân"/>
    </div>
    <div class="field">
      <label>Ghi Chú Hôm Nay (Tối đa 60 ký tự)</label>
      <textarea id="note" rows="2" maxlength="60" placeholder="Hôm nay tâm trạng thế nào?">Hôm nay trời đẹp quá, đang nghe chill phết...</textarea>
    </div>
    <div class="field">
      <label>Bài Hát Đang Nghe</label>
      <input id="track" placeholder="Tên bài hát" value="Ghé Qua - Dick, PC, Tofu"/>
    </div>

    <button onclick="postNote()">🚀 Đăng Note Trong 24 Giờ</button>
    <div id="status" class="bubble" style="display:none;"></div>
  </div>

<script>
async function postNote() {
  const status = document.getElementById("status");
  status.style.display = "block";
  status.innerText = "Đang gửi note...";
  try {
    const res = await fetch("/api/notes", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        user_email: document.getElementById("email").value,
        user_name: document.getElementById("name").value,
        note_text: document.getElementById("note").value,
        track: { title: document.getElementById("track").value, artist: "Đang phát", cover: "" }
      })
    });
    const data = await res.json();
    if (data.success) {
      status.innerText = "✅ Note đã đăng thành công! Bạn bè mở Nutsty sẽ thấy ngay.";
    } else {
      status.innerText = "❌ Lỗi: " + (data.error || "Không thể đăng");
    }
  } catch(e) {
    status.innerText = "❌ Lỗi kết nối: " + e.message;
  }
}
</script>
</body>
</html>`;
      return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8" } });
    }

    return new Response("Not Found", { status: 404 });
  }
};
