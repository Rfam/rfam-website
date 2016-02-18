CREATE TABLE `alignment_das_sources` (
  `from_system` varchar(200) NOT NULL DEFAULT '',
  `from_type` varchar(200) NOT NULL DEFAULT '',
  `to_system` varchar(200) NOT NULL DEFAULT '',
  `to_type` varchar(200) NOT NULL DEFAULT '',
  `server_id` varchar(40) NOT NULL DEFAULT '',
  `name` varchar(100) NOT NULL DEFAULT '',
  `url` varchar(200) NOT NULL DEFAULT '',
  `helper_url` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`server_id`,`from_system`,`from_type`,`to_system`,`to_type`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `article_mapping` (
  `accession` VARCHAR(7) COLLATE utf8_bin NOT NULL,
  `title` TINYTEXT COLLATE utf8_bin NOT NULL,
  PRIMARY KEY (`accession`,`title`(128))
) ENGINE=INNODB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

CREATE TABLE `feature_das_sources` (
  `server_id` VARCHAR(40) NOT NULL DEFAULT '',
  `system` VARCHAR(200) NOT NULL DEFAULT '',
  `sequence_type` VARCHAR(200) NOT NULL DEFAULT '',
  `name` VARCHAR(100) NOT NULL DEFAULT '',
  `url` VARCHAR(200) NOT NULL DEFAULT '',
  `helper_url` VARCHAR(200) DEFAULT NULL,
  `default_server` TINYINT(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`server_id`,`system`,`sequence_type`)
) ENGINE=INNODB DEFAULT CHARSET=latin1;

CREATE TABLE `job_history` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_id` VARCHAR(40) NOT NULL,
  `ebi_id` VARCHAR(60) DEFAULT NULL,
  `status` VARCHAR(5) NOT NULL DEFAULT '',
  `options` VARCHAR(255) DEFAULT '',
  `estimated_time` INT(3) DEFAULT NULL,
  `opened` DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00',
  `closed` DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00',
  `started` DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00',
  `job_type` VARCHAR(50) NOT NULL DEFAULT '',
  `email` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `job_id_idx` (`job_id`(32))
) ENGINE=INNODB AUTO_INCREMENT=3793515 DEFAULT CHARSET=latin1;

CREATE TABLE `job_stream` (
  `id` BIGINT(20) UNSIGNED NOT NULL DEFAULT '0',
  `stdin` LONGTEXT NOT NULL,
  `stdout` MEDIUMBLOB,
  `stderr` LONGTEXT,
  PRIMARY KEY (`id`)
) ENGINE=INNODB DEFAULT CHARSET=latin1;

CREATE TABLE `species_collection` (
  `job_id` VARCHAR(40) NOT NULL,
  `id_list` TEXT NOT NULL,
  PRIMARY KEY (`job_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8;

CREATE TABLE `wikitext` (
  `title` TINYTEXT COLLATE utf8_bin NOT NULL,
  `text` LONGTEXT CHARACTER SET utf8,
  `approved_revision` INT(10) UNSIGNED DEFAULT '0',
  PRIMARY KEY (`title`(128))
) ENGINE=INNODB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
