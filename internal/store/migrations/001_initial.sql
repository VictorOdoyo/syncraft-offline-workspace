CREATE TABLE IF NOT EXISTS workspaces (
 id text PRIMARY KEY,
 sequence bigint NOT NULL DEFAULT 0,
 audit_sequence bigint NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS devices (
 workspace text NOT NULL REFERENCES workspaces(id),
 id uuid NOT NULL,
 actor text NOT NULL,
 name text NOT NULL,
 revoked boolean NOT NULL DEFAULT false,
 created timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(workspace,id)
);
CREATE TABLE IF NOT EXISTS operations (
 workspace text NOT NULL REFERENCES workspaces(id),
 id uuid NOT NULL,
 sequence bigint NOT NULL,
 device uuid NOT NULL,
 actor text NOT NULL,
 created timestamptz NOT NULL DEFAULT now(),
 content jsonb NOT NULL,
 PRIMARY KEY(workspace,id),
 UNIQUE(workspace,sequence),
 FOREIGN KEY(workspace,device) REFERENCES devices(workspace,id)
);
CREATE INDEX IF NOT EXISTS operations_record ON operations(workspace,(content->>'record'));
CREATE TABLE IF NOT EXISTS audit_events (
 workspace text NOT NULL REFERENCES workspaces(id),
 sequence bigint NOT NULL,
 actor text NOT NULL,
 action text NOT NULL,
 target text NOT NULL,
 created timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(workspace,sequence)
);
CREATE TABLE IF NOT EXISTS attachments (
 workspace text NOT NULL REFERENCES workspaces(id),
 id uuid NOT NULL,
 record uuid NOT NULL,
 name text NOT NULL,
 media_type text NOT NULL,
 sha256 text NOT NULL,
 content bytea NOT NULL CHECK(octet_length(content)<=5242880),
 PRIMARY KEY(workspace,id)
);
CREATE INDEX IF NOT EXISTS attachments_record ON attachments(workspace,record);
