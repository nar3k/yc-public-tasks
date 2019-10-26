# Работа с Container Registry и Container Optimized Image

В рамках данной инструкции будут освещены следующие вопросы:
* Настройка базового окружения
* Создание Docker Registry
* Подготовка, сборка и выкладка Docker Image
* Создание виртуальной машины на базе Container Optimized Image
* Обновление Docker Image на виртуальной машине без перезапуска

Ожидается на рабочем месте установлен yc command line tool, docker и системные утилиты: jq, curl.

### Подготовка рабочего окружения

#### Настройка yc command line

Для первоначальной настройки необходимо вызвать `yc init`, выбрать cloud, создать новый folder и выбрать default compute zone - ru-central1-c.

После этого необходимо проставить в переменную окружения идентификатор созданого folder:
```
FOLDER=$(yc config get folder-id)
```

#### Создание рабочей директории

Создаем рабочую директорию и переходим в неё:
```
mkdir "demo-${FOLDER}" && cd "demo-${FOLDER}"
```

#### Настройка сети

Необходимо в новом folder создать сеть и подсеть. В дальнейшем это будет использоваться для запуска виртуальной машины на базе Container Optimized Image.

Для создания сети:
```
yc vpc network create --name=demo-net
```

Пример вывода команды создания сети:
```
done (2s)
id: enptkfb1dutkdpmkp4kv
folder_id: b1g07qkm7vij7am773nd
created_at: "2019-09-30T11:19:43Z"
name: demo-net
```

Для создания подсети в default compute zone (zone не указывается): 
```
yc vpc subnet create --network-name=demo-net \
                     --name=demo-subnet-c \
                     --zone=ru-central1-c \
                     --range=192.168.0.0/24
```

Пример вывода команды создания подсети:
```
done (2s)
id: b0c9r4foch76lik7eupu
folder_id: b1g07qkm7vij7am773nd
created_at: "2019-09-30T11:19:55Z"
name: demo-subnet-c
network_id: enptkfb1dutkdpmkp4kv
zone_id: ru-central1-c
v4_cidr_blocks:
- 192.168.0.0/24
```

#### Создание service account

Для скачивания Docker Image из приватного Registry необходимо создать service account, от имени которого будет действовать виртаульная машина на базе Container Optimized Image. Также необходимо дать права доступа для чтения приватного Registry от имени service account.

Для создания service account:
```
yc iam service-account create --name=demo-${FOLDER}-sa-puller
```

Пример вывода команды по созданию service account:
```
id: ajeitnu6otho0ih7ivpk
folder_id: b1g07qkm7vij7am773nd
created_at: "2019-09-30T11:22:45Z"
name: demo-b1g07qkm7vij7am773nd-sa-puller
```

После этого необходимо проставить в переменную окружения идентификатор созданого service account:
```
SA_PULLER=$(yc iam service-account get --name=demo-${FOLDER}-sa-puller --format=json | jq -r .id)
```

Для выдачи прав доступа на Registry:
```
yc resource-manager folder add-access-binding --id=${FOLDER} \
                                              --subject=serviceAccount:${SA_PULLER} \
                                              --role=container-registry.images.puller
```

### Настройка работы с приватным Registry

#### Создание приватного Registry

Для храния пользовательских Docker Images необходимо создать приватное Registry.

Для создания приватного Registry:
```
yc container registry create --name=demo
```

Пример вывода команды создания приватного Registry:
```
done (1s)
id: crplb12okm2i8me8u94f
folder_id: b1g07qkm7vij7am773nd
name: demo
status: ACTIVE
created_at: "2019-09-30T11:18:00.085Z"
```

После этого необходимо проставить в переменную окружения идентификатор созданного приватного Registry:
```
REGISTRY=$(yc container registry get --name=demo --format=json | jq -r .id)
```

#### Настройка аутентификации для Docker

Чтобы можно было пушить Docker Images необходимо настроить Docker CLI на работу приватным Registry. Для этого предлагается использовать Docker Cred Helper, который в свою очередь будет использовать OAUTH токен из настроек yc tools.

Настроить Docker на работу через Docker Cred Helper:
```
yc container registry configure-docker
```

Пример вывода команды по прописыванию Docker Cred Helper:
```
Credential helper is configured in '~/.docker/config.json'
```

### Подготовка и публикация Docker Image

В рамках этого раздела будет показано как собрать простое веб приложение на базе ngixn.

#### Разработка Docker Image

Создаем в рабочей директории место где будет лежать статический контент:
```
mkdir html
```

Создаем главную индексную страницу веб приложения (выполняется как одна команда):
```
cat <<EOF >html/index.html
<!DOCTYPE html>
<html>
  <head>
    <title>COI</title>
  </head>
  <body>
    <p>Hello world!</p>
  </body>
</html>
EOF
```

Создаем Dockerfile на базе nginx (выполняется как одна команда):
```
cat <<EOF >Dockerfile
FROM nginx:1.17
COPY html /usr/share/nginx/html
EOF
```

#### Сборка Docker Image

Собираем первую версию Docker Image:
```
docker build . -t cr.yandex/${REGISTRY}/demo:v1
```

Пример вывода команды по сборке Docker Image:
```
Sending build context to Docker daemon  142.6MB
Step 1/2 : FROM nginx:1.17
 ---> f949e7d76d63
Step 2/2 : COPY html /usr/share/nginx/html
 ---> Using cache
 ---> 7031c91ae2fc
Successfully built 7031c91ae2fc
Successfully tagged cr.yandex/crplb12okm2i8me8u94f/demo:v1
```

#### Публикация Docker Image 

Публикация Docker Image в приватном Registry:
```
docker push cr.yandex/${REGISTRY}/demo:v1
```

Пример вывода команды публикации Docker Image:
```
The push refers to repository [cr.yandex/crplb12okm2i8me8u94f/demo]
f7540548d12b: Pushed
509a5ea4aeeb: Pushed
3bb51901dfa3: Pushed
2db44bce66cd: Pushed
v1: digest: sha256:4670be8cee9e35a37b81e86d529c3c67d99695254361f47ae7b089c201a68842 size: 1155
```

### Создание виртуальной машины на базе Container Optimized Image

В рамках этой задачи будет создана виртуальная машина базе Container Optimized Image. Для машины будет выделен публичный айпи адрес. В настройках будет указан Docker Image созданный ранее.

Создание виртуальной машины:
```
yc compute instance create-with-container --container-image=cr.yandex/${REGISTRY}/demo:v1 \
                                          --container-name=nginx \
                                          --name=coi \
                                          --service-account-id=${SA_PULLER} \
                                          --create-boot-disk=size=4,type=network-ssd \
                                          --public-ip
```

Пример вывода команды создания виртуальной машины:
```
done (34s)
id: ef37na9nkag3v7t92k4e
folder_id: b1g07qkm7vij7am773nd
created_at: "2019-09-30T11:26:47Z"
name: coi
zone_id: ru-central1-c
platform_id: standard-v2
resources:
  memory: "2147483648"
  cores: "2"
  core_fraction: "100"
status: RUNNING
boot_disk:
  mode: READ_WRITE
  device_name: ef36d83f234njdcfuoot
  auto_delete: true
  disk_id: ef36d83f234njdcfuoot
network_interfaces:
- index: "0"
  mac_address: d0:0d:7b:a9:37:a2
  subnet_id: b0c9r4foch76lik7eupu
  primary_v4_address:
    address: 192.168.0.18
    one_to_one_nat:
      address: 84.201.170.181
      ip_version: IPV4
fqdn: ef37na9nkag3v7t92k4e.auto.internal
scheduling_policy: {}
service_account_id: ajeitnu6otho0ih7ivpk
```

После этого необходимо проставить в переменную окружения публичный айпи адрес созданной виртуальной машины:
```
PUBLIC_IP=$(yc compute instance get --format=json --name=coi | jq -r .network_interfaces[0].primary_v4_address.one_to_one_nat.address)
```

Спустя некоторое время (~1 минута), можно проверить что созданный Docker Image запущен и веб приложение работает:
```
curl "http://${PUBLIC_IP}/"
```

Пример вывода команды когда веб приложение запущено:
```
<!DOCTYPE html>
<html>
  <head>
    <title>COI</title>
  </head>
  <body>
    <p>Hello world!</p>
  </body>
</html>
```

### Внесение изменений в Docker Image

В рабочей директории вносим изменение в индексную страницу (выполняется как одна команда):
```
cat <<EOF >html/index.html
<!DOCTYPE html>
<html>
  <head>
    <title>COI</title>
  </head>
  <body>
    <p>War never changes!</p>
  </body>
</html>
EOF
```

Собираем Docker Image:
```
docker build . -t cr.yandex/${REGISTRY}/demo:v2
```

Пример вывода команды сборки Docker Image:
```
Sending build context to Docker daemon  142.6MB
Step 1/2 : FROM nginx:1.17
 ---> f949e7d76d63
Step 2/2 : COPY html /usr/share/nginx/html
 ---> Using cache
 ---> 7a97ae16f917
Successfully built 7a97ae16f917
Successfully tagged cr.yandex/crp0doirc18q67fhc33h/demo:v2
```

Публикация измененого Docker Image:
```
docker push cr.yandex/${REGISTRY}/demo:v2
```

Пример вывода команды публикации измененого Docker Image:
```
The push refers to repository [cr.yandex/crp0doirc18q67fhc33h/demo]
de52ddf22367: Pushed
509a5ea4aeeb: Layer already exists
3bb51901dfa3: Layer already exists
2db44bce66cd: Layer already exists
v2: digest: sha256:ac649d21790c02dfddfbd50ac7531e7ca9fdf594218335741ab4a8bb64105525 size: 1155
```

### Обновление Docker Image на виртуальной машине

В рамках этой задачи будет обновлен Docker Image на созданной ранее виртуальной машине. Это будет сделано без перезапуска виртуальной машины.

Обновление Docker Image на запущенной виртуальной машине:
```
yc compute instance update-container --container-image=cr.yandex/${REGISTRY}/demo:v2 \
                                     --container-name=nginx \
                                     --name=coi
```

Пример вывода команды обновления Docker Image:
```
done (1s)
id: ef32ajun5dm5mdvte68b
folder_id: b1go5o4cfkg2c7ah0ika
created_at: "2019-09-30T10:30:56Z"
name: coi
zone_id: ru-central1-c
platform_id: standard-v2
resources:
  memory: "2147483648"
  cores: "2"
  core_fraction: "100"
status: RUNNING
boot_disk:
  mode: READ_WRITE
  device_name: ef3bqmu3bpbfdnl76p3g
  auto_delete: true
  disk_id: ef3bqmu3bpbfdnl76p3g
network_interfaces:
- index: "0"
  mac_address: d0:0d:25:4f:d7:2b
  subnet_id: b0cd1tfd1lep434bt7o5
  primary_v4_address:
    address: 192.168.0.13
    one_to_one_nat:
      address: 84.201.169.191
      ip_version: IPV4
fqdn: ef32ajun5dm5mdvte68b.auto.internal
scheduling_policy: {}
service_account_id: ajer0ul57evo2m4mguvr
```

Спустя некоторое время (~30 секунд) можно увидеть новую версию веб приложения:
```
curl "http://${PUBLIC_IP}/"
```

Пример вывода команды когда работает новая версия веб приложения:
```
<!DOCTYPE html>
<html>
  <head>
    <title>COI</title>
  </head>
  <body>
    <p>War never changes!</p>
  </body>
</html>
```

### Зачистка созданного

Для удаленния виртуальной машины (внимание, данная команда удаляет все виртуальные машины в текущем folder):
```
yc compute instance list --format=json | jq -r .[].id | while read id ; do yc compute instance delete $id ; done
```

Для удаления созданных Docker Images (внимание, данная команда удаляет все Docker Images в текущем folder):
```
yc container image list --format=json | jq -r .[].id | while read id ; do yc container image delete $id ; done
```

Для удаления приватного Registry (внимание, данная команда удаляет все приватные Registry в текущем folder):
```
yc container registry list --format=json | jq -r .[].id | while read id ; do yc container registry delete $id ; done
```

Для удаления service account:
```
yc iam service-account delete ${SA_PULLER}
```

Для удаления подсетей (внимание, данная команда удаляет все подсети в текущем folder):
```
yc vpc subnet list --format=json | jq -r .[].id | while read id ; do yc vpc subnet delete $id ; done
```

Для удаления сети (внимание, данная команда удаляет все сети в текущем folder):
```
yc vpc network list --format=json | jq -r .[].id | while read id ; do yc vpc network delete $id ; done
```
