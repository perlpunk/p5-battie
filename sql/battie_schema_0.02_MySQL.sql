-- Schema for Battie 0.02

--
--
-- schema schema_poard_0.01_017
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Nov 29 20:51:44 2007
-- 
SET foreign_key_checks=0;

--
-- Table: `[[PREFIX]]_poard_thread`
--
CREATE TABLE `[[PREFIX]]_poard_thread` (
  `id` bigint(20) NOT NULL auto_increment,
  `title` varchar(128) NOT NULL DEFAULT '',
  `author_id` integer(20) NOT NULL,
  `author_name` varchar(32),
  `status` ENUM('active','deleted','onhold') NOT NULL DEFAULT 'onhold',
  `fixed` tinyint(1) NOT NULL DEFAULT '0',
  `closed` tinyint(1) NOT NULL DEFAULT '0',
  `board_id` integer(5) NOT NULL,
  `read_count` integer(10) DEFAULT '0',
  `messagecount` integer(10) NOT NULL DEFAULT '0',
  `approved_by` integer(20) NOT NULL DEFAULT '0',
  `is_survey` tinyint(1) NOT NULL DEFAULT '0',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  INDEX (`board_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `[[PREFIX]]_poard_thread_fk_board_id` FOREIGN KEY (`board_id`) REFERENCES `[[PREFIX]]_poard_board` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_poard_trash`
--
CREATE TABLE `[[PREFIX]]_poard_trash` (
  `id` bigint(20) NOT NULL auto_increment,
  `thread_id` bigint(20) NOT NULL DEFAULT '0',
  `msid` bigint(20) NOT NULL DEFAULT '0',
  `deleted_by` bigint(20) NOT NULL DEFAULT '0',
  `comment` varchar(64) NOT NULL DEFAULT '',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  PRIMARY KEY (`id`)
);

--
-- Table: `[[PREFIX]]_poard_board`
--
CREATE TABLE `[[PREFIX]]_poard_board` (
  `id` integer(5) NOT NULL auto_increment,
  `name` varchar(64) NOT NULL DEFAULT '',
  `description` varchar(128) NOT NULL DEFAULT '',
  `position` integer(5) NOT NULL DEFAULT '0',
  `parent_id` integer(5) DEFAULT '0',
  `containMessages` integer(1) NOT NULL DEFAULT '0',
  `groupRequired` integer(10) DEFAULT '0',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  PRIMARY KEY (`id`)
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_poard_read_messages`
--
CREATE TABLE `[[PREFIX]]_poard_read_messages` (
  `thread_id` bigint(20) NOT NULL DEFAULT '0',
  `user_id` bigint(20) NOT NULL DEFAULT '0',
  `position` integer(10) NOT NULL DEFAULT '0',
  `mtime` timestamp NOT NULL,
  INDEX (`user_id`),
  INDEX (`thread_id`),
  PRIMARY KEY (`user_id`, `thread_id`),
  CONSTRAINT `[[PREFIX]]_poard_read_messages_fk_thread_id` FOREIGN KEY (`thread_id`) REFERENCES `[[PREFIX]]_poard_thread` (`id`)
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_survey`
--
CREATE TABLE `[[PREFIX]]_survey` (
  `id` bigint(20) NOT NULL auto_increment,
  `thread_id` bigint(20) NOT NULL,
  `question` text NOT NULL DEFAULT '',
  `votecount` integer(10) NOT NULL DEFAULT '0',
  `is_multiple` integer(5) NOT NULL DEFAULT '0',
  `status` ENUM('onhold','active','deleted') NOT NULL DEFAULT 'onhold',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  INDEX (`thread_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `[[PREFIX]]_survey_fk_thread_id` FOREIGN KEY (`thread_id`) REFERENCES `[[PREFIX]]_poard_thread` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_survey_option`
--
CREATE TABLE `[[PREFIX]]_survey_option` (
  `id` bigint(20) NOT NULL auto_increment,
  `position` integer(5) NOT NULL,
  `survey_id` bigint(20) NOT NULL,
  `answer` text NOT NULL DEFAULT '',
  `votecount` integer(10) NOT NULL DEFAULT '0',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  INDEX (`position`),
  INDEX (`survey_id`),
  PRIMARY KEY (`id`),
  UNIQUE `survey_option_position_survey_id` (`position`, `survey_id`),
  CONSTRAINT `[[PREFIX]]_survey_option_fk_survey_id` FOREIGN KEY (`survey_id`) REFERENCES `[[PREFIX]]_survey` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_poard_message`
--
CREATE TABLE `[[PREFIX]]_poard_message` (
  `id` bigint(20) NOT NULL auto_increment,
  `thread_id` bigint(20) NOT NULL DEFAULT '0',
  `author_id` integer(20) NOT NULL DEFAULT '0',
  `position` integer(10) NOT NULL DEFAULT '0',
  `lasteditor` integer(20) NOT NULL DEFAULT '0',
  `approved_by` integer(20) NOT NULL DEFAULT '0',
  `message` text NOT NULL DEFAULT '',
  `author_name` varchar(32),
  `status` ENUM('active','deleted','onhold') NOT NULL DEFAULT 'onhold',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  INDEX (`thread_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `[[PREFIX]]_poard_message_fk_thread_id` FOREIGN KEY (`thread_id`) REFERENCES `[[PREFIX]]_poard_thread` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_survey_vote`
--
CREATE TABLE `[[PREFIX]]_survey_vote` (
  `id` bigint(20) NOT NULL auto_increment,
  `user_id` bigint(20) NOT NULL,
  `survey_id` bigint(20) NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  INDEX (`user_id`),
  INDEX (`survey_id`),
  PRIMARY KEY (`id`),
  UNIQUE `survey_vote_user_id_survey_id` (`user_id`, `survey_id`),
  CONSTRAINT `[[PREFIX]]_survey_vote_fk_survey_id` FOREIGN KEY (`survey_id`) REFERENCES `[[PREFIX]]_survey` (`id`)
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_poard_notify`
--
CREATE TABLE `[[PREFIX]]_poard_notify` (
  `id` bigint(20) NOT NULL auto_increment,
  `user_id` bigint(20) NOT NULL,
  `thread_id` bigint(20) NOT NULL DEFAULT '0',
  `last_notified` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  INDEX (`user_id`),
  INDEX (`thread_id`),
  PRIMARY KEY (`id`),
  UNIQUE `poard_notify_user_id_thread_id` (`user_id`, `thread_id`),
  CONSTRAINT `[[PREFIX]]_poard_notify_fk_thread_id` FOREIGN KEY (`thread_id`) REFERENCES `[[PREFIX]]_poard_thread` (`id`)
) Type=InnoDB;

SET foreign_key_checks=1;

--
--
-- schema schema_system_0.01_002
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Nov 29 20:51:44 2007
-- 
SET foreign_key_checks=0;

--
-- Table: `[[PREFIX]]_system_lang`
--
CREATE TABLE `[[PREFIX]]_system_lang` (
  `id` char(5) NOT NULL,
  `name` varchar(128) NOT NULL,
  `fallback` char(5) NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  INDEX (`id`),
  PRIMARY KEY (`id`)
);

--
-- Table: `[[PREFIX]]_system_translation`
--
CREATE TABLE `[[PREFIX]]_system_translation` (
  `id` varchar(128) NOT NULL,
  `lang` char(5) NOT NULL,
  `translation` text NOT NULL,
  INDEX (`id`),
  UNIQUE `system_translation_id_lang` (`id`, `lang`)
);

SET foreign_key_checks=1;

--
--
-- schema schema_content_0.01_002
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Nov 29 20:51:44 2007
-- 
SET foreign_key_checks=0;

--
-- Table: `[[PREFIX]]_news`
--
CREATE TABLE `[[PREFIX]]_news` (
  `id` integer(10) NOT NULL auto_increment,
  `headline` text NOT NULL,
  `message` text NOT NULL,
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  PRIMARY KEY (`id`)
);

--
-- Table: `[[PREFIX]]_content_page`
--
CREATE TABLE `[[PREFIX]]_content_page` (
  `id` integer(10) NOT NULL auto_increment,
  `title` varchar(64) NOT NULL,
  `parent` integer(10) NOT NULL DEFAULT '0',
  `position` integer(4) NOT NULL DEFAULT '0',
  `url` varchar(32) NOT NULL,
  `text` text NOT NULL,
  `markup` ENUM('html','textile') NOT NULL,
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  PRIMARY KEY (`id`)
);

SET foreign_key_checks=1;

--
--
-- schema schema_blog_0.01
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Nov 29 20:51:44 2007
-- 
SET foreign_key_checks=0;

--
-- Table: `[[PREFIX]]_blog`
--
CREATE TABLE `[[PREFIX]]_blog` (
  `id` integer(10) NOT NULL auto_increment,
  `title` text NOT NULL,
  `image` text NOT NULL,
  `created_by` integer(10) NOT NULL,
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  PRIMARY KEY (`id`)
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_theme`
--
CREATE TABLE `[[PREFIX]]_theme` (
  `id` integer(10) NOT NULL auto_increment,
  `blog_id` integer(10) NOT NULL,
  `title` text NOT NULL,
  `abstract` text NOT NULL,
  `image` text NOT NULL,
  `link` text NOT NULL,
  `message` text NOT NULL,
  `posted_by` integer(10) NOT NULL,
  `active` integer(1) NOT NULL,
  `is_news` integer(1) NOT NULL,
  `can_comment` integer(1) NOT NULL,
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  INDEX (`blog_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `[[PREFIX]]_theme_fk_blog_id` FOREIGN KEY (`blog_id`) REFERENCES `[[PREFIX]]_blog` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) Type=InnoDB;

SET foreign_key_checks=1;

--
--
-- schema schema_userlist_0.03
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Nov 29 20:51:44 2007
-- 
SET foreign_key_checks=0;

--
-- Table: `[[PREFIX]]_user_list`
--
CREATE TABLE `[[PREFIX]]_user_list` (
  `user_id` integer(20) NOT NULL,
  `last_seen` timestamp NOT NULL,
  `logged_in` timestamp NOT NULL,
  `visible` integer(1) NOT NULL DEFAULT '1',
  INDEX (`user_id`),
  PRIMARY KEY (`user_id`)
);

SET foreign_key_checks=1;

--
--
-- schema schema_user_0.01_030
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Nov 29 20:51:44 2007
-- 
SET foreign_key_checks=0;

--
-- Table: `[[PREFIX]]_pm`
--
CREATE TABLE `[[PREFIX]]_pm` (
  `id` bigint(20) NOT NULL auto_increment,
  `sender` integer(20) NOT NULL,
  `message` text NOT NULL,
  `subject` varchar(128) NOT NULL,
  `recipients` varchar(128) NOT NULL,
  `has_read` tinyint(1) NOT NULL,
  `copy_of` bigint(20) NOT NULL,
  `box_id` integer(10) NOT NULL,
  `sent_notify` tinyint(1) NOT NULL DEFAULT '1',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  INDEX (`box_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `[[PREFIX]]_pm_fk_box_id` FOREIGN KEY (`box_id`) REFERENCES `[[PREFIX]]_postbox` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_user_profile`
--
CREATE TABLE `[[PREFIX]]_user_profile` (
  `user_id` bigint(20) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `email` varchar(64) NOT NULL DEFAULT '',
  `homepage` varchar(128) NOT NULL DEFAULT '',
  `avatar` varchar(37) NOT NULL DEFAULT '',
  `location` varchar(64) NOT NULL DEFAULT '',
  `signature` text,
  `sex` ENUM('f','m','t'),
  `icq` varchar(32),
  `aol` varchar(32),
  `yahoo` varchar(32),
  `msn` varchar(32),
  `interests` text,
  `foto_url` varchar(128),
  `birth_year` integer(4),
  `birth_day` char(4),
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`user_id`),
  PRIMARY KEY (`user_id`)
);

--
-- Table: `[[PREFIX]]_role`
--
CREATE TABLE `[[PREFIX]]_role` (
  `id` integer(10) NOT NULL auto_increment,
  `name` varchar(32) NOT NULL DEFAULT '',
  `rtype` varchar(32) NOT NULL DEFAULT '',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  PRIMARY KEY (`id`)
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_user_role`
--
CREATE TABLE `[[PREFIX]]_user_role` (
  `role_id` integer(10) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`role_id`),
  INDEX (`user_id`),
  PRIMARY KEY (`role_id`, `user_id`),
  CONSTRAINT `[[PREFIX]]_user_role_fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `[[PREFIX]]_poard_user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `[[PREFIX]]_user_role_fk_role_id` FOREIGN KEY (`role_id`) REFERENCES `[[PREFIX]]_role` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_user_settings`
--
CREATE TABLE `[[PREFIX]]_user_settings` (
  `user_id` bigint(20) NOT NULL auto_increment,
  `messagecount` bigint(15) NOT NULL DEFAULT '0',
  `send_notify` tinyint(1) NOT NULL DEFAULT '0',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`user_id`),
  PRIMARY KEY (`user_id`)
);

--
-- Table: `[[PREFIX]]_poard_user`
--
CREATE TABLE `[[PREFIX]]_poard_user` (
  `id` bigint(20) NOT NULL auto_increment,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `nick` varchar(32) NOT NULL DEFAULT '',
  `password` varchar(32) NOT NULL DEFAULT '',
  `mtime` timestamp NOT NULL,
  `lastlogin` datetime NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  PRIMARY KEY (`id`)
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_action_token`
--
CREATE TABLE `[[PREFIX]]_action_token` (
  `id` bigint(20) NOT NULL auto_increment,
  `user_id` bigint(20) NOT NULL DEFAULT '0',
  `token` varchar(32) NOT NULL,
  `action` varchar(32) DEFAULT '',
  `info` text DEFAULT '',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  PRIMARY KEY (`id`)
);

--
-- Table: `[[PREFIX]]_message_recipient`
--
CREATE TABLE `[[PREFIX]]_message_recipient` (
  `message_id` bigint(10) NOT NULL,
  `recipient_id` bigint(20) NOT NULL,
  `has_read` tinyint(1) NOT NULL,
  INDEX (`message_id`),
  INDEX (`recipient_id`),
  UNIQUE `message_recipient_message_id_recipient_id` (`message_id`, `recipient_id`),
  CONSTRAINT `[[PREFIX]]_message_recipient_fk_recipient_id` FOREIGN KEY (`recipient_id`) REFERENCES `[[PREFIX]]_poard_user` (`id`),
  CONSTRAINT `[[PREFIX]]_message_recipient_fk_message_id` FOREIGN KEY (`message_id`) REFERENCES `[[PREFIX]]_pm` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_token`
--
CREATE TABLE `[[PREFIX]]_token` (
  `id` varchar(32) NOT NULL,
  `id2` varchar(32) NOT NULL,
  `user_id` integer(20) NOT NULL DEFAULT '0',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`user_id`),
  PRIMARY KEY (`user_id`)
);

--
-- Table: `[[PREFIX]]_sessions`
--
CREATE TABLE `[[PREFIX]]_sessions` (
  `id` varchar(32) NOT NULL,
  `a_session` text NOT NULL,
  `mtime` timestamp NOT NULL,
  INDEX (`id`),
  PRIMARY KEY (`id`)
);

--
-- Table: `[[PREFIX]]_postbox`
--
CREATE TABLE `[[PREFIX]]_postbox` (
  `id` integer(10) NOT NULL auto_increment,
  `user_id` bigint(20) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `type` ENUM('in','out') NOT NULL DEFAULT 'in',
  `is_default` tinyint(1) NOT NULL DEFAULT '0',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  INDEX (`user_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `[[PREFIX]]_postbox_fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `[[PREFIX]]_poard_user` (`id`)
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_user_abook`
--
CREATE TABLE `[[PREFIX]]_user_abook` (
  `user_id` bigint(20) NOT NULL,
  `contactid` bigint(20) NOT NULL,
  `note` varchar(128),
  `blacklist` tinyint(1) NOT NULL DEFAULT '0',
  `ctime` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  INDEX (`user_id`),
  INDEX (`contactid`),
  PRIMARY KEY (`user_id`, `contactid`),
  CONSTRAINT `[[PREFIX]]_user_abook_fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `[[PREFIX]]_poard_user` (`id`),
  CONSTRAINT `[[PREFIX]]_user_abook_fk_contactid` FOREIGN KEY (`contactid`) REFERENCES `[[PREFIX]]_poard_user` (`id`)
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_role_action`
--
CREATE TABLE `[[PREFIX]]_role_action` (
  `id` integer(10) NOT NULL auto_increment,
  `role_id` integer(10) NOT NULL,
  `action` varchar(128) NOT NULL,
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  INDEX (`role_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `[[PREFIX]]_role_action_fk_role_id` FOREIGN KEY (`role_id`) REFERENCES `[[PREFIX]]_role` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) Type=InnoDB;

SET foreign_key_checks=1;

--
--
-- schema schema_gallery_0.01_002
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Nov 29 20:51:44 2007
-- 
SET foreign_key_checks=0;

--
-- Table: `[[PREFIX]]_gallery_info`
--
CREATE TABLE `[[PREFIX]]_gallery_info` (
  `id` integer(10) NOT NULL auto_increment,
  `created_by` integer(10) NOT NULL,
  `title` varchar(255) NOT NULL,
  `image_count` integer(5) NOT NULL DEFAULT '0',
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  PRIMARY KEY (`id`)
) Type=InnoDB;

--
-- Table: `[[PREFIX]]_gallery_image`
--
CREATE TABLE `[[PREFIX]]_gallery_image` (
  `id` integer(10) NOT NULL auto_increment,
  `info` integer(10) NOT NULL,
  `position` integer(4) NOT NULL,
  `title` varchar(255) NOT NULL,
  `suffix` varchar(4) NOT NULL,
  `mtime` timestamp NOT NULL,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  INDEX (`info`),
  PRIMARY KEY (`id`),
  CONSTRAINT `[[PREFIX]]_gallery_image_fk_info` FOREIGN KEY (`info`) REFERENCES `[[PREFIX]]_gallery_info` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) Type=InnoDB;

SET foreign_key_checks=1;

--
--
-- schema schema_log_0.01_002
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Nov 29 20:51:44 2007
-- 
SET foreign_key_checks=0;

--
-- Table: `[[PREFIX]]_log`
--
CREATE TABLE `[[PREFIX]]_log` (
  `id` bigint(21) NOT NULL auto_increment,
  `user_id` bigint(20),
  `module` varchar(32) NOT NULL,
  `action` varchar(64) NOT NULL,
  `object_id` bigint(20),
  `object_type` varchar(64),
  `ip` varchar(16) NOT NULL,
  `forwarded_for` varchar(128),
  `comment` text,
  `referrer` text,
  `ctime` timestamp NOT NULL,
  INDEX (`id`),
  PRIMARY KEY (`id`)
);

SET foreign_key_checks=1;

