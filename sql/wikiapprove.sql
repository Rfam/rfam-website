CREATE DATABASE wiki_approve;

USE wiki_approve;

CREATE TABLE `article_mapping` (
  `accession` varchar(7) NOT NULL,
  `title` tinytext NOT NULL,
  `db` enum('pfam','rfam') NOT NULL,
  PRIMARY KEY  (`accession`,`title`(64))
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `wikipedia` (
  `title` tinytext NOT NULL,
  `updated` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `approved_revision` int(10) unsigned default '0',
  `wikipedia_revision` int(10) unsigned default '0',
  `approved_by` varchar(100) NOT NULL,
  `pfam_status` enum('active','inactive','pending') NOT NULL default 'pending',
  `rfam_status` enum('active','inactive','pending') NOT NULL default 'pending',
  PRIMARY KEY  (`title`(64))
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `wikiuser` (
  `user_name` varchar(100) NOT NULL,
  `approved` tinyint(1) default '0',
  `number_edits` int(11) default '0',
  PRIMARY KEY  (`user_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
