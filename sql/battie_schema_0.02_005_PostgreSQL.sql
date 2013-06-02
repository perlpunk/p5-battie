-- Schema for Battie 0.02_005

--
--
-- schema schema_poard_0.01_023
--
--
-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Sat Feb 25 19:13:52 2012
-- 
--
-- Table: TABLE_PREFIX_poard_archived_message
--
CREATE TABLE "TABLE_PREFIX_poard_archived_message" (
  "id" bigserial NOT NULL,
  "msg_id" integer NOT NULL,
  "lasteditor_id" integer,
  "thread_id" integer NOT NULL,
  "message" text,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_poard_board
--
CREATE TABLE "TABLE_PREFIX_poard_board" (
  "id" serial NOT NULL,
  "flags" integer DEFAULT 0 NOT NULL,
  "name" character varying(64) DEFAULT '' NOT NULL,
  "description" character varying(256) DEFAULT '' NOT NULL,
  "position" integer DEFAULT 0 NOT NULL,
  "lft" integer,
  "rgt" integer,
  "parent_id" integer DEFAULT 0,
  "containmessages" integer DEFAULT 0 NOT NULL,
  "grouprequired" integer DEFAULT 0,
  "meta" text,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_poard_tag
--
CREATE TABLE "TABLE_PREFIX_poard_tag" (
  "id" bigserial NOT NULL,
  "name" character varying(128) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "poard_tag_name" UNIQUE ("name")
);

--
-- Table: TABLE_PREFIX_poard_user_tag
--
CREATE TABLE "TABLE_PREFIX_poard_user_tag" (
  "tag_id" integer NOT NULL,
  "user_id" integer NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("tag_id", "user_id")
);
CREATE INDEX "TABLE_PREFIX_poard_user_tag_idx_tag_id" on "TABLE_PREFIX_poard_user_tag" ("tag_id");

--
-- Table: TABLE_PREFIX_poard_message
--
CREATE TABLE "TABLE_PREFIX_poard_message" (
  "id" bigserial NOT NULL,
  "title" character varying(128),
  "thread_id" integer DEFAULT 0 NOT NULL,
  "author_id" integer DEFAULT 0 NOT NULL,
  "position" integer DEFAULT 0 NOT NULL,
  "changelog" integer DEFAULT 0 NOT NULL,
  "has_attachment" integer DEFAULT 0 NOT NULL,
  "lft" integer,
  "rgt" integer,
  "lasteditor" integer DEFAULT 0 NOT NULL,
  "approved_by" integer DEFAULT 0 NOT NULL,
  "message" text DEFAULT '' NOT NULL,
  "author_name" character varying(32),
  "status" varchar(16) DEFAULT 'onhold' NOT NULL,
  "mtime" timestamp NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "TABLE_PREFIX_poard_message_idx_thread_id" on "TABLE_PREFIX_poard_message" ("thread_id");

--
-- Table: TABLE_PREFIX_poard_notify
--
CREATE TABLE "TABLE_PREFIX_poard_notify" (
  "id" bigserial NOT NULL,
  "user_id" integer NOT NULL,
  "thread_id" integer NOT NULL,
  "msg_id" integer,
  "last_notified" timestamp NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "poard_notify_user_id_thread_id" UNIQUE ("user_id", "thread_id")
);
CREATE INDEX "TABLE_PREFIX_poard_notify_idx_thread_id" on "TABLE_PREFIX_poard_notify" ("thread_id");

--
-- Table: TABLE_PREFIX_poard_read_messages
--
CREATE TABLE "TABLE_PREFIX_poard_read_messages" (
  "thread_id" integer DEFAULT 0 NOT NULL,
  "user_id" integer DEFAULT 0 NOT NULL,
  "position" integer DEFAULT 0 NOT NULL,
  "mtime" timestamp NOT NULL,
  "meta" text,
  PRIMARY KEY ("user_id", "thread_id")
);
CREATE INDEX "TABLE_PREFIX_poard_read_messages_idx_thread_id" on "TABLE_PREFIX_poard_read_messages" ("thread_id");

--
-- Table: TABLE_PREFIX_survey
--
CREATE TABLE "TABLE_PREFIX_survey" (
  "id" bigserial NOT NULL,
  "thread_id" integer NOT NULL,
  "question" text DEFAULT '' NOT NULL,
  "votecount" integer DEFAULT 0 NOT NULL,
  "is_multiple" integer DEFAULT 0 NOT NULL,
  "status" varchar(16) DEFAULT 'onhold' NOT NULL,
  "mtime" timestamp NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "TABLE_PREFIX_survey_idx_thread_id" on "TABLE_PREFIX_survey" ("thread_id");

--
-- Table: TABLE_PREFIX_poard_attachment
--
CREATE TABLE "TABLE_PREFIX_poard_attachment" (
  "message_id" integer NOT NULL,
  "attach_id" integer NOT NULL,
  "type" character varying(32) NOT NULL,
  "filename" character varying(32) NOT NULL,
  "meta" character varying(256) NOT NULL,
  "size" integer NOT NULL,
  "deleted" integer DEFAULT 0 NOT NULL,
  "thumb" integer DEFAULT 0 NOT NULL,
  "ctime" timestamp NOT NULL,
  "mtime" timestamp NOT NULL,
  PRIMARY KEY ("message_id", "attach_id")
);
CREATE INDEX "TABLE_PREFIX_poard_attachment_idx_message_id" on "TABLE_PREFIX_poard_attachment" ("message_id");

--
-- Table: TABLE_PREFIX_poard_msglog
--
CREATE TABLE "TABLE_PREFIX_poard_msglog" (
  "message_id" integer NOT NULL,
  "log_id" integer NOT NULL,
  "action" character varying(64) NOT NULL,
  "comment" character varying(256),
  "user_id" integer NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("message_id", "log_id")
);
CREATE INDEX "TABLE_PREFIX_poard_msglog_idx_message_id" on "TABLE_PREFIX_poard_msglog" ("message_id");

--
-- Table: TABLE_PREFIX_poard_thread_tag
--
CREATE TABLE "TABLE_PREFIX_poard_thread_tag" (
  "tag_id" integer NOT NULL,
  "thread_id" integer NOT NULL,
  PRIMARY KEY ("tag_id", "thread_id")
);
CREATE INDEX "TABLE_PREFIX_poard_thread_tag_idx_tag_id" on "TABLE_PREFIX_poard_thread_tag" ("tag_id");
CREATE INDEX "TABLE_PREFIX_poard_thread_tag_idx_thread_id" on "TABLE_PREFIX_poard_thread_tag" ("thread_id");

--
-- Table: TABLE_PREFIX_survey_option
--
CREATE TABLE "TABLE_PREFIX_survey_option" (
  "id" bigserial NOT NULL,
  "position" integer NOT NULL,
  "survey_id" integer NOT NULL,
  "answer" text DEFAULT '' NOT NULL,
  "votecount" integer DEFAULT 0 NOT NULL,
  "mtime" timestamp NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "survey_option_position_survey_id" UNIQUE ("position", "survey_id")
);
CREATE INDEX "TABLE_PREFIX_survey_option_idx_survey_id" on "TABLE_PREFIX_survey_option" ("survey_id");

--
-- Table: TABLE_PREFIX_survey_vote
--
CREATE TABLE "TABLE_PREFIX_survey_vote" (
  "id" bigserial NOT NULL,
  "user_id" integer NOT NULL,
  "survey_id" integer NOT NULL,
  "ctime" timestamp NOT NULL,
  "meta" text NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "survey_vote_user_id_survey_id" UNIQUE ("user_id", "survey_id")
);
CREATE INDEX "TABLE_PREFIX_survey_vote_idx_survey_id" on "TABLE_PREFIX_survey_vote" ("survey_id");

--
-- Table: TABLE_PREFIX_poard_thread
--
CREATE TABLE "TABLE_PREFIX_poard_thread" (
  "id" bigserial NOT NULL,
  "title" character varying(128) DEFAULT '' NOT NULL,
  "meta" text,
  "author_id" integer NOT NULL,
  "author_name" character varying(32),
  "status" varchar(16) DEFAULT 'onhold' NOT NULL,
  "fixed" integer DEFAULT '0' NOT NULL,
  "solved" integer DEFAULT '0' NOT NULL,
  "is_tree" integer DEFAULT '0' NOT NULL,
  "closed" integer DEFAULT '0' NOT NULL,
  "board_id" integer NOT NULL,
  "read_count" integer DEFAULT '0',
  "messagecount" integer DEFAULT '0' NOT NULL,
  "approved_by" integer DEFAULT '0' NOT NULL,
  "is_survey" integer DEFAULT '0' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_poard_trash
--
CREATE TABLE "TABLE_PREFIX_poard_trash" (
  "id" bigserial NOT NULL,
  "thread_id" integer DEFAULT '0' NOT NULL,
  "msid" integer DEFAULT '0' NOT NULL,
  "deleted_by" integer DEFAULT '0' NOT NULL,
  "comment" character varying(64) DEFAULT '' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Foreign Key Definitions
--

ALTER TABLE "TABLE_PREFIX_poard_message" ADD FOREIGN KEY ("thread_id")
  REFERENCES "TABLE_PREFIX_poard_thread" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_poard_notify" ADD FOREIGN KEY ("thread_id")
  REFERENCES "TABLE_PREFIX_poard_thread" ("id") DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_poard_read_messages" ADD FOREIGN KEY ("thread_id")
  REFERENCES "TABLE_PREFIX_poard_thread" ("id") DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_survey" ADD FOREIGN KEY ("thread_id")
  REFERENCES "TABLE_PREFIX_poard_thread" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_poard_attachment" ADD FOREIGN KEY ("message_id")
  REFERENCES "TABLE_PREFIX_poard_message" ("id") DEFERRABLE;
ALTER TABLE "TABLE_PREFIX_survey_option" ADD FOREIGN KEY ("survey_id")
  REFERENCES "TABLE_PREFIX_survey" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_survey_vote" ADD FOREIGN KEY ("survey_id")
  REFERENCES "TABLE_PREFIX_survey" ("id") DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_poard_thread" ADD FOREIGN KEY ("board_id")
  REFERENCES "TABLE_PREFIX_poard_board" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;
--
--
-- schema schema_system_0.01_004
--
--
-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Sat Feb 27 17:53:07 2010
-- 
--
-- Table: TABLE_PREFIX_system_lang
--
CREATE TABLE "TABLE_PREFIX_system_lang" (
  "id" character(5) NOT NULL,
  "name" character varying(128) NOT NULL,
  "fallback" character(5) NOT NULL,
  "active" integer DEFAULT 0 NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_system_term_user
--
CREATE TABLE "TABLE_PREFIX_system_term_user" (
  "term_id" character(32) NOT NULL,
  "user_id" integer NOT NULL,
  "start_date" timestamp NOT NULL,
  PRIMARY KEY ("term_id", "start_date", "user_id")
);

--
-- Table: TABLE_PREFIX_system_terms
--
CREATE TABLE "TABLE_PREFIX_system_terms" (
  "id" character(32) NOT NULL,
  "name" character varying(128) NOT NULL,
  "style" character varying(16) NOT NULL,
  "content" text,
  "start_date" timestamp NOT NULL,
  PRIMARY KEY ("id", "start_date")
);

--
-- Table: TABLE_PREFIX_system_translation
--
CREATE TABLE "TABLE_PREFIX_system_translation" (
  "id" character varying(128) NOT NULL,
  "lang" character(5) NOT NULL,
  "translation" text NOT NULL,
  "plural" text,
  CONSTRAINT "system_translation_id_lang" UNIQUE ("id", "lang")
);

--
--
-- schema schema_content_0.01_003
--
--
-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Thu Sep 10 22:00:56 2009
-- 
--
-- Table: TABLE_PREFIX_content_motd
--
CREATE TABLE "TABLE_PREFIX_content_motd" (
  "id" serial NOT NULL,
  "weight" integer NOT NULL,
  "content" text,
  "start" timestamp NOT NULL,
  "end" timestamp NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_news
--
CREATE TABLE "TABLE_PREFIX_news" (
  "id" serial NOT NULL,
  "headline" character varying(256) NOT NULL,
  "message" text NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_content_page
--
CREATE TABLE "TABLE_PREFIX_content_page" (
  "id" serial NOT NULL,
  "title" character varying(64) NOT NULL,
  "parent" integer DEFAULT '0' NOT NULL,
  "position" integer DEFAULT '0' NOT NULL,
  "url" character varying(32) NOT NULL,
  "text" text NOT NULL,
  "markup" character varying(16) DEFAULT 'html' NOT NULL,
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
-- Table: TABLE_PREFIX_blog
--
CREATE TABLE "TABLE_PREFIX_blog" (
  "id" serial NOT NULL,
  "title" character varying(256) NOT NULL,
  "image" character varying(256),
  "created_by" integer NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_theme
--
CREATE TABLE "TABLE_PREFIX_theme" (
  "id" serial NOT NULL,
  "blog_id" integer NOT NULL,
  "title" character varying(256) NOT NULL,
  "abstract" character varying(512) NOT NULL,
  "image" character varying(256),
  "link" character varying(256) NOT NULL,
  "message" text,
  "posted_by" integer NOT NULL,
  "active" integer DEFAULT 0 NOT NULL,
  "is_news" integer DEFAULT 0 NOT NULL,
  "can_comment" integer DEFAULT 0 NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Foreign Key Definitions
--

ALTER TABLE "TABLE_PREFIX_theme" ADD FOREIGN KEY ("blog_id")
  REFERENCES "TABLE_PREFIX_blog" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;
--
--
-- schema schema_userlist_0.05
--
--
-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Tue Mar 20 21:53:14 2012
-- 
--
-- Table: TABLE_PREFIX_au_session
--
CREATE TABLE "TABLE_PREFIX_au_session" (
  "id" character(64) NOT NULL,
  "user_id" integer,
  "data" text,
  "ctime" integer DEFAULT 0 NOT NULL,
  "mtime" integer DEFAULT 0 NOT NULL,
  "expires" integer DEFAULT 0 NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_chatterbox
--
CREATE TABLE "TABLE_PREFIX_chatterbox" (
  "user_id" integer NOT NULL,
  "seq" integer NOT NULL,
  "msg" character varying(256) NOT NULL,
  "ctime" timestamp NOT NULL,
  "rec" integer
);

--
-- Table: TABLE_PREFIX_user_list
--
CREATE TABLE "TABLE_PREFIX_user_list" (
  "user_id" integer NOT NULL,
  "last_seen" timestamp,
  "logged_in" timestamp NOT NULL,
  "visible" integer DEFAULT 1 NOT NULL,
  PRIMARY KEY ("user_id")
);

--
--
-- schema schema_user_0.01_032
--
--
-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Sat Feb 25 19:13:52 2012
-- 
--
-- Table: TABLE_PREFIX_action_token
--
CREATE TABLE "TABLE_PREFIX_action_token" (
  "id" bigserial NOT NULL,
  "user_id" integer DEFAULT 0 NOT NULL,
  "token" character varying(32) NOT NULL,
  "action" character varying(32) DEFAULT '',
  "info" text DEFAULT '',
  "mtime" timestamp NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_group
--
CREATE TABLE "TABLE_PREFIX_group" (
  "id" serial NOT NULL,
  "name" character varying(64) DEFAULT '' NOT NULL,
  "rtype" character varying(32) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_poard_user
--
CREATE TABLE "TABLE_PREFIX_poard_user" (
  "id" bigserial NOT NULL,
  "group_id" integer DEFAULT 0 NOT NULL,
  "extra_roles" integer DEFAULT 0 NOT NULL,
  "active" integer DEFAULT 0 NOT NULL,
  "nick" character varying(64) DEFAULT '' NOT NULL,
  "password" character varying(32) DEFAULT '' NOT NULL,
  "mtime" timestamp NOT NULL,
  "lastlogin" timestamp,
  "openid" character varying(16),
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "poard_user_nick" UNIQUE ("nick")
);

--
-- Table: TABLE_PREFIX_role
--
CREATE TABLE "TABLE_PREFIX_role" (
  "id" serial NOT NULL,
  "name" character varying(32) DEFAULT '' NOT NULL,
  "rtype" character varying(32) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_sessions
--
CREATE TABLE "TABLE_PREFIX_sessions" (
  "id" character varying(32) NOT NULL,
  "a_session" text NOT NULL,
  "mtime" timestamp,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_token
--
CREATE TABLE "TABLE_PREFIX_token" (
  "id" character varying(32) NOT NULL,
  "id2" character varying(32) NOT NULL,
  "user_id" integer DEFAULT 0 NOT NULL,
  "mtime" timestamp NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("user_id")
);

--
-- Table: TABLE_PREFIX_user_my_nodelet
--
CREATE TABLE "TABLE_PREFIX_user_my_nodelet" (
  "user_id" integer NOT NULL,
  "content" text NOT NULL,
  "is_open" integer DEFAULT 1 NOT NULL,
  PRIMARY KEY ("user_id")
);

--
-- Table: TABLE_PREFIX_user_profile
--
CREATE TABLE "TABLE_PREFIX_user_profile" (
  "user_id" integer NOT NULL,
  "name" character varying(64) DEFAULT '' NOT NULL,
  "email" character varying(128) DEFAULT '' NOT NULL,
  "homepage" character varying(128) DEFAULT '' NOT NULL,
  "geo" character varying(21),
  "avatar" character varying(37) DEFAULT '' NOT NULL,
  "location" character varying(64) DEFAULT '' NOT NULL,
  "signature" text,
  "sex" char(1),
  "icq" character varying(32),
  "aol" character varying(32),
  "yahoo" character varying(32),
  "msn" character varying(32),
  "interests" character varying(512),
  "foto_url" character varying(128),
  "birth_year" integer,
  "birth_day" character(4),
  "mtime" timestamp NOT NULL,
  "ctime" timestamp NOT NULL,
  "meta" text,
  PRIMARY KEY ("user_id")
);

--
-- Table: TABLE_PREFIX_users_new_user
--
CREATE TABLE "TABLE_PREFIX_users_new_user" (
  "id" bigserial NOT NULL,
  "token" character varying(32) NOT NULL,
  "email" character varying(128) DEFAULT '' NOT NULL,
  "nick" character varying(64) DEFAULT '' NOT NULL,
  "password" character varying(32) DEFAULT '' NOT NULL,
  "openid" character varying(16),
  "meta" text,
  "mtime" timestamp NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "users_new_user_nick" UNIQUE ("nick")
);

--
-- Table: TABLE_PREFIX_postbox
--
CREATE TABLE "TABLE_PREFIX_postbox" (
  "id" serial NOT NULL,
  "user_id" integer NOT NULL,
  "name" character varying(64) DEFAULT '' NOT NULL,
  "type" varchar(16) DEFAULT 'in' NOT NULL,
  "is_default" integer DEFAULT 0 NOT NULL,
  "mtime" timestamp NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "TABLE_PREFIX_postbox_idx_user_id" on "TABLE_PREFIX_postbox" ("user_id");

--
-- Table: TABLE_PREFIX_role_action
--
CREATE TABLE "TABLE_PREFIX_role_action" (
  "id" serial NOT NULL,
  "role_id" integer NOT NULL,
  "action" character varying(128) NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "TABLE_PREFIX_role_action_idx_role_id" on "TABLE_PREFIX_role_action" ("role_id");

--
-- Table: TABLE_PREFIX_user_abook
--
CREATE TABLE "TABLE_PREFIX_user_abook" (
  "user_id" integer NOT NULL,
  "contactid" integer NOT NULL,
  "note" character varying(128),
  "blacklist" integer DEFAULT 0 NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("user_id", "contactid")
);
CREATE INDEX "TABLE_PREFIX_user_abook_idx_contactid" on "TABLE_PREFIX_user_abook" ("contactid");
CREATE INDEX "TABLE_PREFIX_user_abook_idx_user_id" on "TABLE_PREFIX_user_abook" ("user_id");

--
-- Table: TABLE_PREFIX_user_settings
--
CREATE TABLE "TABLE_PREFIX_user_settings" (
  "user_id" bigserial NOT NULL,
  "messagecount" integer DEFAULT 0 NOT NULL,
  "send_notify" integer DEFAULT 0 NOT NULL,
  "mtime" timestamp NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("user_id")
);

--
-- Table: TABLE_PREFIX_group_role
--
CREATE TABLE "TABLE_PREFIX_group_role" (
  "group_id" integer NOT NULL,
  "role_id" integer NOT NULL,
  PRIMARY KEY ("group_id", "role_id")
);
CREATE INDEX "TABLE_PREFIX_group_role_idx_group_id" on "TABLE_PREFIX_group_role" ("group_id");
CREATE INDEX "TABLE_PREFIX_group_role_idx_role_id" on "TABLE_PREFIX_group_role" ("role_id");

--
-- Table: TABLE_PREFIX_pm
--
CREATE TABLE "TABLE_PREFIX_pm" (
  "id" bigserial NOT NULL,
  "sender" integer NOT NULL,
  "message" text NOT NULL,
  "subject" character varying(128) NOT NULL,
  "recipients" character varying(128) NOT NULL,
  "has_read" integer NOT NULL,
  "copy_of" integer NOT NULL,
  "box_id" integer NOT NULL,
  "sent_notify" integer DEFAULT 1 NOT NULL,
  "mtime" timestamp NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "TABLE_PREFIX_pm_idx_box_id" on "TABLE_PREFIX_pm" ("box_id");

--
-- Table: TABLE_PREFIX_user_role
--
CREATE TABLE "TABLE_PREFIX_user_role" (
  "role_id" integer NOT NULL,
  "user_id" integer NOT NULL,
  "mtime" timestamp NOT NULL,
  "ctime" timestamp NOT NULL,
  PRIMARY KEY ("role_id", "user_id")
);
CREATE INDEX "TABLE_PREFIX_user_role_idx_role_id" on "TABLE_PREFIX_user_role" ("role_id");
CREATE INDEX "TABLE_PREFIX_user_role_idx_user_id" on "TABLE_PREFIX_user_role" ("user_id");

--
-- Table: TABLE_PREFIX_message_recipient
--
CREATE TABLE "TABLE_PREFIX_message_recipient" (
  "message_id" integer NOT NULL,
  "recipient_id" integer NOT NULL,
  "has_read" integer NOT NULL,
  CONSTRAINT "message_recipient_message_id_recipient_id" UNIQUE ("message_id", "recipient_id")
);
CREATE INDEX "TABLE_PREFIX_message_recipient_idx_message_id" on "TABLE_PREFIX_message_recipient" ("message_id");
CREATE INDEX "TABLE_PREFIX_message_recipient_idx_recipient_id" on "TABLE_PREFIX_message_recipient" ("recipient_id");

--
-- Foreign Key Definitions
--

ALTER TABLE "TABLE_PREFIX_postbox" ADD FOREIGN KEY ("user_id")
  REFERENCES "TABLE_PREFIX_poard_user" ("id") DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_role_action" ADD FOREIGN KEY ("role_id")
  REFERENCES "TABLE_PREFIX_role" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_user_abook" ADD FOREIGN KEY ("contactid")
  REFERENCES "TABLE_PREFIX_poard_user" ("id") DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_user_abook" ADD FOREIGN KEY ("user_id")
  REFERENCES "TABLE_PREFIX_poard_user" ("id") DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_user_settings" ADD FOREIGN KEY ("user_id")
  REFERENCES "TABLE_PREFIX_poard_user" ("id") ON DELETE CASCADE DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_group_role" ADD FOREIGN KEY ("group_id")
  REFERENCES "TABLE_PREFIX_group" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_group_role" ADD FOREIGN KEY ("role_id")
  REFERENCES "TABLE_PREFIX_role" ("id") DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_pm" ADD FOREIGN KEY ("box_id")
  REFERENCES "TABLE_PREFIX_postbox" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_user_role" ADD FOREIGN KEY ("role_id")
  REFERENCES "TABLE_PREFIX_role" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_user_role" ADD FOREIGN KEY ("user_id")
  REFERENCES "TABLE_PREFIX_poard_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_message_recipient" ADD FOREIGN KEY ("message_id")
  REFERENCES "TABLE_PREFIX_pm" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_message_recipient" ADD FOREIGN KEY ("recipient_id")
  REFERENCES "TABLE_PREFIX_poard_user" ("id") DEFERRABLE;

--
--
-- schema schema_gallery_0.01_002
--
--
--
-- Table: TABLE_PREFIX_gallery_category
--
CREATE TABLE "TABLE_PREFIX_gallery_category" (
  "id" serial NOT NULL,
  "parent_id" integer NOT NULL,
  "left_id" integer NOT NULL,
  "right_id" integer NOT NULL,
  "title" character varying(255) NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_gallery_image
--
CREATE TABLE "TABLE_PREFIX_gallery_image" (
  "id" serial NOT NULL,
  "info" integer NOT NULL,
  "position" integer NOT NULL,
  "title" character varying(255) NOT NULL,
  "suffix" character varying(4) NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: TABLE_PREFIX_gallery_info
--
CREATE TABLE "TABLE_PREFIX_gallery_info" (
  "id" serial NOT NULL,
  "cat_id" integer NOT NULL,
  "created_by" integer NOT NULL,
  "title" character varying(255) NOT NULL,
  "image_count" integer DEFAULT '0' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Foreign Key Definitions
--

ALTER TABLE "TABLE_PREFIX_gallery_image" ADD FOREIGN KEY ("info")
  REFERENCES "TABLE_PREFIX_gallery_info" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE "TABLE_PREFIX_gallery_info" ADD FOREIGN KEY ("cat_id")
  REFERENCES "TABLE_PREFIX_gallery_category" ("id") DEFERRABLE;
-- schema schema_guest_0.01_002
--
--
--
-- Table: TABLE_PREFIX_guest_book_entry
--
CREATE TABLE "TABLE_PREFIX_guest_book_entry" (
  "id" bigserial NOT NULL,
  "name" character varying(64) NOT NULL,
  "email" character varying(128),
  "url" character varying(128),
  "location" character varying(64),
  "message" text NOT NULL,
  "comment" text,
  "comment_by" integer,
  "approved_by" integer,
  "active" integer DEFAULT '0' NOT NULL,
  "mtime" timestamp(0) NOT NULL,
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

--
--
-- schema schema_log_0.01_002
--
--
--
-- Table: TABLE_PREFIX_log
--
CREATE TABLE "TABLE_PREFIX_log" (
  "id" bigserial NOT NULL,
  "user_id" integer,
  "module" character varying(32) NOT NULL,
  "action" character varying(64) NOT NULL,
  "object_id" integer,
  "object_type" character varying(64),
  "ip" character varying(16) NOT NULL,
  "country" character(2),
  "city" character varying(32),
  "forwarded_for" character varying(128),
  "comment" character varying(256),
  "referrer" character varying(256),
  "ctime" timestamp(0) NOT NULL,
  PRIMARY KEY ("id")
);

