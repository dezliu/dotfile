# 本地安装 orbStack
brew install orbstack

# 本地新建一个文件夹
eg: 
```bash
cd ~
mkdir docker
cd docker
mkdir mysql_docker
cd mysql_docker
vim docker-compose.yml
``` 
```docker-compose.yml
version: "3.3"
services:
  db:
    image: mysql:8.0
    restart: always
    container_name: my_mysql
    platform: linux/arm64
    environment:
      MYSQL_DATABASE: "my_database"
      MYSQL_USER: "dezliu"
      MYSQL_PASSWORD: "dezliu"
      MYSQL_ROOT_PASSWORD: "123456"
    ports:
      - "3306:3306"
    volumes:
      - ./db-data:/var/lib/mysql
```

在此目录下执行：docker compose up -d

如果网络不行，打开 settings -> docker -> engine，json里粘贴：
```json
{
  "registry-mirrors" : [
    "https:\/\/docker.m.daocloud.io",
    "https:\/\/docker.1panel.live"
  ]
}
```

安装好后，docker ps 就能看到了
可以通过：
docker exec -it my_mysql mysql -u root -p
连接
或者：brew link --overwrite mysql-client
mysql -h mysql_docker.orb.local -u root -p
mysql -h my_mysql.orb.local -u root -p 123456
mysql -h my_mysql.orb.local -u dezliu -p dezliu
连接