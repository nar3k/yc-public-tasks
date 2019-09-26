# Работа с сервисом Compute

Если у вас еще нет интерфейса командной строки Яндекс.Облака, установите его и выполните инициализацию. Подробнее: https://cloud.yandex.ru/docs/cli/quickstart

## Создайте ВМ

Посмотрите описание команды CLI для создания виртуальной машины:

```
yc compute instance create --help
```

Создайте виртуальную машину в каталоге по умолчанию:

```
yc compute instance create \
	--name scale-b \
	--description "Yandex.Scale-2019" \
	--hostname scale-b \
	--zone ru-central1-b \
	--platform-id standard-v2 \
	--cores 2 \
	--core-fraction 100 \
	--memory 2 \
	--preemptible \
	--create-boot-disk name=scale-b,type=network-ssd,size=10,image-folder-id=standard-images,image-family=ubuntu-1804-lts \
	--network-interface subnet-name=default-ru-central1-b,nat-ip-version=ipv4 \
	--ssh-key ~/.ssh/id_rsa.pub
```

На машине будет создан пользователь ```yc-user``` с публичным ключом из файла ```~/.ssh/id_rsa.pub```.

Подключитесь к виртуальной машине:

```
ssh yc-user@<публичный_IP-адрес_виртуальной машины>
```

Установите ```nginx``` на виртуальной машине:

```
sudo apt-get update
sudo apt-get install nginx
```

Проверьте работоспособность web-сервера. Перейдите в браузере по ссылке:

```
http://<публичный_IP-адрес_виртуальной машины>
```

## Измените размер ВМ

Остановите виртуальную машину, созданную в предыдущем примере:

```
yc compute instance stop scale-b
```

Измените количество ядер и памяти:

```
yc compute instance update scale-b --cores 8 --memory 8
```

Запустите виртуальную машину:

```
yc compute instance start scale-b
```

## Создайте дополнительный диск

Создайте новый диск в той же зоне доступности, что и виртуальная машина из первого примера:

```
yc compute disk create --name scale-b-data --zone ru-central1-b --type network-hdd --size 20
```

Подключите новый диск к запущенной виртуальной машине:

```
yc compute instance attach-disk scale-b --disk-name scale-b-data
```

Подключитесь к виртуальной машине:

```
ssh yc-user@<публичный_IP-адрес_виртуальной машины>
```

Выполните команду ```lsblk```, чтобы проверить, подключен ли диск как устройство и узнать его путь в системе. Обычно, пустой диск имеет метку вида ```/dev/vdb```.

Разметьте новый диск:

```
lsblk
sudo cfdisk /dev/vdb
```

Отформатируйте диск:

```
sudo mkfs /dev/vdb
```

Смонтируйте готовый раздел:

```
sudo mkdir /mnt/scale-b-data
sudo mount /dev/vdb /mnt/scale-b-data
lsblk
```

Отключить диск от работающей виртуальной машины можно с помощью команды:

```
yc compute instance detach-disk scale-b --disk-name scale-b-data
```

## Создайте резервную копию диска

Создайте резервную копию загрузочного диска виртуальной машины, созданной в первом примере:

```
yc compute snapshot create --name scale-b-backup --disk-name scale-b
```

Удалите виртуальную машину и её загрузочный диск:

```
yc compute instance delete scale-b
```

Создайте новую виртуальную машину из резервной копии:

```
yc compute instance create \
	--name scale-b \
	--description "Yandex.Scale-2019" \
	--hostname scale-b \
	--zone ru-central1-b \
	--platform-id standard-v2 \
	--cores 2 \
	--core-fraction 100 \
	--memory 2 \
	--preemptible \
	--create-boot-disk name=scale-b,type=network-ssd,snapshot-name=scale-b-backup \
	--network-interface subnet-name=default-ru-central1-b,nat-ip-version=ipv4 \
	--ssh-key ~/.ssh/id_rsa.pub
```

Подключитесь к виртуальной машине:

```
ssh yc-user@<публичный_IP-адрес_виртуальной машины>
```

Проверьте работоспособность web-сервера. Перейдите в браузере по ссылке:

```
http://<публичный_IP-адрес_виртуальной машины>
```

## Удалите ресурсы

Удалите ресурсы, созданные в предыдущих примерах (виртуальную машину, дополнительный диск и резервную копию диска):

```
yc compute instance delete scale-b
yc compute disk delete scale-b-data
yc compute snapshot delete scale-b-backup
```
