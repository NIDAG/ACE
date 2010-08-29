# Setup script for ACE tools.
# Assumes you have a MySQL database set up with read/write permissions.
# Modify database credentials in config file and then run this script to create tables.
# Will not overwrite existing tables; delete manually if you need to re-create them.

require 'config'
require 'mysql'

sql = <<EOF
CREATE TABLE IF NOT EXISTS `articles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `metadata` text,
  `pubmed_metadata` text,
  `filename` varchar(256) DEFAULT NULL,
  `journal` varchar(256) DEFAULT NULL,
  `doi` varchar(256) DEFAULT NULL,
  `year` int(4) DEFAULT NULL,
  `sample_size` varchar(20) DEFAULT NULL,
  `author` text,
  `title` text,
  `n_words` int(11) DEFAULT NULL,
  `active` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `filename` (`filename`)
); CREATE TABLE IF NOT EXISTS `article_texts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `text` longtext,
  `article_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `article_id` (`article_id`)
); CREATE TABLE IF NOT EXISTS `peaks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `table_id` int(11) DEFAULT NULL,
  `number` int(11) DEFAULT NULL,
  `region` text,
  `hemisphere` varchar(100) DEFAULT NULL,
  `ba` varchar(100) DEFAULT NULL,
  `x` int(11) DEFAULT NULL,
  `y` int(11) DEFAULT NULL,
  `z` int(11) DEFAULT NULL,
  `size` varchar(100) DEFAULT NULL,
  `groups` text,
  `statistic` varchar(100) DEFAULT NULL,
  `p_value` varchar(100) DEFAULT NULL,
  `columns` text,
  `problems` text,
  PRIMARY KEY (`id`),
  KEY `table_id` (`table_id`)
); CREATE TABLE IF NOT EXISTS `tables` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `number` int(11) DEFAULT NULL,
  `article_id` int(11) DEFAULT NULL,
  `title` text,
  `caption` text,
  PRIMARY KEY (`id`),
  KEY `article_id` (`article_id`)
); CREATE TABLE IF NOT EXISTS `terms` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `n_articles` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
); CREATE TABLE IF NOT EXISTS `tags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `article_id` int(11) DEFAULT NULL,
  `term_id` int(11) DEFAULT NULL,
  `count` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `term_id` (`term_id`),
  KEY `article_id` (`article_id`)
)
EOF

db = Mysql.real_connect(DB_HOST, DB_USERNAME, DB_PASSWORD, DB_DATABASE)
sql.split(";").each { |s| db.query(s) }