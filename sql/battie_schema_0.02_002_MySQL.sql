-- Schema for Battie 0.02_002

--
--
-- schema schema_poard_0.01_018
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Fri Sep 12 20:46:37 2008
-- 
SET foreign_key_checks=0;

--
-- Table: `TABLE_PREFIX_poard_board`
--
CREATE TABLE `TABLE_PREFIX_poard_board` (
  `id` integer(5) NOT NULL auto_increment,
  `flags` integer(10) NOT NULL DEFAULT '0',
  `name` varchar(64) NOT NULL DEFAULT '',
  `description` varchar(128) NOT NULL DEFAULT '',
  `position` integer(5) NOT NULL DEFAULT '0',
  `lft` integer(10),
  `rgt` integer(10),
  `parent_id` integer(5) DEFAULT '0',
  `containmessages` integer(1) NOT NULL DEFAULT '0',
  `grouprequired` integer(10) DEFAULT '0',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_poard_message`
--
CREATE TABLE `TABLE_PREFIX_poard_message` (
  `id` bigint(20) NOT NULL auto_increment,
  `thread_id` bigint(20) NOT NULL DEFAULT '0',
  `author_id` integer(20) NOT NULL DEFAULT '0',
  `position` integer(10) NOT NULL DEFAULT '0',
  `lft` integer(10),
  `rgt` integer(10),
  `lasteditor` integer(20) NOT NULL DEFAULT '0',
  `approved_by` integer(20) NOT NULL DEFAULT '0',
  `message` text NOT NULL DEFAULT '',
  `author_name` varchar(32),
  `status` ENUM('active','deleted','onhold') NOT NULL DEFAULT 'onhold',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`thread_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_thread_id` FOREIGN KEY (`thread_id`) REFERENCES `TABLE_PREFIX_poard_thread` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_poard_notify`
--
CREATE TABLE `TABLE_PREFIX_poard_notify` (
  `id` bigint(20) NOT NULL auto_increment,
  `user_id` bigint(20) NOT NULL,
  `thread_id` bigint(20) NOT NULL DEFAULT '0',
  `last_notified` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`thread_id`),
  PRIMARY KEY (`id`),
  UNIQUE `poard_notify_user_id_thread_id` (`user_id`, `thread_id`),
  CONSTRAINT `fk_thread_id_1` FOREIGN KEY (`thread_id`) REFERENCES `TABLE_PREFIX_poard_thread` (`id`)
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_poard_read_messages`
--
CREATE TABLE `TABLE_PREFIX_poard_read_messages` (
  `thread_id` bigint(20) NOT NULL DEFAULT '0',
  `user_id` bigint(20) NOT NULL DEFAULT '0',
  `position` integer(10) NOT NULL DEFAULT '0',
  `mtime` datetime NOT NULL,
  INDEX (`thread_id`),
  PRIMARY KEY (`user_id`, `thread_id`),
  CONSTRAINT `fk_thread_id_2` FOREIGN KEY (`thread_id`) REFERENCES `TABLE_PREFIX_poard_thread` (`id`)
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_survey`
--
CREATE TABLE `TABLE_PREFIX_survey` (
  `id` bigint(20) NOT NULL auto_increment,
  `thread_id` bigint(20) NOT NULL,
  `question` text NOT NULL DEFAULT '',
  `votecount` integer(10) NOT NULL DEFAULT '0',
  `is_multiple` integer(5) NOT NULL DEFAULT '0',
  `status` ENUM('onhold','active','deleted') NOT NULL DEFAULT 'onhold',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`thread_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_thread_id_3` FOREIGN KEY (`thread_id`) REFERENCES `TABLE_PREFIX_poard_thread` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_survey_option`
--
CREATE TABLE `TABLE_PREFIX_survey_option` (
  `id` bigint(20) NOT NULL auto_increment,
  `position` integer(5) NOT NULL,
  `survey_id` bigint(20) NOT NULL,
  `answer` text NOT NULL DEFAULT '',
  `votecount` integer(10) NOT NULL DEFAULT '0',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`survey_id`),
  PRIMARY KEY (`id`),
  UNIQUE `survey_option_position_survey_id` (`position`, `survey_id`),
  CONSTRAINT `fk_survey_id` FOREIGN KEY (`survey_id`) REFERENCES `TABLE_PREFIX_survey` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_survey_vote`
--
CREATE TABLE `TABLE_PREFIX_survey_vote` (
  `id` bigint(20) NOT NULL auto_increment,
  `user_id` bigint(20) NOT NULL,
  `survey_id` bigint(20) NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`survey_id`),
  PRIMARY KEY (`id`),
  UNIQUE `survey_vote_user_id_survey_id` (`user_id`, `survey_id`),
  CONSTRAINT `fk_survey_id_1` FOREIGN KEY (`survey_id`) REFERENCES `TABLE_PREFIX_survey` (`id`)
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_poard_thread`
--
CREATE TABLE `TABLE_PREFIX_poard_thread` (
  `id` bigint(20) NOT NULL auto_increment,
  `title` varchar(128) NOT NULL DEFAULT '',
  `author_id` integer(20) NOT NULL,
  `author_name` varchar(32),
  `status` ENUM('active','deleted','onhold') NOT NULL DEFAULT 'onhold',
  `fixed` tinyint(1) NOT NULL DEFAULT '0',
  `is_tree` tinyint(1) NOT NULL DEFAULT '0',
  `closed` tinyint(1) NOT NULL DEFAULT '0',
  `board_id` integer(5) NOT NULL,
  `read_count` integer(10) DEFAULT '0',
  `messagecount` integer(10) NOT NULL DEFAULT '0',
  `approved_by` integer(20) NOT NULL DEFAULT '0',
  `is_survey` tinyint(1) NOT NULL DEFAULT '0',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`board_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_board_id` FOREIGN KEY (`board_id`) REFERENCES `TABLE_PREFIX_poard_board` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_poard_trash`
--
CREATE TABLE `TABLE_PREFIX_poard_trash` (
  `id` bigint(20) NOT NULL auto_increment,
  `thread_id` bigint(20) NOT NULL DEFAULT '0',
  `msid` bigint(20) NOT NULL DEFAULT '0',
  `deleted_by` bigint(20) NOT NULL DEFAULT '0',
  `comment` varchar(64) NOT NULL DEFAULT '',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  PRIMARY KEY (`id`)
);

SET foreign_key_checks=1;

--
--
-- schema schema_system_0.01_003
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Fri Sep 12 20:46:37 2008
-- 
SET foreign_key_checks=0;

--
-- Table: `TABLE_PREFIX_system_lang`
--
CREATE TABLE `TABLE_PREFIX_system_lang` (
  `id` char(5) NOT NULL,
  `name` varchar(128) NOT NULL,
  `fallback` char(5) NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
);

--
-- Table: `TABLE_PREFIX_system_translation`
--
CREATE TABLE `TABLE_PREFIX_system_translation` (
  `id` varchar(128) NOT NULL,
  `lang` char(5) NOT NULL,
  `translation` text NOT NULL,
  `plural` text,
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
-- Created on Fri Sep 12 20:46:37 2008
-- 
SET foreign_key_checks=0;

--
-- Table: `TABLE_PREFIX_news`
--
CREATE TABLE `TABLE_PREFIX_news` (
  `id` integer(10) NOT NULL auto_increment,
  `headline` text NOT NULL,
  `message` text NOT NULL,
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  PRIMARY KEY (`id`)
);

--
-- Table: `TABLE_PREFIX_content_page`
--
CREATE TABLE `TABLE_PREFIX_content_page` (
  `id` integer(10) NOT NULL auto_increment,
  `title` varchar(64) NOT NULL,
  `parent` integer(10) NOT NULL DEFAULT '0',
  `position` integer(4) NOT NULL DEFAULT '0',
  `url` varchar(32) NOT NULL,
  `text` text NOT NULL,
  `markup` varchar(16) NOT NULL DEFAULT 'html',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
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
-- Created on Fri Sep 12 20:46:37 2008
-- 
SET foreign_key_checks=0;

--
-- Table: `TABLE_PREFIX_blog`
--
CREATE TABLE `TABLE_PREFIX_blog` (
  `id` integer(10) NOT NULL auto_increment,
  `title` text NOT NULL,
  `image` text,
  `created_by` integer(10) NOT NULL,
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_theme`
--
CREATE TABLE `TABLE_PREFIX_theme` (
  `id` integer(10) NOT NULL auto_increment,
  `blog_id` integer(10) NOT NULL,
  `title` text NOT NULL,
  `abstract` text NOT NULL,
  `image` text,
  `link` text NOT NULL,
  `message` text NOT NULL,
  `posted_by` integer(10) NOT NULL,
  `active` integer(1) NOT NULL,
  `is_news` integer(1) NOT NULL,
  `can_comment` integer(1) NOT NULL,
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`blog_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_blog_id` FOREIGN KEY (`blog_id`) REFERENCES `TABLE_PREFIX_blog` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

SET foreign_key_checks=1;

--
--
-- schema schema_userlist_0.03
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Fri Sep 12 20:46:37 2008
-- 
SET foreign_key_checks=0;

--
-- Table: `TABLE_PREFIX_chatterbox`
--
CREATE TABLE `TABLE_PREFIX_chatterbox` (
  `user_id` bigint(20) NOT NULL,
  `seq` integer(3) NOT NULL,
  `msg` text NOT NULL,
  `ctime` datetime NOT NULL,
  `rec` bigint(20)
);

--
-- Table: `TABLE_PREFIX_user_list`
--
CREATE TABLE `TABLE_PREFIX_user_list` (
  `user_id` integer(20) NOT NULL,
  `last_seen` datetime,
  `logged_in` datetime NOT NULL,
  `visible` integer(1) NOT NULL DEFAULT '1',
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
-- Created on Fri Sep 12 20:46:37 2008
-- 
SET foreign_key_checks=0;

--
-- Table: `TABLE_PREFIX_action_token`
--
CREATE TABLE `TABLE_PREFIX_action_token` (
  `id` bigint(20) NOT NULL auto_increment,
  `user_id` bigint(20) NOT NULL DEFAULT '0',
  `token` varchar(32) NOT NULL,
  `action` varchar(32) DEFAULT '',
  `info` text DEFAULT '',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  PRIMARY KEY (`id`)
);

--
-- Table: `TABLE_PREFIX_user_abook`
--
CREATE TABLE `TABLE_PREFIX_user_abook` (
  `user_id` bigint(20) NOT NULL,
  `contactid` bigint(20) NOT NULL,
  `note` varchar(128),
  `blacklist` tinyint(1) NOT NULL DEFAULT '0',
  `ctime` datetime NOT NULL,
  INDEX (`contactid`),
  INDEX (`user_id`),
  PRIMARY KEY (`user_id`, `contactid`),
  CONSTRAINT `fk_contactid` FOREIGN KEY (`contactid`) REFERENCES `TABLE_PREFIX_poard_user` (`id`),
  CONSTRAINT `fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `TABLE_PREFIX_poard_user` (`id`)
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_sessions`
--
CREATE TABLE `TABLE_PREFIX_sessions` (
  `id` varchar(32) NOT NULL,
  `a_session` text NOT NULL,
  `mtime` datetime,
  PRIMARY KEY (`id`)
);

--
-- Table: `TABLE_PREFIX_message_recipient`
--
CREATE TABLE `TABLE_PREFIX_message_recipient` (
  `message_id` bigint(10) NOT NULL,
  `recipient_id` bigint(20) NOT NULL,
  `has_read` tinyint(1) NOT NULL,
  INDEX (`message_id`),
  INDEX (`recipient_id`),
  UNIQUE `message_recipient_message_id_recipient_id` (`message_id`, `recipient_id`),
  CONSTRAINT `fk_message_id` FOREIGN KEY (`message_id`) REFERENCES `TABLE_PREFIX_pm` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_recipient_id` FOREIGN KEY (`recipient_id`) REFERENCES `TABLE_PREFIX_poard_user` (`id`)
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_user_my_nodelet`
--
CREATE TABLE `TABLE_PREFIX_user_my_nodelet` (
  `user_id` bigint(20) NOT NULL,
  `content` text NOT NULL,
  `is_open` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`user_id`)
);

--
-- Table: `TABLE_PREFIX_pm`
--
CREATE TABLE `TABLE_PREFIX_pm` (
  `id` bigint(20) NOT NULL auto_increment,
  `sender` integer(20) NOT NULL,
  `message` text NOT NULL,
  `subject` varchar(128) NOT NULL,
  `recipients` varchar(128) NOT NULL,
  `has_read` tinyint(1) NOT NULL,
  `copy_of` bigint(20) NOT NULL,
  `box_id` integer(10) NOT NULL,
  `sent_notify` tinyint(1) NOT NULL DEFAULT '1',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`box_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_box_id` FOREIGN KEY (`box_id`) REFERENCES `TABLE_PREFIX_postbox` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_postbox`
--
CREATE TABLE `TABLE_PREFIX_postbox` (
  `id` integer(10) NOT NULL auto_increment,
  `user_id` bigint(20) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `type` ENUM('in','out') NOT NULL DEFAULT 'in',
  `is_default` tinyint(1) NOT NULL DEFAULT '0',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`user_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_user_id_1` FOREIGN KEY (`user_id`) REFERENCES `TABLE_PREFIX_poard_user` (`id`)
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_user_profile`
--
CREATE TABLE `TABLE_PREFIX_user_profile` (
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
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  PRIMARY KEY (`user_id`)
);

--
-- Table: `TABLE_PREFIX_role`
--
CREATE TABLE `TABLE_PREFIX_role` (
  `id` integer(10) NOT NULL auto_increment,
  `name` varchar(32) NOT NULL DEFAULT '',
  `rtype` varchar(32) NOT NULL DEFAULT '',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_role_action`
--
CREATE TABLE `TABLE_PREFIX_role_action` (
  `id` integer(10) NOT NULL auto_increment,
  `role_id` integer(10) NOT NULL,
  `action` varchar(128) NOT NULL,
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`role_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_role_id` FOREIGN KEY (`role_id`) REFERENCES `TABLE_PREFIX_role` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_user_settings`
--
CREATE TABLE `TABLE_PREFIX_user_settings` (
  `user_id` bigint(20) NOT NULL auto_increment,
  `messagecount` bigint(15) NOT NULL DEFAULT '0',
  `send_notify` tinyint(1) NOT NULL DEFAULT '0',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  PRIMARY KEY (`user_id`)
);

--
-- Table: `TABLE_PREFIX_token`
--
CREATE TABLE `TABLE_PREFIX_token` (
  `id` varchar(32) NOT NULL,
  `id2` varchar(32) NOT NULL,
  `user_id` integer(20) NOT NULL DEFAULT '0',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  PRIMARY KEY (`user_id`)
);

--
-- Table: `TABLE_PREFIX_poard_user`
--
CREATE TABLE `TABLE_PREFIX_poard_user` (
  `id` bigint(20) NOT NULL auto_increment,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `nick` varchar(64) NOT NULL DEFAULT '',
  `password` varchar(32) NOT NULL DEFAULT '',
  `mtime` datetime NOT NULL,
  `lastlogin` datetime,
  `openid` varchar(16),
  `ctime` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_user_role`
--
CREATE TABLE `TABLE_PREFIX_user_role` (
  `role_id` integer(10) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`role_id`),
  INDEX (`user_id`),
  PRIMARY KEY (`role_id`, `user_id`),
  CONSTRAINT `fk_role_id_1` FOREIGN KEY (`role_id`) REFERENCES `TABLE_PREFIX_role` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_user_id_2` FOREIGN KEY (`user_id`) REFERENCES `TABLE_PREFIX_poard_user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

SET foreign_key_checks=1;

--
--
-- schema schema_gallery_0.01_002
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Wed Aug 27 18:56:52 2008
-- 
SET foreign_key_checks=0;

--
-- Table: `TABLE_PREFIX_gallery_category`
--
CREATE TABLE `TABLE_PREFIX_gallery_category` (
  `id` integer(10) NOT NULL auto_increment,
  `parent_id` integer(10) NOT NULL,
  `left_id` integer(10) NOT NULL,
  `right_id` integer(10) NOT NULL,
  `title` varchar(255) NOT NULL,
  `mtime` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_gallery_image`
--
CREATE TABLE `TABLE_PREFIX_gallery_image` (
  `id` integer(10) NOT NULL auto_increment,
  `info` integer(10) NOT NULL,
  `position` integer(4) NOT NULL,
  `title` varchar(255) NOT NULL,
  `suffix` varchar(4) NOT NULL,
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`info`),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_info` FOREIGN KEY (`info`) REFERENCES `TABLE_PREFIX_gallery_info` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

--
-- Table: `TABLE_PREFIX_gallery_info`
--
CREATE TABLE `TABLE_PREFIX_gallery_info` (
  `id` integer(10) NOT NULL auto_increment,
  `cat_id` integer(10) NOT NULL,
  `created_by` integer(10) NOT NULL,
  `title` varchar(255) NOT NULL,
  `image_count` integer(5) NOT NULL DEFAULT '0',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  INDEX (`cat_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_cat_id` FOREIGN KEY (`cat_id`) REFERENCES `TABLE_PREFIX_gallery_category` (`id`)
) ENGINE=InnoDB;

SET foreign_key_checks=1;

--
--
-- schema schema_guest_0.01_002
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Fri Sep 12 20:46:37 2008
-- 
SET foreign_key_checks=0;

--
-- Table: `TABLE_PREFIX_guest_book_entry`
--
CREATE TABLE `TABLE_PREFIX_guest_book_entry` (
  `id` bigint(21) NOT NULL auto_increment,
  `name` varchar(64) NOT NULL,
  `email` varchar(128),
  `url` varchar(128),
  `location` varchar(64),
  `message` text NOT NULL,
  `comment` text,
  `comment_by` bigint(20),
  `approved_by` bigint(20),
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `mtime` datetime NOT NULL,
  `ctime` datetime NOT NULL,
  PRIMARY KEY (`id`)
);

SET foreign_key_checks=1;

--
--
-- schema schema_log_0.01_002
--
--
-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Fri Sep 12 20:46:37 2008
-- 
SET foreign_key_checks=0;

--
-- Table: `TABLE_PREFIX_log`
--
CREATE TABLE `TABLE_PREFIX_log` (
  `id` bigint(21) NOT NULL auto_increment,
  `user_id` bigint(20),
  `module` varchar(32) NOT NULL,
  `action` varchar(64) NOT NULL,
  `object_id` bigint(20),
  `object_type` varchar(64),
  `ip` varchar(16) NOT NULL,
  `country` char(2),
  `city` varchar(32),
  `forwarded_for` varchar(128),
  `comment` text,
  `referrer` text,
  `ctime` datetime NOT NULL,
  PRIMARY KEY (`id`)
);

SET foreign_key_checks=1;

