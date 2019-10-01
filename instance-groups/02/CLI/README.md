# Обновление группы виртуальных машин под нагрузкой

### Подготовка окружения
Создайте для себя новый каталог, сеть, сабнеты в каждой зоне доступности и сервисный аккаунт.
Для этого запустите скрипт `init_common.sh` и следуйте инструкциям.

### Создание группы виртуальных машин
Создайте группу инстансов, которая интегрируется с балансировщиком сетевой нагрузки из спецификации

```
cat 02/CLI/specification.yaml
yc compute instance-group create --file=02/CLI/specification.yaml
```

Дождитесь выполнения команды. 

Вы можете наблюдать за процессом создания через [веб-консоль облака](https://console.cloud.yandex.ru/). 
Для этого зайдите в ваш фолдер, далее выберите Сompute и перейдите в раздел "Группы виртуальных машин" и посмотрите на созданную вами группу.

Также можно наблюдать за процессом через командную строку 
`watch yc compute instance-group list-instances load-generator`

По окончанию развертывания будет создана группа однотипных виртуальных машин, каждая из которых будет
создана из container optimized образа. При старте инстанса будет скачиваться докер контейнер openresty из
публичного репозитория. Данный докер-образ содержит nginx и дополнительные модули, благодаря
которым мы сможем эмулировать процесс обработки запроса, "засыпая" на 10 секунд на каждое обращение.
Таким образом, мы сможем увидеть, что все запросы обработаны, не смотря на то, что группа вм будет
обновлена.

### Подключим балансировщик к созданной группе виртуальных машин

Создадим балансировщик, к которому подключена таргет-группа
```
TG_ID=$(yc compute instance-group get load-generator --format json | jq -r .load_balancer_state.target_group_id)

yc load-balancer network-load-balancer create --name load-generator --region-id ru-central1 --type external \
--target-group target-group-id=$TG_ID,healthcheck-name=http,healthcheck-http-port=80,healthcheck-http-path=/ \
--listener name=http,port=80,target-port=80,protocol=tcp,external-ip-version=ipv4
```
Дождитесь выполнения команды. 
Наблюдать за ним можно через веб консоль или через командную строку:
`watch yc load-balancer network-load-balancer list`


### Проверим запущенный веб-сервис

Команды ниже сделают 5 HTTP запросов на адрес балансировщика. Веб сервера за балансирощиком ответят своими fqdn именами.

```
EXTERNAL_IP=$(yc load-balancer network-load-balancer get load-generator --format=json | jq -r .listeners[0].address)

for i in {1..5}
do
  curl -s -I $EXTERNAL_IP | grep HTTP/ | awk {'print $2'} 
done
```

### Обновим группу под нагрузкой

Запустим в отдельной вкладке утилиту, которая будет отправлять запросы на созданный балансировщик в 20 потоков
```
EXTERNAL_IP=$(yc load-balancer network-load-balancer get load-generator --format=json | jq -r .listeners[0].address)

wrk -t20 -c20 -d1h --timeout 20s http://$EXTERNAL_IP/sleep 
```
Изменим спецификацию группы. Например, уменьшим кол-во ядер (`cores: 2` поменяем на `cores: 1`, и увеличим размер бут-диска)
```
sed -i '' -e "s/cores: 2/cores: 1/g" -e "s/size: 10G/size: 15G/g" 02/CLI/specification.yaml
```
Обновим группу виртуальных машин
```
cat 02/CLI/specification.yaml
yc compute instance-group update load-generator --file=02/CLI/specification.yaml
```

Дождитесь выполнения команды. 

Вы можете наблюдать за процессом создания через [веб-консоль облака](https://console.cloud.yandex.ru/). 
Для этого зайдите в ваш фолдер, далее выберите Сompute и перейдите в раздел "Группы виртуальных машин" и посмотрите на созданную вами группу.

Также можно наблюдать за процессом через командную строку 
`watch yc compute instance-group list-instances load-generator`

По окончании обновления группы, проверим, что ни одного запроса не было потеряно. Для этого остановим выполнение `wrk` которая генерировала нагрузку, нажав `Ctrl-C`:
В консоль будет выведена информация о ее работе - кол-ве выполненных запросов и их результатах.
```
 Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    51.12ms   20.99ms 131.32ms   76.41%
    Req/Sec    18.71      6.65    30.00     57.14%
  544 requests in 1.44s, 253.94KB read
Requests/sec:    377.74
Transfer/sec:    176.33KB
```


### Удалим инфраструктуру

Удалим балансировщик и группу виртуальных машин
```
yc load-balancer network-load-balancer delete load-generator
yc compute instance-group delete load-generator
```
