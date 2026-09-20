-- Nutsty Global Friends Relay - Cloudflare D1 SQL Schema
-- Supports Discord-style Tags (Username#1234), Immutable User UUIDs, Realtime Event Queues

CREATE TABLE IF NOT EXISTS nutsty_users (
    id TEXT PRIMARY KEY,               -- Immutable UUID v4 (usr_xxxxxxxx...)
    secret_key TEXT NOT NULL,          -- Client secret key for authentication
    username TEXT NOT NULL,            -- Display name ("Shiraori")
    discriminator TEXT NOT NULL,       -- 4-digit number ("6180")
    tag TEXT NOT NULL UNIQUE,          -- Composite: username#discriminator ("Shiraori#6180")
    avatar_url TEXT DEFAULT '',        -- Google avatar URL
    now_playing TEXT DEFAULT '',       -- JSON string of current listening track
    created_at INTEGER NOT NULL,       -- Epoch ms
    updated_at INTEGER NOT NULL,       -- Epoch ms
    last_active_at INTEGER NOT NULL    -- Epoch ms
);

CREATE INDEX IF NOT EXISTS idx_users_tag ON nutsty_users(tag);
CREATE INDEX IF NOT EXISTS idx_users_username ON nutsty_users(username);
CREATE INDEX IF NOT EXISTS idx_users_discriminator ON nutsty_users(discriminator);

CREATE TABLE IF NOT EXISTS nutsty_friendships (
    id TEXT PRIMARY KEY,               -- UUID of friendship relation
    user_id_1 TEXT NOT NULL,           -- min(user_a, user_b) to enforce unique pair
    user_id_2 TEXT NOT NULL,           -- max(user_a, user_b)
    status TEXT NOT NULL,              -- 'pending', 'accepted', 'rejected'
    initiated_by TEXT NOT NULL,        -- User UUID who sent the friend request
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY(user_id_1) REFERENCES nutsty_users(id),
    FOREIGN KEY(user_id_2) REFERENCES nutsty_users(id),
    UNIQUE(user_id_1, user_id_2)
);

CREATE INDEX IF NOT EXISTS idx_friendships_u1 ON nutsty_friendships(user_id_1);
CREATE INDEX IF NOT EXISTS idx_friendships_u2 ON nutsty_friendships(user_id_2);

CREATE TABLE IF NOT EXISTS nutsty_events (
    id TEXT PRIMARY KEY,               -- Event UUID
    to_user_id TEXT NOT NULL,          -- Recipient User UUID
    from_user_id TEXT NOT NULL,        -- Sender User UUID
    event_type TEXT NOT NULL,          -- 'friend_request', 'friend_accepted', 'friend_removed'
    payload TEXT NOT NULL,             -- JSON string with event metadata
    consumed INTEGER DEFAULT 0,        -- 0 = pending, 1 = received/consumed
    created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_events_to_user ON nutsty_events(to_user_id, consumed);
