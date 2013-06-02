-- Schema for Battie 0.02

--
--
-- schema schema_poard_0.01_017
--
--
--
-- Table: [[PREFIX]]_poard_thread
CREATE TABLE "[[PREFIX]]_poard_thread" (
  "id" bigserial NOT NULL,
  "title" character varying(128) DEFAULT '' NOT NULL,
  "author_id" bigint NOT NULL,
  "author_name" character varying(32),
  "status" varchar(16) DEFAULT 'onhold' NOT NULL,
  "fixed" tinyint(1) DEFAULT '0' NOT NULL,
  "closed" tinyint(1) DEFAULT '0' NOT NULL,
  "board_id" integer NOT NULL,
  "read_count" integer DEFAULT '0',
  "messagecount" integer DEFAULT '0' NOT NULL,
  "approved_by" bigint DEFAULT '0' NOT NULL,
  "is_survey" smallint DEFAULT '0' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_poard_trash
CREATE TABLE "[[PREFIX]]_poard_trash" (
  "id" bigserial NOT NULL,
  "thread_id" bigint DEFAULT '0' NOT NULL,
  "msid" bigint DEFAULT '0' NOT NULL,
  "deleted_by" bigint DEFAULT '0' NOT NULL,
  "comment" character varying(64) DEFAULT '' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_poard_board
CREATE TABLE "[[PREFIX]]_poard_board" (
  "id" serial NOT NULL,
  "name" character varying(64) DEFAULT '' NOT NULL,
  "description" character varying(128) DEFAULT '' NOT NULL,
  "position" integer DEFAULT '0' NOT NULL,
  "parent_id" integer DEFAULT '0',
  "containMessages" smallint DEFAULT '0' NOT NULL,
  "groupRequired" integer DEFAULT '0',
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_poard_read_messages
CREATE TABLE "[[PREFIX]]_poard_read_messages" (
  "thread_id" bigint DEFAULT '0' NOT NULL,
  "user_id" bigint DEFAULT '0' NOT NULL,
  "position" integer DEFAULT '0' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  PRIMARY KEY ("user_id", "thread_id")
);



--
-- Table: [[PREFIX]]_survey
CREATE TABLE "[[PREFIX]]_survey" (
  "id" bigserial NOT NULL,
  "thread_id" bigint NOT NULL,
  "question" text DEFAULT '' NOT NULL,
  "votecount" integer DEFAULT '0' NOT NULL,
  "is_multiple" integer DEFAULT '0' NOT NULL,
  "status" varchar(16) DEFAULT 'onhold' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_survey_option
CREATE TABLE "[[PREFIX]]_survey_option" (
  "id" bigserial NOT NULL,
  "position" integer NOT NULL,
  "survey_id" bigint NOT NULL,
  "answer" text DEFAULT '' NOT NULL,
  "votecount" integer DEFAULT '0' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id"),
  Constraint "survey_option_position_survey_id" UNIQUE ("position", "survey_id")
);



--
-- Table: [[PREFIX]]_poard_message
CREATE TABLE "[[PREFIX]]_poard_message" (
  "id" bigserial NOT NULL,
  "thread_id" bigint DEFAULT '0' NOT NULL,
  "author_id" bigint DEFAULT '0' NOT NULL,
  "position" integer DEFAULT '0' NOT NULL,
  "lasteditor" bigint DEFAULT '0' NOT NULL,
  "approved_by" bigint DEFAULT '0' NOT NULL,
  "message" text DEFAULT '' NOT NULL,
  "author_name" character varying(32),
  "status" varchar(16) DEFAULT 'onhold' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_survey_vote
CREATE TABLE "[[PREFIX]]_survey_vote" (
  "id" bigserial NOT NULL,
  "user_id" bigint NOT NULL,
  "survey_id" bigint NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id"),
  Constraint "survey_vote_user_id_survey_id" UNIQUE ("user_id", "survey_id")
);



--
-- Table: [[PREFIX]]_poard_notify
CREATE TABLE "[[PREFIX]]_poard_notify" (
  "id" bigserial NOT NULL,
  "user_id" bigint NOT NULL,
  "thread_id" bigint DEFAULT '0' NOT NULL,
  "last_notified" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id"),
  Constraint "poard_notify_user_id_thread_id" UNIQUE ("user_id", "thread_id")
);

--
-- Foreign Key Definitions
--

ALTER TABLE "[[PREFIX]]_poard_thread" ADD FOREIGN KEY ("board_id")
  REFERENCES "[[PREFIX]]_poard_board" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "[[PREFIX]]_poard_read_messages" ADD FOREIGN KEY ("thread_id")
  REFERENCES "[[PREFIX]]_poard_thread" ("id");

ALTER TABLE "[[PREFIX]]_survey" ADD FOREIGN KEY ("thread_id")
  REFERENCES "[[PREFIX]]_poard_thread" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "[[PREFIX]]_survey_option" ADD FOREIGN KEY ("survey_id")
  REFERENCES "[[PREFIX]]_survey" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "[[PREFIX]]_poard_message" ADD FOREIGN KEY ("thread_id")
  REFERENCES "[[PREFIX]]_poard_thread" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "[[PREFIX]]_survey_vote" ADD FOREIGN KEY ("survey_id")
  REFERENCES "[[PREFIX]]_survey" ("id");

ALTER TABLE "[[PREFIX]]_poard_notify" ADD FOREIGN KEY ("thread_id")
  REFERENCES "[[PREFIX]]_poard_thread" ("id");
--
--
-- schema schema_system_0.01_002
--
--
--
-- Table: [[PREFIX]]_system_lang
CREATE TABLE "[[PREFIX]]_system_lang" (
  "id" character(5) NOT NULL,
  "name" character varying(128) NOT NULL,
  "fallback" character(5) NOT NULL,
  "active" smallint DEFAULT '0' NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_system_translation
CREATE TABLE "[[PREFIX]]_system_translation" (
  "id" character varying(128) NOT NULL,
  "lang" character(5) NOT NULL,
  "translation" text NOT NULL,
  Constraint "system_translation_id_lang" UNIQUE ("id", "lang")
);

--
--
-- schema schema_content_0.01_002
--
--
--
-- Table: [[PREFIX]]_news
CREATE TABLE "[[PREFIX]]_news" (
  "id" serial NOT NULL,
  "headline" character varying(256) NOT NULL,
  "message" text NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_content_page
CREATE TABLE "[[PREFIX]]_content_page" (
  "id" serial NOT NULL,
  "title" character varying(64) NOT NULL,
  "parent" integer DEFAULT '0' NOT NULL,
  "position" smallint DEFAULT '0' NOT NULL,
  "url" character varying(32) NOT NULL,
  "text" text NOT NULL,
  "markup" varchar(16) NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
--
-- schema schema_blog_0.01
--
--
--
-- Table: [[PREFIX]]_blog
CREATE TABLE "[[PREFIX]]_blog" (
  "id" serial NOT NULL,
  "title" character varying(256) NOT NULL,
  "image" character varying(256) NOT NULL,
  "created_by" integer NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_theme
CREATE TABLE "[[PREFIX]]_theme" (
  "id" serial NOT NULL,
  "blog_id" integer NOT NULL,
  "title" character varying(256) NOT NULL,
  "abstract" character varying(512) NOT NULL,
  "image" character varying(256) NOT NULL,
  "link" character varying(256) NOT NULL,
  "message" text NOT NULL,
  "posted_by" integer NOT NULL,
  "active" smallint NOT NULL,
  "is_news" smallint NOT NULL,
  "can_comment" smallint NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Foreign Key Definitions
--

ALTER TABLE "[[PREFIX]]_theme" ADD FOREIGN KEY ("blog_id")
  REFERENCES "[[PREFIX]]_blog" ("id") ON DELETE CASCADE ON UPDATE CASCADE;
--
--
-- schema schema_userlist_0.03
--
--
--
-- Table: [[PREFIX]]_user_list
CREATE TABLE "[[PREFIX]]_user_list" (
  "user_id" bigint NOT NULL,
  "last_seen" timestamp(0) NOT NULL,
  "logged_in" timestamp(0) NOT NULL,
  "visible" smallint DEFAULT '1' NOT NULL,
  PRIMARY KEY ("user_id")
);

--
--
-- schema schema_user_0.01_030
--
--
--
-- Table: [[PREFIX]]_pm
CREATE TABLE "[[PREFIX]]_pm" (
  "id" bigserial NOT NULL,
  "sender" bigint NOT NULL,
  "message" text NOT NULL,
  "subject" character varying(128) NOT NULL,
  "recipients" character varying(128) NOT NULL,
  "has_read" smallint NOT NULL,
  "copy_of" bigint NOT NULL,
  "box_id" integer NOT NULL,
  "sent_notify" smallint DEFAULT '1' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_user_profile
CREATE TABLE "[[PREFIX]]_user_profile" (
  "user_id" bigint NOT NULL,
  "name" character varying(64) DEFAULT '' NOT NULL,
  "email" character varying(64) DEFAULT '' NOT NULL,
  "homepage" character varying(128) DEFAULT '' NOT NULL,
  "avatar" character varying(37) DEFAULT '' NOT NULL,
  "location" character varying(64) DEFAULT '' NOT NULL,
  "signature" text,
  "sex" enum('f','m','t'),
  "icq" character varying(32),
  "aol" character varying(32),
  "yahoo" character varying(32),
  "msn" character varying(32),
  "interests" character varying(512),
  "foto_url" character varying(128),
  "birth_year" smallint,
  "birth_day" character(4),
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("user_id")
);



--
-- Table: [[PREFIX]]_role
CREATE TABLE "[[PREFIX]]_role" (
  "id" serial NOT NULL,
  "name" character varying(32) DEFAULT '' NOT NULL,
  "rtype" character varying(32) DEFAULT '' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_user_role
CREATE TABLE "[[PREFIX]]_user_role" (
  "role_id" integer NOT NULL,
  "user_id" bigint NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("role_id", "user_id")
);



--
-- Table: [[PREFIX]]_user_settings
CREATE TABLE "[[PREFIX]]_user_settings" (
  "user_id" bigserial NOT NULL,
  "messagecount" bigint DEFAULT '0' NOT NULL,
  "send_notify" smallint DEFAULT '0' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("user_id")
);



--
-- Table: [[PREFIX]]_poard_user
CREATE TABLE "[[PREFIX]]_poard_user" (
  "id" bigserial NOT NULL,
  "active" smallint DEFAULT '0' NOT NULL,
  "nick" character varying(32) DEFAULT '' NOT NULL,
  "password" character varying(32) DEFAULT '' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "lastlogin" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_action_token
CREATE TABLE "[[PREFIX]]_action_token" (
  "id" bigserial NOT NULL,
  "user_id" bigint DEFAULT '0' NOT NULL,
  "token" character varying(32) NOT NULL,
  "action" character varying(32) DEFAULT '',
  "info" text DEFAULT '',
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_message_recipient
CREATE TABLE "[[PREFIX]]_message_recipient" (
  "message_id" bigint NOT NULL,
  "recipient_id" bigint NOT NULL,
  "has_read" smallint NOT NULL,
  Constraint "message_recipient_message_id_recipient_id" UNIQUE ("message_id", "recipient_id")
);



--
-- Table: [[PREFIX]]_token
CREATE TABLE "[[PREFIX]]_token" (
  "id" character varying(32) NOT NULL,
  "id2" character varying(32) NOT NULL,
  "user_id" bigint DEFAULT '0' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("user_id")
);



--
-- Table: [[PREFIX]]_sessions
CREATE TABLE "[[PREFIX]]_sessions" (
  "id" character varying(32) NOT NULL,
  "a_session" text NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_postbox
CREATE TABLE "[[PREFIX]]_postbox" (
  "id" serial NOT NULL,
  "user_id" bigint NOT NULL,
  "name" character varying(64) DEFAULT '' NOT NULL,
  "type" varchar(16) DEFAULT 'in' NOT NULL,
  "is_default" smallint DEFAULT '0' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_user_abook
CREATE TABLE "[[PREFIX]]_user_abook" (
  "user_id" bigint NOT NULL,
  "contactid" bigint NOT NULL,
  "note" character varying(128),
  "blacklist" smallint DEFAULT '0' NOT NULL,
  "ctime" timestamp(0) DEFAULT '0000-00-00 00:00:00' NOT NULL,
  PRIMARY KEY ("user_id", "contactid")
);



--
-- Table: [[PREFIX]]_role_action
CREATE TABLE "[[PREFIX]]_role_action" (
  "id" serial NOT NULL,
  "role_id" integer NOT NULL,
  "action" character varying(128) NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Foreign Key Definitions
--

ALTER TABLE "[[PREFIX]]_pm" ADD FOREIGN KEY ("box_id")
  REFERENCES "[[PREFIX]]_postbox" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "[[PREFIX]]_user_role" ADD FOREIGN KEY ("user_id")
  REFERENCES "[[PREFIX]]_poard_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "[[PREFIX]]_user_role" ADD FOREIGN KEY ("role_id")
  REFERENCES "[[PREFIX]]_role" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "[[PREFIX]]_message_recipient" ADD FOREIGN KEY ("recipient_id")
  REFERENCES "[[PREFIX]]_poard_user" ("id");

ALTER TABLE "[[PREFIX]]_message_recipient" ADD FOREIGN KEY ("message_id")
  REFERENCES "[[PREFIX]]_pm" ("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "[[PREFIX]]_postbox" ADD FOREIGN KEY ("user_id")
  REFERENCES "[[PREFIX]]_poard_user" ("id");

ALTER TABLE "[[PREFIX]]_user_abook" ADD FOREIGN KEY ("user_id")
  REFERENCES "[[PREFIX]]_poard_user" ("id");

ALTER TABLE "[[PREFIX]]_user_abook" ADD FOREIGN KEY ("contactid")
  REFERENCES "[[PREFIX]]_poard_user" ("id");

ALTER TABLE "[[PREFIX]]_role_action" ADD FOREIGN KEY ("role_id")
  REFERENCES "[[PREFIX]]_role" ("id") ON DELETE CASCADE ON UPDATE CASCADE;
--
--
-- schema schema_gallery_0.01_002
--
--
--
-- Table: [[PREFIX]]_gallery_info
CREATE TABLE "[[PREFIX]]_gallery_info" (
  "id" serial NOT NULL,
  "created_by" integer NOT NULL,
  "title" character varying(255) NOT NULL,
  "image_count" integer DEFAULT '0' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);



--
-- Table: [[PREFIX]]_gallery_image
CREATE TABLE "[[PREFIX]]_gallery_image" (
  "id" serial NOT NULL,
  "info" integer NOT NULL,
  "position" smallint NOT NULL,
  "title" character varying(255) NOT NULL,
  "suffix" character varying(4) NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Foreign Key Definitions
--

ALTER TABLE "[[PREFIX]]_gallery_image" ADD FOREIGN KEY ("info")
  REFERENCES "[[PREFIX]]_gallery_info" ("id") ON DELETE CASCADE ON UPDATE CASCADE;
--
--
-- schema schema_log_0.01_002
--
--
--
-- Table: [[PREFIX]]_log
CREATE TABLE "[[PREFIX]]_log" (
  "id" bigserial NOT NULL,
  "user_id" bigint,
  "module" character varying(32) NOT NULL,
  "action" character varying(64) NOT NULL,
  "object_id" bigint,
  "object_type" character varying(64),
  "ip" character varying(16) NOT NULL,
  "forwarded_for" character varying(128),
  "comment" character varying(256),
  "referrer" character varying(256),
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

