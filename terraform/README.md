# Работа через terraform

* Зайдите в консоль облака https://console.cloud.yandex.ru и создайте себе фолдер
* В терминале рабочей станции инициируйте `yc init`
* Запишите id вашего фолдера, облака и ваш токен, выполнив `yc config list`
* Скачайте данный репозиторий с помощью git
```
git clone https://github.com/nar3k/yc-public-tasks.git
cd yc-public-tasks
```

Переходим в папку `terraform`

```
cd terraform
```

Документация к провайдеру terraform находится [тут](https://www.terraform.io/docs/providers/yandex/index.html)

### Изучим файлы terraform

* `variables.tf` - описание переменных
* `network.tf` - описание сети
* `main.tf` - описание инстансов
* `output.tf` - описание вывода

###  Создадим инфраструктуру
Скопируем файл terraform.tfvars_example в terraform.tfvars
```
cp terraform.tfvars_example terraform.tfvars
```

Заполним значения переменных в файле значениями, полученными при выводе `yc config list`
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
Напишем `yes`, чтобы terraform начал деплой


###  Проверим инфраструктуру

Подождем несколько минут, чтобы nginx установился.
Зайдите в консоль облака, выберите ваш фолдер и посмотрите на созданные инстансы и сети.

Посмотрим на полученные адреса

```
terraform output external_ip_addresses
```
Попробуем подключимтся к созданным инстансам по полученным ip адресам

```
ssh ubuntu@<IP_ADDRESS>
```
Попробуем сделать в них curl. Сервера должны отвечать своими именами (которые получаются при выводе команды `terraform output hostnames`)
```
for i in $(terraform output external_ip_addresses | tr -d ','); do  
 curl $i;
done
```


###  Смаштабируем кластер

Размером кластера управляем переменная `cluster_size`. Изменим ее значения до 6 в файле `terraform.tfvars`

```
nrkk-osx:02 user$ cat terraform.tfvars
cluster_size = 6
```
Применим изменения.

```
terraform apply
```
Обратите внимание, что terraform просто добавит в кластер 3 узла

```
Plan: 3 to add, 0 to change, 0 to destroy.
```

Дождемся, когда новые узлы добавятся в кластер, и проверим что он работает

```
for i in $(terraform output external_ip_addresses | tr -d ','); do  
 curl  $i;
done
```

### Удаляем инфраструктуру

```
terraform destroy
```

Напишите `yes`.
Зайдите в консоль и убедитесь, что в вашем фолдере не осталось ресурсов.
