#!/bin/bash
# For DB Login

COM="/bin/mysql -pPqW0ns%FqB1%$H --socket=/var/lib/mysql/mysql.sock -A"

echo  -e  "\033[33m
--- Login ---
 DB   - Masteri Mariadb
 Port - 3306 
 User - root
-------------
\033[0m"

sleep 3

$COM
