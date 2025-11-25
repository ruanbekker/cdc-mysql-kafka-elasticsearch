#!/usr/bin/env bash
docker compose exec mysql mysql -uroot -prootpassword
USE employees;
INSERT INTO user_info (username,email) VALUES ('charlie','charlie@example.com');

