# Работа через terraform

* Зайдите в консоль облака https://console.cloud.yandex.ru и создайте себе фолдер
* В терминале рабочей станции инициируйте `yc init`
* Запишите id вашего фолдера, облака и ваш токен, выполнив `yc config list`
* Скачайте репозиторий с помощью git
```
git clone https://github.com/nar3k/yc-automation.git
cd yc-automation
```

Переходим в папку `02-03-terraform`

```
cd ../02-03-terraform
```

Документация к провайдеру terraform находится [тут](https://www.terraform.io/docs/providers/yandex/index.html)

### Изучим файлы terraform

* variables.tf - описание переменных
* network.tf - описание сети
* main.tf - описание инстансов
* output.tf - описание вывода

###  Создадим инфраструктуру
Скопируем файл terraform.tfvars_example в terraform.tfvars
```
cp terraform.tfvars_example terraform.tfvars
```

Заполним значения переменных в файле значениями, полученными при выводе 'yc config list'
* token  
* cloud_id
* folder_id

Остальные значения измените

Запустим terraform
```
terraform init
```
Применим инфраструктуру

```
terraform apply
```
Напишем yes, чтобы терраформ начал деплой


###  Проверим инфраструктуру

Подождем несколько минут, чтобы nginx установился
Зайдите в консоль облака, выберите ваш фолдер и посмотрите на созданные инстансы и сети

Посмотрим на полученные адреса

```
terraform output external_ip_addresses
```

Попробуем сделать в них curl
```
for i in $(terraform output external_ip_addresses | tr -d ','); do  
 curl $i;
done
```

###  Добавим новый инстанс в кластер

Создадим план деплоя с новым значением переменной  cluster_size

```
terraform plan -var cluster_size=3 -out new.plan
```
Применим новый план

```
terraform apply "new.plan"
```

Дождемся когда новый nginx добавиться в кластер и проверим что он работает

```
for i in $(terraform output external_ip_addresses | tr -d ','); do  
 curl  $i;
done
```

### Удаляем инфраструктуру

```
terraform destroy
```
