-- initdb.sql
CREATE DATABASE IF NOT EXISTS employees;
USE employees;


CREATE TABLE IF NOT EXISTS user_info (
id INT AUTO_INCREMENT PRIMARY KEY,
username VARCHAR(100) NOT NULL,
email VARCHAR(255) NOT NULL,
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS user_salaries (
id INT AUTO_INCREMENT PRIMARY KEY,
user_id INT NOT NULL,
salary DECIMAL(10,2) NOT NULL,
effective_from DATE,
FOREIGN KEY (user_id) REFERENCES user_info(id)
) ENGINE=InnoDB;


-- Debezium user
CREATE USER IF NOT EXISTS 'debezium'@'%' IDENTIFIED BY 'dbz';
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'debezium'@'%';
FLUSH PRIVILEGES;


-- sample data
INSERT INTO user_info (username, email) VALUES ('alice','alice@example.com'), ('bob','bob@example.com');
INSERT INTO user_salaries (user_id, salary, effective_from) VALUES (1, 75000.00, '2024-01-01'), (2, 65000.00, '2024-06-01');
