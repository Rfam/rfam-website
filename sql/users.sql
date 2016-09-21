CREATE USER 'rfam'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'rfam'@'localhost' WITH GRANT OPTION;
CREATE USER 'rfam'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'rfam'@'%' WITH GRANT OPTION;
