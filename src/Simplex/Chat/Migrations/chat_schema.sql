CREATE TABLE migrations(
  name TEXT NOT NULL,
  ts TEXT NOT NULL,
  down TEXT,
  PRIMARY KEY(name)
);
CREATE TABLE contact_profiles(
  -- remote user profile
  contact_profile_id INTEGER PRIMARY KEY,
  display_name TEXT NOT NULL, -- contact name set by remote user(not unique), this name must not contain spaces
  full_name TEXT NOT NULL,
  properties TEXT NOT NULL DEFAULT '{}' -- JSON with contact profile properties
  ,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL),
  image TEXT,
  user_id INTEGER DEFAULT NULL REFERENCES users ON DELETE CASCADE,
  incognito INTEGER,
  local_alias TEXT DEFAULT '' CHECK(local_alias NOT NULL),
  preferences TEXT
);
CREATE INDEX contact_profiles_index ON contact_profiles(
  display_name,
  full_name
);
CREATE TABLE users(
  user_id INTEGER PRIMARY KEY,
  contact_id INTEGER NOT NULL UNIQUE REFERENCES contacts ON DELETE CASCADE
  DEFERRABLE INITIALLY DEFERRED,
  local_display_name TEXT NOT NULL UNIQUE,
  active_user INTEGER NOT NULL DEFAULT 0,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL),
  agent_user_id INTEGER CHECK(agent_user_id NOT NULL),
  view_pwd_hash BLOB,
  view_pwd_salt BLOB,
  show_ntfs INTEGER NOT NULL DEFAULT 1, -- 1 for active user
  FOREIGN KEY(user_id, local_display_name)
  REFERENCES display_names(user_id, local_display_name)
  ON DELETE CASCADE
  ON UPDATE CASCADE
  DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE display_names(
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  local_display_name TEXT NOT NULL,
  ldn_base TEXT NOT NULL,
  ldn_suffix INTEGER NOT NULL DEFAULT 0,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL),
  PRIMARY KEY(user_id, local_display_name) ON CONFLICT FAIL,
  UNIQUE(user_id, ldn_base, ldn_suffix) ON CONFLICT FAIL
) WITHOUT ROWID;
CREATE TABLE contacts(
  contact_id INTEGER PRIMARY KEY,
  contact_profile_id INTEGER REFERENCES contact_profiles ON DELETE SET NULL,
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  local_display_name TEXT NOT NULL,
  is_user INTEGER NOT NULL DEFAULT 0, -- 1 if this contact is a user
  via_group INTEGER REFERENCES groups(group_id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  updated_at TEXT CHECK(updated_at NOT NULL),
  xcontact_id BLOB,
  enable_ntfs INTEGER,
  unread_chat INTEGER DEFAULT 0 CHECK(unread_chat NOT NULL),
  contact_used INTEGER DEFAULT 0 CHECK(contact_used NOT NULL),
  user_preferences TEXT DEFAULT '{}' CHECK(user_preferences NOT NULL),
  chat_ts TEXT,
  FOREIGN KEY(user_id, local_display_name)
  REFERENCES display_names(user_id, local_display_name)
  ON DELETE CASCADE
  ON UPDATE CASCADE,
  UNIQUE(user_id, local_display_name),
  UNIQUE(user_id, contact_profile_id)
);
CREATE TABLE sent_probes(
  sent_probe_id INTEGER PRIMARY KEY,
  contact_id INTEGER NOT NULL UNIQUE REFERENCES contacts ON DELETE CASCADE,
  probe BLOB NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL),
  UNIQUE(user_id, probe)
);
CREATE TABLE sent_probe_hashes(
  sent_probe_hash_id INTEGER PRIMARY KEY,
  sent_probe_id INTEGER NOT NULL REFERENCES sent_probes ON DELETE CASCADE,
  contact_id INTEGER NOT NULL REFERENCES contacts ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL),
  UNIQUE(sent_probe_id, contact_id)
);
CREATE TABLE received_probes(
  received_probe_id INTEGER PRIMARY KEY,
  contact_id INTEGER NOT NULL REFERENCES contacts ON DELETE CASCADE,
  probe BLOB,
  probe_hash BLOB NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE
  ,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL)
);
CREATE TABLE known_servers(
  server_id INTEGER PRIMARY KEY,
  host TEXT NOT NULL,
  port TEXT NOT NULL,
  key_hash BLOB,
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL),
  UNIQUE(user_id, host, port)
) WITHOUT ROWID;
CREATE TABLE group_profiles(
  -- shared group profiles
  group_profile_id INTEGER PRIMARY KEY,
  display_name TEXT NOT NULL, -- this name must not contain spaces
  full_name TEXT NOT NULL,
  properties TEXT NOT NULL DEFAULT '{}' -- JSON with user or contact profile
  ,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL),
  image TEXT,
  user_id INTEGER DEFAULT NULL REFERENCES users ON DELETE CASCADE,
  preferences TEXT,
  description TEXT NULL
);
CREATE TABLE groups(
  group_id INTEGER PRIMARY KEY, -- local group ID
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  local_display_name TEXT NOT NULL, -- local group name without spaces
  group_profile_id INTEGER REFERENCES group_profiles ON DELETE SET NULL, -- shared group profile
  inv_queue_info BLOB,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL),
  chat_item_id INTEGER DEFAULT NULL REFERENCES chat_items ON DELETE SET NULL,
  enable_ntfs INTEGER,
  host_conn_custom_user_profile_id INTEGER REFERENCES contact_profiles ON DELETE SET NULL,
  unread_chat INTEGER DEFAULT 0 CHECK(unread_chat NOT NULL),
  chat_ts TEXT, -- received
  FOREIGN KEY(user_id, local_display_name)
  REFERENCES display_names(user_id, local_display_name)
  ON DELETE CASCADE
  ON UPDATE CASCADE,
  UNIQUE(user_id, local_display_name),
  UNIQUE(user_id, group_profile_id)
);
CREATE INDEX idx_groups_inv_queue_info ON groups(inv_queue_info);
CREATE TABLE group_members(
  -- group members, excluding the local user
  group_member_id INTEGER PRIMARY KEY,
  group_id INTEGER NOT NULL REFERENCES groups ON DELETE CASCADE,
  member_id BLOB NOT NULL, -- shared member ID, unique per group
  member_role TEXT NOT NULL, -- owner, admin, member
  member_category TEXT NOT NULL, -- see GroupMemberCategory
  member_status TEXT NOT NULL, -- see GroupMemberStatus
  invited_by INTEGER REFERENCES contacts(contact_id) ON DELETE SET NULL, -- NULL for the members who joined before the current user and for the group creator
  sent_inv_queue_info BLOB, -- sent
  group_queue_info BLOB, -- received
  direct_queue_info BLOB, -- received
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  local_display_name TEXT NOT NULL, -- should be the same as contact
  contact_profile_id INTEGER NOT NULL REFERENCES contact_profiles ON DELETE CASCADE,
  contact_id INTEGER REFERENCES contacts ON DELETE CASCADE,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL),
  member_profile_id INTEGER REFERENCES contact_profiles ON DELETE SET NULL,
  FOREIGN KEY(user_id, local_display_name)
  REFERENCES display_names(user_id, local_display_name)
  ON DELETE CASCADE
  ON UPDATE CASCADE,
  UNIQUE(group_id, member_id)
);
CREATE TABLE group_member_intros(
  group_member_intro_id INTEGER PRIMARY KEY,
  re_group_member_id INTEGER NOT NULL REFERENCES group_members(group_member_id) ON DELETE CASCADE,
  to_group_member_id INTEGER NOT NULL REFERENCES group_members(group_member_id) ON DELETE CASCADE,
  group_queue_info BLOB,
  direct_queue_info BLOB,
  intro_status TEXT NOT NULL,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL), -- see GroupMemberIntroStatus
  UNIQUE(re_group_member_id, to_group_member_id)
);
CREATE TABLE files(
  file_id INTEGER PRIMARY KEY,
  contact_id INTEGER REFERENCES contacts ON DELETE CASCADE,
  group_id INTEGER REFERENCES groups ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_path TEXT,
  file_size INTEGER NOT NULL,
  chunk_size INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE
  ,
  chat_item_id INTEGER DEFAULT NULL REFERENCES chat_items ON DELETE CASCADE,
  updated_at TEXT CHECK(updated_at NOT NULL),
  cancelled INTEGER,
  ci_file_status TEXT,
  file_inline TEXT,
  agent_snd_file_id BLOB NULL,
  private_snd_file_descr TEXT NULL,
  agent_snd_file_deleted INTEGER DEFAULT 0 CHECK(agent_snd_file_deleted NOT NULL),
  protocol TEXT NOT NULL DEFAULT 'smp'
);
CREATE TABLE snd_files(
  file_id INTEGER NOT NULL REFERENCES files ON DELETE CASCADE,
  connection_id INTEGER NOT NULL REFERENCES connections ON DELETE CASCADE,
  file_status TEXT NOT NULL, -- new, accepted, connected, completed
  group_member_id INTEGER REFERENCES group_members ON DELETE CASCADE,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL),
  file_inline TEXT,
  last_inline_msg_delivery_id INTEGER,
  file_descr_id INTEGER NULL
  REFERENCES xftp_file_descriptions ON DELETE SET NULL,
  PRIMARY KEY(file_id, connection_id)
) WITHOUT ROWID;
CREATE TABLE rcv_files(
  file_id INTEGER PRIMARY KEY REFERENCES files ON DELETE CASCADE,
  file_status TEXT NOT NULL, -- new, accepted, connected, completed
  group_member_id INTEGER REFERENCES group_members ON DELETE CASCADE,
  file_queue_info BLOB
  ,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL),
  rcv_file_inline TEXT,
  file_inline TEXT,
  file_descr_id INTEGER NULL
  REFERENCES xftp_file_descriptions ON DELETE SET NULL,
  agent_rcv_file_id BLOB NULL,
  agent_rcv_file_deleted INTEGER DEFAULT 0 CHECK(agent_rcv_file_deleted NOT NULL)
);
CREATE TABLE snd_file_chunks(
  file_id INTEGER NOT NULL,
  connection_id INTEGER NOT NULL,
  chunk_number INTEGER NOT NULL,
  chunk_agent_msg_id INTEGER,
  chunk_sent INTEGER NOT NULL DEFAULT 0,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL), -- 0(sent to agent), 1(sent to server)
  FOREIGN KEY(file_id, connection_id) REFERENCES snd_files ON DELETE CASCADE,
  PRIMARY KEY(file_id, connection_id, chunk_number)
) WITHOUT ROWID;
CREATE TABLE rcv_file_chunks(
  file_id INTEGER NOT NULL REFERENCES rcv_files ON DELETE CASCADE,
  chunk_number INTEGER NOT NULL,
  chunk_agent_msg_id INTEGER NOT NULL,
  chunk_stored INTEGER NOT NULL DEFAULT 0,
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL), -- 0(received), 1(appended to file)
  PRIMARY KEY(file_id, chunk_number)
) WITHOUT ROWID;
CREATE TABLE connections(
  -- all SMP agent connections
  connection_id INTEGER PRIMARY KEY,
  agent_conn_id BLOB NOT NULL UNIQUE,
  conn_level INTEGER NOT NULL DEFAULT 0,
  via_contact INTEGER REFERENCES contacts(contact_id) ON DELETE SET NULL,
  conn_status TEXT NOT NULL,
  conn_type TEXT NOT NULL, -- contact, member, rcv_file, snd_file
  user_contact_link_id INTEGER REFERENCES user_contact_links ON DELETE CASCADE,
  contact_id INTEGER REFERENCES contacts ON DELETE CASCADE,
  group_member_id INTEGER REFERENCES group_members ON DELETE CASCADE,
  snd_file_id INTEGER,
  rcv_file_id INTEGER REFERENCES rcv_files(file_id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  updated_at TEXT CHECK(updated_at NOT NULL),
  via_contact_uri_hash BLOB,
  xcontact_id BLOB,
  via_user_contact_link INTEGER DEFAULT NULL
  REFERENCES user_contact_links(user_contact_link_id) ON DELETE SET NULL,
  custom_user_profile_id INTEGER REFERENCES contact_profiles ON DELETE SET NULL,
  conn_req_inv BLOB,
  local_alias DEFAULT '' CHECK(local_alias NOT NULL),
  via_group_link INTEGER DEFAULT 0 CHECK(via_group_link NOT NULL),
  group_link_id BLOB,
  security_code TEXT NULL,
  security_code_verified_at TEXT NULL,
  auth_err_counter INTEGER DEFAULT 0 CHECK(auth_err_counter NOT NULL),
  FOREIGN KEY(snd_file_id, connection_id)
  REFERENCES snd_files(file_id, connection_id)
  ON DELETE CASCADE
  DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE user_contact_links(
  user_contact_link_id INTEGER PRIMARY KEY,
  conn_req_contact BLOB NOT NULL,
  local_display_name TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  updated_at TEXT CHECK(updated_at NOT NULL),
  auto_accept INTEGER DEFAULT 0,
  auto_reply_msg_content TEXT DEFAULT NULL,
  group_id INTEGER REFERENCES groups ON DELETE CASCADE,
  auto_accept_incognito INTEGER DEFAULT 0 CHECK(auto_accept_incognito NOT NULL),
  group_link_id BLOB,
  group_link_member_role TEXT NULL,
  UNIQUE(user_id, local_display_name)
);
CREATE TABLE contact_requests(
  contact_request_id INTEGER PRIMARY KEY,
  user_contact_link_id INTEGER NOT NULL REFERENCES user_contact_links
  ON UPDATE CASCADE ON DELETE CASCADE,
  agent_invitation_id BLOB NOT NULL,
  contact_profile_id INTEGER REFERENCES contact_profiles
  ON DELETE SET NULL
  DEFERRABLE INITIALLY DEFERRED,
  local_display_name TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  updated_at TEXT CHECK(updated_at NOT NULL),
  xcontact_id BLOB,
  FOREIGN KEY(user_id, local_display_name)
  REFERENCES display_names(user_id, local_display_name)
  ON UPDATE CASCADE
  ON DELETE CASCADE
  DEFERRABLE INITIALLY DEFERRED,
  UNIQUE(user_id, local_display_name),
  UNIQUE(user_id, contact_profile_id)
);
CREATE TABLE messages(
  message_id INTEGER PRIMARY KEY,
  msg_sent INTEGER NOT NULL, -- 0 for received, 1 for sent
  chat_msg_event TEXT NOT NULL, -- message event tag(the constructor of CMEventTag)
  msg_body BLOB, -- agent message body as received or sent
  created_at TEXT NOT NULL DEFAULT(datetime('now'))
  ,
  updated_at TEXT CHECK(updated_at NOT NULL),
  connection_id INTEGER DEFAULT NULL REFERENCES connections ON DELETE CASCADE,
  group_id INTEGER DEFAULT NULL REFERENCES groups ON DELETE CASCADE,
  shared_msg_id BLOB,
  shared_msg_id_user INTEGER
);
CREATE TABLE msg_deliveries(
  msg_delivery_id INTEGER PRIMARY KEY,
  message_id INTEGER NOT NULL REFERENCES messages ON DELETE CASCADE, -- non UNIQUE for group messages
  connection_id INTEGER NOT NULL REFERENCES connections ON DELETE CASCADE,
  agent_msg_id INTEGER, -- internal agent message ID(NULL while pending)
  agent_msg_meta TEXT, -- JSON with timestamps etc. sent in MSG, NULL for sent
  chat_ts TEXT NOT NULL DEFAULT(datetime('now')),
  created_at TEXT CHECK(created_at NOT NULL),
  updated_at TEXT CHECK(updated_at NOT NULL),
  agent_ack_cmd_id INTEGER, -- broker_ts for received, created_at for sent
  UNIQUE(connection_id, agent_msg_id)
);
CREATE TABLE msg_delivery_events(
  msg_delivery_event_id INTEGER PRIMARY KEY,
  msg_delivery_id INTEGER NOT NULL REFERENCES msg_deliveries ON DELETE CASCADE, -- non UNIQUE for multiple events per msg delivery
  delivery_status TEXT NOT NULL, -- see MsgDeliveryStatus for allowed values
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  updated_at TEXT CHECK(updated_at NOT NULL),
  UNIQUE(msg_delivery_id, delivery_status)
);
CREATE TABLE pending_group_messages(
  pending_group_message_id INTEGER PRIMARY KEY,
  group_member_id INTEGER NOT NULL REFERENCES group_members ON DELETE CASCADE,
  message_id INTEGER NOT NULL REFERENCES messages ON DELETE CASCADE,
  group_member_intro_id INTEGER REFERENCES group_member_intros ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  updated_at TEXT NOT NULL DEFAULT(datetime('now'))
);
CREATE TABLE chat_items(
  chat_item_id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  contact_id INTEGER REFERENCES contacts ON DELETE CASCADE,
  group_id INTEGER REFERENCES groups ON DELETE CASCADE,
  group_member_id INTEGER REFERENCES group_members ON DELETE SET NULL, -- NULL for sent even if group_id is not
  chat_msg_id INTEGER, -- sent as part of the message that created the item
  created_by_msg_id INTEGER UNIQUE REFERENCES messages(message_id) ON DELETE SET NULL,
  item_sent INTEGER NOT NULL, -- 0 for received, 1 for sent
  item_ts TEXT NOT NULL, -- broker_ts of creating message for received, created_at for sent
  item_deleted INTEGER NOT NULL DEFAULT 0, -- 1 for deleted
  item_content TEXT NOT NULL, -- JSON
  item_text TEXT NOT NULL, -- textual representation
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  updated_at TEXT NOT NULL DEFAULT(datetime('now'))
  ,
  item_status TEXT CHECK(item_status NOT NULL),
  shared_msg_id BLOB,
  quoted_shared_msg_id BLOB,
  quoted_sent_at TEXT,
  quoted_content TEXT,
  quoted_sent INTEGER,
  quoted_member_id BLOB,
  item_edited INTEGER,
  timed_ttl INTEGER,
  timed_delete_at TEXT,
  item_live INTEGER,
  item_deleted_by_group_member_id INTEGER REFERENCES group_members ON DELETE SET NULL
);
CREATE TABLE chat_item_messages(
  chat_item_id INTEGER NOT NULL REFERENCES chat_items ON DELETE CASCADE,
  message_id INTEGER NOT NULL UNIQUE REFERENCES messages ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  updated_at TEXT NOT NULL DEFAULT(datetime('now')),
  UNIQUE(chat_item_id, message_id)
);
CREATE INDEX idx_connections_via_contact_uri_hash ON connections(
  via_contact_uri_hash
);
CREATE INDEX idx_contact_requests_xcontact_id ON contact_requests(xcontact_id);
CREATE INDEX idx_contacts_xcontact_id ON contacts(xcontact_id);
CREATE INDEX idx_messages_shared_msg_id ON messages(shared_msg_id);
CREATE INDEX idx_chat_items_shared_msg_id ON chat_items(shared_msg_id);
CREATE TABLE calls(
  -- stores call invitations state for communicating state between NSE and app when call notification comes
  call_id INTEGER PRIMARY KEY,
  contact_id INTEGER NOT NULL REFERENCES contacts ON DELETE CASCADE,
  shared_call_id BLOB NOT NULL,
  chat_item_id INTEGER NOT NULL REFERENCES chat_items ON DELETE CASCADE,
  call_state BLOB NOT NULL,
  call_ts TEXT NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  updated_at TEXT NOT NULL DEFAULT(datetime('now'))
);
CREATE INDEX idx_chat_items_groups ON chat_items(
  user_id,
  group_id,
  item_ts,
  chat_item_id
);
CREATE INDEX idx_chat_items_contacts ON chat_items(
  user_id,
  contact_id,
  chat_item_id
);
CREATE TABLE commands(
  command_id INTEGER PRIMARY KEY AUTOINCREMENT, -- used as ACorrId
  connection_id INTEGER REFERENCES connections ON DELETE CASCADE,
  command_function TEXT NOT NULL,
  command_status TEXT NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  updated_at TEXT NOT NULL DEFAULT(datetime('now'))
);
CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE settings(
  settings_id INTEGER PRIMARY KEY,
  chat_item_ttl INTEGER,
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  updated_at TEXT NOT NULL DEFAULT(datetime('now'))
);
CREATE UNIQUE INDEX idx_chat_items_direct_shared_msg_id ON chat_items(
  user_id,
  contact_id,
  shared_msg_id
);
CREATE UNIQUE INDEX idx_chat_items_group_shared_msg_id ON chat_items(
  user_id,
  group_id,
  group_member_id,
  shared_msg_id
);
CREATE INDEX idx_msg_deliveries_message_id ON msg_deliveries(message_id);
CREATE UNIQUE INDEX idx_user_contact_links_group_id ON user_contact_links(
  group_id
);
CREATE UNIQUE INDEX idx_snd_files_last_inline_msg_delivery_id ON snd_files(
  last_inline_msg_delivery_id
);
CREATE INDEX idx_messages_connection_id ON messages(connection_id);
CREATE INDEX idx_chat_items_group_member_id ON chat_items(group_member_id);
CREATE INDEX idx_chat_items_contact_id ON chat_items(contact_id);
CREATE INDEX idx_chat_items_timed_delete_at ON chat_items(timed_delete_at);
CREATE INDEX idx_chat_items_item_status ON chat_items(item_status);
CREATE INDEX idx_connections_group_member ON connections(
  user_id,
  group_member_id
);
CREATE INDEX idx_commands_connection_id ON commands(connection_id);
CREATE INDEX idx_calls_user_id ON calls(user_id);
CREATE INDEX idx_calls_chat_item_id ON calls(chat_item_id);
CREATE INDEX idx_calls_contact_id ON calls(contact_id);
CREATE INDEX idx_commands_user_id ON commands(user_id);
CREATE INDEX idx_connections_custom_user_profile_id ON connections(
  custom_user_profile_id
);
CREATE INDEX idx_connections_via_user_contact_link ON connections(
  via_user_contact_link
);
CREATE INDEX idx_connections_rcv_file_id ON connections(rcv_file_id);
CREATE INDEX idx_connections_contact_id ON connections(contact_id);
CREATE INDEX idx_connections_user_contact_link_id ON connections(
  user_contact_link_id
);
CREATE INDEX idx_connections_via_contact ON connections(via_contact);
CREATE INDEX idx_contact_profiles_user_id ON contact_profiles(user_id);
CREATE INDEX idx_contact_requests_contact_profile_id ON contact_requests(
  contact_profile_id
);
CREATE INDEX idx_contact_requests_user_contact_link_id ON contact_requests(
  user_contact_link_id
);
CREATE INDEX idx_contacts_via_group ON contacts(via_group);
CREATE INDEX idx_contacts_contact_profile_id ON contacts(contact_profile_id);
CREATE INDEX idx_files_chat_item_id ON files(chat_item_id);
CREATE INDEX idx_files_user_id ON files(user_id);
CREATE INDEX idx_files_group_id ON files(group_id);
CREATE INDEX idx_files_contact_id ON files(contact_id);
CREATE INDEX idx_group_member_intros_to_group_member_id ON group_member_intros(
  to_group_member_id
);
CREATE INDEX idx_group_members_user_id_local_display_name ON group_members(
  user_id,
  local_display_name
);
CREATE INDEX idx_group_members_member_profile_id ON group_members(
  member_profile_id
);
CREATE INDEX idx_group_members_contact_id ON group_members(contact_id);
CREATE INDEX idx_group_members_contact_profile_id ON group_members(
  contact_profile_id
);
CREATE INDEX idx_group_members_user_id ON group_members(user_id);
CREATE INDEX idx_group_members_invited_by ON group_members(invited_by);
CREATE INDEX idx_group_profiles_user_id ON group_profiles(user_id);
CREATE INDEX idx_groups_host_conn_custom_user_profile_id ON groups(
  host_conn_custom_user_profile_id
);
CREATE INDEX idx_groups_chat_item_id ON groups(chat_item_id);
CREATE INDEX idx_groups_group_profile_id ON groups(group_profile_id);
CREATE INDEX idx_messages_group_id ON messages(group_id);
CREATE INDEX idx_pending_group_messages_group_member_intro_id ON pending_group_messages(
  group_member_intro_id
);
CREATE INDEX idx_pending_group_messages_message_id ON pending_group_messages(
  message_id
);
CREATE INDEX idx_pending_group_messages_group_member_id ON pending_group_messages(
  group_member_id
);
CREATE INDEX idx_rcv_file_chunks_file_id ON rcv_file_chunks(file_id);
CREATE INDEX idx_rcv_files_group_member_id ON rcv_files(group_member_id);
CREATE INDEX idx_received_probes_user_id ON received_probes(user_id);
CREATE INDEX idx_received_probes_contact_id ON received_probes(contact_id);
CREATE INDEX idx_sent_probe_hashes_user_id ON sent_probe_hashes(user_id);
CREATE INDEX idx_sent_probe_hashes_contact_id ON sent_probe_hashes(contact_id);
CREATE INDEX idx_settings_user_id ON settings(user_id);
CREATE INDEX idx_snd_file_chunks_file_id_connection_id ON snd_file_chunks(
  file_id,
  connection_id
);
CREATE INDEX idx_snd_files_group_member_id ON snd_files(group_member_id);
CREATE INDEX idx_snd_files_connection_id ON snd_files(connection_id);
CREATE INDEX idx_snd_files_file_id ON snd_files(file_id);
CREATE TABLE IF NOT EXISTS "protocol_servers"(
  smp_server_id INTEGER PRIMARY KEY,
  host TEXT NOT NULL,
  port TEXT NOT NULL,
  key_hash BLOB NOT NULL,
  basic_auth TEXT,
  preset INTEGER NOT NULL DEFAULT 0,
  tested INTEGER,
  enabled INTEGER NOT NULL DEFAULT 1,
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  updated_at TEXT NOT NULL DEFAULT(datetime('now')),
  protocol TEXT NOT NULL DEFAULT 'smp',
  UNIQUE(user_id, host, port)
);
CREATE INDEX idx_smp_servers_user_id ON "protocol_servers"(user_id);
CREATE INDEX idx_chat_items_item_deleted_by_group_member_id ON chat_items(
  item_deleted_by_group_member_id
);
CREATE TABLE xftp_file_descriptions(
  file_descr_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  file_descr_text TEXT NOT NULL,
  file_descr_part_no INTEGER NOT NULL DEFAULT(0),
  file_descr_complete INTEGER NOT NULL DEFAULT(0),
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  updated_at TEXT NOT NULL DEFAULT(datetime('now'))
);
CREATE INDEX idx_snd_files_file_descr_id ON snd_files(file_descr_id);
CREATE INDEX idx_rcv_files_file_descr_id ON rcv_files(file_descr_id);
