# Сетевые сервисы Яндекс облака


### Подготовка окружения
* Зайдите в консоль облака https://console.cloud.yandex.ru и создайте себе Каталог (folder) - - создавать сеть по умолчанию там не требуется
* В терминале рабочей станции инициируйте `yc init`
* Выберите созданный вами folder

### Создание сетей и подсетей

Создадим сеть и подсети в трех зонах доступности.
**Сеть** - это изолированная приватная сеть в вашем облаке.
Ресурсы облака создаются в **подсетях**. Между всеми **подсетями** внутри **сети** обеспечивается полная IP связность.
```
yc vpc network create --name yc-auto-network

zones=(a b c)

for i in ${!zones[@]}; do
  echo "Creating subnet yc-auto-subnet-${zones[$i]}"
  yc vpc subnet create --name yc-auto-subnet-${zones[$i]} \
  --zone ru-central1-${zones[$i]} \
  --range 192.168.$i.0/24 \
  --network-name yc-auto-network
done
```
### Активация доступа в интернет на подсетях

Мы создали сети и подсети с помощью командной строки. Теперь активизируем доступ в интернет в этих подсетях.  Это нужно, чтобы виртуальные машины, которые мы создадим в задании далее могли выходить в интернет без необходимости получать публичный IP адрес.

* Зайдите в созданный вами каталог
* Выберите сервис Virtual Private Cloud
* Выберите созданную вами сеть - yc-auto-network
* Нажмите на знак "..." в строке с одной из подсетей и нажмите "Включить NAT в интернет"
* Включите NAT в интернет для всех подсетей

Напомним, что функционал Включения NAT в интернет на 01 октября 2019 года доступен в режиме Preview.

### Создание группы виртуальных машин
Создаем группу инстансов, которая интегрируется с целевой группой

Создадим сервисный аккаунт для работы группы виртуальных машин и дадим ему роль администратора в фолдере
```
FOLDER_ID=$(yc config get folder-id)
SA_NAME=ig-sa-$FOLDER_ID
yc iam service-account create --name $SA_NAME
SA_ID=$(yc iam service-account get --name $SA_NAME --format json | jq .id -r)
yc resource-manager folder add-access-binding --id $FOLDER_ID --role admin --subject serviceAccount:$SA_ID
```


Создадим файл конфигурации для группы VM 
```
cat > nginx.yaml <<EOF
name: nginx
service_account_id: $(echo $SA_ID)
instance_template:
  platform_id: standard-v2
  resources_spec:
    memory: 2147483648
    cores: 2
    core_fraction: 100
  metadata:
    user-data: |-
      #cloud-config
      apt:
        preserve_sources_list: true
      package_update: true
      runcmd:
        - [ sh, -c, "until ping -c1 www.centos.org &>/dev/null; do :; done" ]
        - [ sh, -c, "until ping -c1 www.docker.com &>/dev/null; do :; done" ]
        - [ sh, -c, "until ping -c1 www.google.com &>/dev/null; do :; done" ]
        - [ sh, -c, "sleep 60" ]
        - [ sh, -c, "systemd-resolve --flush-cache" ]
        - [ sh, -c, "apt update -y "]
        - [ sh, -c, "apt install -y nginx" ]
        - [ systemctl, daemon-reload ]
        - [ systemctl, enable,  nginx.service ]
        - [ systemctl, start, --no-block, nginx.service ]
        - [ sh, -c, "echo \$(hostname | cut -d '.' -f 1 ) > /var/www/html/index.html" ]
  boot_disk_spec:
    mode: READ_WRITE
    disk_spec:
      type_id: network-ssd
      size: 21474836480
      image_id: fd8o145rut84nlussc8a
  network_interface_specs:
  - network_id: $(yc vpc network get --name yc-auto-network --format=json | jq .id -r)
    primary_v4_address_spec: {}
scale_policy:
  fixed_scale:
    size: 3
deploy_policy:
  max_unavailable: 1
  starting_duration: 0s
allocation_policy:
  zones:
  - zone_id: ru-central1-a
  - zone_id: ru-central1-b
  - zone_id: ru-central1-c
load_balancer_spec:
    target_group_spec:
        name: nginx

EOF
```

```
cat nginx.yaml
yc compute instance-group create --file=nginx.yaml
rm -rf nginx.yaml
```
Дождитесь завершения операции в командной строке. Теперь зайдите в консоль Облака в ваш каталог, далее выберите Сompute и перейдите в раздел "Группы виртуальных машин" и посмотрите на созданную вами группу. Также можно выбрать по очереди каждую виртуальную машину целевой группы, посмотреть на ее свойства и убедится, что у виртуальной машины нет публичного IP-адреса.


### Подключим балансировщик нагрузки с защитой от DDoS

Создадим балансировщик, к которому подключена таргет группа
* Зайдите в созданный вами каталог
* Выберите Load balancer
* Нажмите "Создать балансировщик"
* Присвойте балансировщику имя nginx
* Установите галочку напротив свойства "Защита от DDoS-атак"
* Добавьте обработчик на порту 80
* Добавьте созданную целевую группу (она называется "nginx") с проверкой состояния, работающей по HTTP на 80 порту, и выполняющей запросы на url '/'

### Проверим балансировщик

Зайдите в раздел "Load balancer", посмотрите на созданный балансировщик, откройте его и проверьте, что все ВМ находятся в статусе Healthy (для этого может понадобится несколько минут, так как установка на nginx на виртуальные машины занимает некоторое время).

Команды ниже сделают 30 HTTP запросов на адрес балансировщика. Веб-серверы за балансирощиком ответят своими именами хостов.

```
EXTERNAL_IP=$(yc load-balancer network-load-balancer get nginx --format=json | jq .listeners[0].address -r )

for i in {1..30}
do
  curl --silent $EXTERNAL_IP
done
```

Поздравляем - в этом задании вы с помощью сервисов VPC создали защищенную и отказоустойчивую инфраструктуру для вашего приложения!

### Удалим инфраструктуру

Удалим Балансировщик и группу витуальных машин
```
yc load-balancer network-load-balancer delete --name nginx

yc compute instance-group delete --name nginx
```

Удалим сервисный аккаунт
```

yc iam service-account delete --name $SA_NAME
```

Удалим сеть

```
zones=(a b c)

for i in ${!zones[@]}; do
  echo "Deleting subnet yc-auto-subnet-${zones[$i]}"
  yc vpc subnet delete --name yc-auto-subnet-${zones[$i]}
done

echo "Deleting network yc-auto-network"
yc vpc network delete --name yc-auto-network

```
