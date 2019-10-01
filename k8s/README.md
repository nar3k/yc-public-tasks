# Работа с Managed Kubernetes и Container Registry


### Подготовка окружения
* Зайдите в консоль облака https://console.cloud.yandex.ru и создайте себе каталог (folder) - создавать сеть по умолчанию там не требуется.
* В терминале рабочей станции инициируйте `yc init`.
* Выберите созданный вами каталог.


### Создание сети для задания

Создадим сеть и подсети в трех зонах доступности для работы группы виртуальных машин

```
yc vpc network create --name yc-auto-network

zones=(a b c)

for i in ${!zones[@]}; do
  echo "Creating subnet yc-auto-subnet-$i"
  yc vpc subnet create --name yc-auto-subnet-$i \
  --zone ru-central1-${zones[$i]} \
  --range 192.168.$i.0/24 \
  --network-name yc-auto-network
done
```



### Создание кластера Kubernetes и Container Registry

#### Создадим сервисный аккаунт для кластера
```
FOLDER_ID=$(yc config get folder-id)

yc iam service-account create --name k8s-sa-${FOLDER_ID}
SA_ID=$(yc iam service-account get --name k8s-sa-${FOLDER_ID} --format json | jq .id -r)
yc resource-manager folder add-access-binding --id $FOLDER_ID --role admin --subject serviceAccount:$SA_ID
```

#### Создадим мастер
```

yc managed-kubernetes cluster create \
 --name k8s-demo --network-name yc-auto-network \
 --zone ru-central1-a  --subnet-name yc-auto-subnet-0 \
 --public-ip \
 --service-account-id ${SA_ID} --node-service-account-id ${SA_ID} --async

```
Создание мастера занимает около 7 минут - в это время мы создадим Container Registry и загрузим в него Docker образ

Создадим Container Registry

```
yc container registry create --name yc-auto-cr
```

Аутентифицируемся в Container Registry

```
yc container registry configure-docker
```

Создадим Dockerfile

```
cat > hello.dockerfile <<EOF
FROM ubuntu:latest
CMD echo "Hi, I'm inside"
EOF
```
Соберем образ и загрузим его в Registry
```
REGISTRY_ID=$(yc container registry get --name yc-auto-cr  --format json | jq .id -r)
docker build . -f hello.dockerfile \
-t cr.yandex/$REGISTRY_ID/ubuntu:hello

docker push cr.yandex/${REGISTRY_ID}/ubuntu:hello
```
Проверим, что в Container Registry появился созданный образ

```
yc container image list
```


#### Создание группы узлов

Перейдите в веб интерфейс вашего каталога в раздел "Managed Service For Kubernetes". Дождитесь создания кластера - он должен перейти в статус `Ready` и состояние `Healthy`.
Теперь создадим группу узлов

```
yc managed-kubernetes node-group create \
 --name k8s-demo-ng \
 --cluster-name k8s-demo \
 --platform-id standard-v2 \
 --public-ip \
 --cores 2 \
 --memory 4 \
 --core-fraction 50 \
 --disk-type network-ssd \
 --fixed-size 2 \
 --location subnet-name=yc-auto-subnet-0,zone=ru-central1-a \
 --async
 ```

#### Подключение к кластеру

Создание группы узлов занимает около 3 минут - давайте пока подключимся к кластеру при помощи kubectl.

Настроим аутентификацию в кластере
```
yc managed-kubernetes cluster get-credentials --external --name k8s-demo
```

Дождемся создания группы узлов с помощью kubectl

```
watch kubectl get nodes
```
Когда команда начнет выводить 2 узла в статусе `Ready`, значит кластер готов для работы. 
Нажмите  `Ctrl`+`C` для выхода из режима watch.


### Тестовое приложение

В данном разделе мы установим тестовое приложение, чтобы показать возможности интеграции сущностей Load Balancer и 
Persistent Volume с Яндекс.Облаком, а также интеграцию с Container Registry.

####  Интеграция с Container Registry

Запустите pod, который хранит образ в Container Registry
```
kubectl run --attach hello-ubuntu --image cr.yandex/${REGISTRY_ID}/ubuntu:hello
```

Найдите этот pod и посмотрите его название

```
$kubectl get po
$kubectl logs POD_NAME

Hi, I'm inside
```

Как видите, pod загрузил образ без необходимости делать аутентификацию на стороне registry.

#### Установка Helm v2

Установите tiller
```
cat  > tiller-sa.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF
kubectl apply -f tiller-sa.yaml
helm init --service-account tiller
```

#### Установите Prometheus 
```
helm install --name prom stable/prometheus
```
дождитесь, пока запустятся все pod-ы  :
```
$ kubectl get pods -o wide

NAME                                                  READY   STATUS    RESTARTS   AGE   IP              NODE                        NOMINATED NODE   READINESS GATES
prom-prometheus-alertmanager-5bfc6bdc65-jskzs         2/2     Running   0          20m   10.112.129.3    cl1n14i18r68jrph2nip-ezuw   <none>           <none>
prom-prometheus-kube-state-metrics-5df649d7b5-hkp55   1/1     Running   0          20m   10.112.129.2    cl1n14i18r68jrph2nip-ezuw   <none>           <none>
prom-prometheus-node-exporter-44xzj                   1/1     Running   0          20m   172.17.0.15     cl1n14i18r68jrph2nip-ezuw   <none>           <none>
prom-prometheus-node-exporter-c5v4k                   1/1     Running   0          20m   172.17.0.6      cl1n14i18r68jrph2nip-izid   <none>           <none>
prom-prometheus-node-exporter-tk22d                   1/1     Running   0          20m   172.17.0.3      cl1n14i18r68jrph2nip-arub   <none>           <none>
prom-prometheus-pushgateway-55887dc9f8-9prkv          1/1     Running   0          14m   10.112.129.4    cl1n14i18r68jrph2nip-ezuw   <none>           <none>
prom-prometheus-server-9bdb4fdf8-5fpdg                2/2     Running   0          14m   10.112.128.10   cl1n14i18r68jrph2nip-arub   <none>           <none>
```
####  Persistent Volumes
Посмотрите persistent volumes

```
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                STORAGECLASS     REASON   AGE
pvc-3a51d0eb-e1f3-11e9-a841-d00d11b3fc30   2Gi        RWO            Delete           Bound    scale/prom-prometheus-alertmanager   yc-network-hdd            25m
pvc-3a546f8f-e1f3-11e9-a841-d00d11b3fc30   8Gi        RWO            Delete           Bound    scale/prom-prometheus-server         yc-network-hdd            24m
```
посмотрите диски в compute. Первые 2 - это persistent volumes для Prometheus
```
$ yc compute disk list

+----------------------+--------------------------------------------------+--------------+---------------+--------+----------------------+-------------+
|          ID          |                       NAME                       |     SIZE     |     ZONE      | STATUS |     INSTANCE IDS     | DESCRIPTION |
+----------------------+--------------------------------------------------+--------------+---------------+--------+----------------------+-------------+
| epd2gp5a9autq7bbboka | k8s-csi-f396782f2bb9d9a97cc22fc36f58727f3a566ba2 |   2147483648 | ru-central1-b | READY  | epd0khqhv7g4orvus14t |             |
| epd5p4ntg142s5bmr5q9 | k8s-csi-275082ef18e5e2629eed4cd3820873025f40c0e5 |   8589934592 | ru-central1-b | READY  | epdgbb8rdnf0802shqme |             |
| epdderf768sv8piehojv |                                                  | 103079215104 | ru-central1-b | READY  | epdgbb8rdnf0802shqme |             |
| epdlgt4m1ne23tj2hmur |                                                  | 103079215104 | ru-central1-b | READY  | epdsumepapjcruujnv9e |             |
| epdqu65bl1atqqtlod6a |                                                  | 103079215104 | ru-central1-b | READY  | epd0khqhv7g4orvus14t |             |
+----------------------+--------------------------------------------------+--------------+---------------+--------+----------------------+-------------+
```

Узнаем имя узла, где запущен prometheus-server
```
$ kubectl get po -o wide | grep prom-prometheus-server

prom-prometheus-server-df7c4757b-cdhj8                2/2     Running   0          6m30s   10.112.128.6   cl1eund4clhgtmm3r7kd-umyt   <none>           <none
```

В выводе выше имя узла это - `cl1eund4clhgtmm3r7kd-umyt`.

Сделайте drain узлу, на котором работает prometheus-server.
```
$ kubectl drain NODE_NAME  --ignore-daemonsets
```



Понаблюдайте, как pod переназначится на другой узел и, когда он запустится,
выполните `yc compute disk list` еще раз - вы заметите, что диск с данными переподключился к другому узлу.
####  Load Balancer

Откройте наружу сервис Prometheus:
```
$ kubectl patch svc prom-prometheus-server --type merge -p '{"spec": {"type": "LoadBalancer"}}'
```

Дождитесь, пока сервис не откроется наружу:
```
$ watch kubectl get svc prom-prometheus-server
NAME                     TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)        AGE
prom-prometheus-server   LoadBalancer   10.96.247.101   84.201.136.8   80:31955/TCP   36m
```
Когда в столбце EXTERNAL-IP появится IP адрес, перейдите по нему в браузере - вы должны попасть на страницу сервиса Prometheus.

Зайдите в UI облака и посмотрите, что создался балансировщик нагрузки.
На текущий момент он показывает, что все узлы кластера находятся в статусе `Healthy`

Поменяйте external traffic policy на Local
```
$ kubectl patch svc prom-prometheus-server --type merge -p '{"spec": {"externalTrafficPolicy": "Local"}}'
```

дождитесь, пока на балансировщике не отобразится готовность целевых адресов. Заметьте, что `HEALTHY` адрес только
у того узла, на котором работает pod prometheus-server.

###  Завершение работы

Удалите кластер (занимает около 1 минуты)
```
yc managed-kubernetes cluster delete --name k8s-demo
```

Удалите сервисный аккаунт
**Внимание: не удаляйте сервисный аккаунт до удаления кластера!**
```
yc iam service-account delete --id $SA_ID
```

Удалите Container Registry
```
IMAGE_ID=$(yc container image list   --format json | jq .[0].id -r)
yc container image delete --id $IMAGE_ID
yc container registry delete --name yc-auto-cr

```

Удалите подсети и сеть
```
zones=(a b c)

for i in ${!zones[@]}; do
  echo "Deleting subnet yc-auto-subnet-$i"
  yc vpc subnet delete --name yc-auto-subnet-$i
done

echo "Deleting network yc-auto-network"
yc vpc network delete --name yc-auto-network

```
