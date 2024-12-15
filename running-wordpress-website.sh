#!/bin/bash

    apt-get install apache2 -y  
    apt install mysql-server -y
    apt -y install expect
    SECURE_MYSQL=$(expect -c "
    set timeout 10
    spawn mysql_secure_installation
    expect \"Enter current password for root (enter for none):\"
    send \"$MYSQL\r\"
    expect \"Change the root password?\"
    send \"n\r\"
    expect \"Remove anonymous users?\"
    send \"y\r\"
    expect \"Disallow root login remotely?\"
    send \"y\r\"
    expect \"Remove test database and access to it?\"
    send \"y\r\"
    expect \"Reload privilege tables now?\"
    send \"y\r\"
    expect eof
    ")

    echo "$SECURE_MYSQL"

    apt -y purge expect
    apt install php libapache2-mod-php php-mysql -y
    apt-get install phpmyadmin -y
  
    read -p "Enter User for mysql " mysql_user
    read -p "Enter password for $mysql_user " mysql_password
    cat > setup-db.sql <<-EOF
        CREATE USER '$mysql_user'@'localhost' IDENTIFIED BY '$mysql_password';
        GRANT ALL PRIVILEGES ON *.* TO '$mysql_user'@'localhost' WITH GRANT OPTION;
        FLUSH PRIVILEGES;   
EOF
    
    sudo mysql < setup-db.sql
    sudo systemctl restart apache2


    read -p "Enter Wordpress Website Name " WORDPRESS_NAME
    cat > setup-wordpress.sql <<-EOF
        CREATE DATABASE $WORDPRESS_NAME;
        GRANT ALL ON $WORDPRESS_NAME.* TO '$mysql_user'@'localhost';
        FLUSH PRIVILEGES;   
EOF

    sudo mysql < setup-wordpress.sql
    sudo apt update
    sudo apt install php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip -y
    sudo systemctl restart apache2

    cat > /etc/apache2/sites-available/$WORDPRESS_NAME.conf <<-EOF
        <Directory /var/www/html/$WORDPRESS_NAME/ >
        AllowOverride All   
        </Directory>
EOF

    sudo a2enmod rewrite
    sudo a2ensite $WORDPRESS_NAME
    sudo systemctl reload apache2
    sudo systemctl restart apache2

    cd /tmp
    sudo apt install curl -y
    curl -O https://wordpress.org/latest.tar.gz
    tar xzvf latest.tar.gz
    touch /tmp/wordpress/.htaccess
    sudo cp /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php
    mkdir /tmp/wordpress/wp-content/upgrade
    sudo cp -a /tmp/wordpress/ /var/www/html/
    sudo mv /var/www/html/wordpress /var/www/html/$WORDPRESS_NAME
    sudo chown -R www-data:www-data /var/www/html/$WORDPRESS_NAME
    sudo find /var/www/html/$WORDPRESS_NAME -type d -exec chmod 750 {} \;
    sudo find /var/www/html/$WORDPRESS_NAME -type f -exec chmod 640 {} \;

    sed -i "s/database_name_here/$WORDPRESS_NAME/g"  /var/www/html/$WORDPRESS_NAME/wp-config.php
    sed -i "s/username_here/$mysql_user/g"  /var/www/html/$WORDPRESS_NAME/wp-config.php
    sed -i "s/password_here/$mysql_password/g"  /var/www/html/$WORDPRESS_NAME/wp-config.php