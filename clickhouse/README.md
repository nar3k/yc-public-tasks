# Работа с сервисом Managed Service for Clickhouse

Мы создадим кластер Clickhouse и попробуем развеять некоторые мифы о разнице погоды Москвы и Питера.
В этом нам поможет история метеонаблюдений за 10 лет, которую мы загрузим в СУБД.

## Подготовка кластера

* Зайдите в консоль Яндекс.Облака https://console.cloud.yandex.ru
* Cоздайте себе каталог, выбрав опцию создания сети по умолчанию
* Зайдите в созданный каталог

### Создание

* Перейдите на главную страницу сервиса Managed Service for Clickhouse
* Создайте кластер Clickhouse со следующими параметрами:
- Класс хоста - `s2.micro`
- Хосты - добавьте один или два хоста в разных зонах доступности (чтобы суммарно было не менее двух хостов) и укажите необходимость публичного доступа (публичного IP адреса) для них
- Имя пользователя - `user1`
- База данных - `db1`
- Пароль - `CH1-test-123456`

Остальные параметры оставьте по умолчанию, либо измените по своему усмотрению.

* Нажмите кнопку Создать кластер и дождитесь окончания процесса создания (Статус кластера = `RUNNING`). Кластер создается от 5 до 10 минут
* Обратите внимание на калькулятор стоимости услуги и изменение стоимости при изменении параметров кластера.

### Создание таблиц

Прежде, чем мы сможем загрузить датасет, нам потребуется создать табличку.

* Выберите кластер на странице сервиса
* Войдя в меню, выберите пункт "SQL" слева
* Авторизуйтесь и выберите созданную базу (по умолчанию `db1`)
* Создайте табличку:
```sql
CREATE TABLE db1.weather
(
    `LocalDateTime` DateTime,
    `LocalDate` Date,
    `Month` Int8,
    `Day` Int8,
    `TempC` Float32,
    `Pressure` Float32,
    `RelHumidity` Int32,
    `WindSpeed10MinAvg` Int32,
    `VisibilityKm` Float32,
    `City` String
)
ENGINE = MergeTree()
PARTITION BY toYear(LocalDate)
ORDER BY LocalDate
```

### Вставка данных

Для заливки воспользуемся скриптом на python (ниже).
В него нужно вставить `hostname` -- его можно выяснить во вкладке "Обзор", нажав кнопку "Подключиться".
Сам датасет, `weather_data.csv.gz`, лежит в текущей директории. Его нужно предварительно распаковать:
```
gunzip weather_data.csv.gz
```

```python
#!/usr/bin/env python
from __future__ import print_function
import requests

USER = 'user1'
PW = 'CH1-test-123456'
DB = 'db1'
HOST = '<hostname>'
CSVFILE = 'weather_data.csv'

def request(host, text, data):
    url = 'https://{host}:8443/?database={db}&query={query}'.format(
        host=host,
        db=DB,
        query=text)
    auth = {
        'X-ClickHouse-User': USER,
        'X-ClickHouse-Key': PW,
    }
    res = requests.post(url, headers=auth, data=data, verify='yandex_ca.pem')
    res.raise_for_status()
    return res.text

def upload():
    query = 'INSERT INTO {0}.weather FORMAT TabSeparated'.format(DB)
    return request(HOST, query, open(CSVFILE).read())

def main():
    try:
        print(upload())
        print('Upload completed ok')
    except Exception:
        raise

main()
```


### Запросы о погоде

Давайте попробуем разобраться как на самом деле обстоят дела с климатом в двух крупнейших мегаполисах России.
Запросы ниже удобнее всего будет делать через веб-консоль: для этого отройте стартовую страницу сервиса, перейдите в ваш кластер и нажмте на вкладку "SQL" (слева).

* Правда ли что в Питере и Москве разный климат? Посмотрим разницу среднегодовой температуры у этих городов.

```sql
SELECT
    Year,
    msk.t - spb.t
FROM
(
    SELECT
        toYear(LocalDate) AS Year,
        avg(TempC) AS t
    FROM db1.weather
    WHERE City = 'Moscow'
    GROUP BY Year
    ORDER BY Year ASC
) AS msk
INNER JOIN
(
    SELECT
        toYear(LocalDate) AS Year,
        avg(TempC) AS t
    FROM db1.weather
    WHERE City = 'Saint-Petersburg'
    GROUP BY Year
    ORDER BY Year ASC
) AS spb USING (Year)
```
Как насчет скорости ветра? Или влажности (Питер все-таки морской город)?
Попрубуйте изменить некоторые поля в запросе, чтобы узнать.

Ветер -- `WindSpeed10MinAvg` (среднее за 10 минут)

Относительная влажность -- `RelHumidity`

* Наверняка самая низкая температура была зарегистрирована в Питере. Давайте убедимся.
```sql
SELECT
    City,
    LocalDate,
    TempC
FROM db1.weather
ORDER BY TempC ASC
LIMIT 1
```
Можно посмотреть также и жару, изменив один параметр.

* Давайте попробуем что-то аналитическое. Например, где раньше начинается лето?
Будем считать, что лето -- это когда в течение 10 дней (`864000` секунд) было более 15 градусов хотя бы три раза.
```sql
SELECT
    City,
    toYear(md) AS year,
    min(md) AS month
FROM
(
    SELECT
        City,
        toYYYYMM(LocalDate) AS ym,
        min(LocalDate) AS md,
        windowFunnel(864000)(LocalDateTime, TempC >= 15, TempC >= 15, TempC >= 15) AS warmdays
    FROM db1.weather
    GROUP BY
        City,
        ym
)
WHERE warmdays = 3
GROUP BY
    year,
    City
ORDER BY
    year ASC,
    City ASC,
    month ASC
```
А когда начинается осень? Поменяйте агрегатную функцию во внешнем `SELECT`, чтобы узнать.

Кстати, при помощи похожего запроса можно [считать](https://clickhouse.yandex/docs/ru/query_language/agg_functions/parametric_functions/#windowfunnel-window-timestamp-cond1-cond2-cond3) конверсию покупок в онлайн-ретейле.


### Удалите кластер

* Удалите кластер выбрав соответствующее действие в UI консоли.
* Обратите внимание, что данные удаляемого кластера можно восстановить в течении 7 дней после удаления, т.к. в течении этого периода сохраняются его резервные копии.
