# Использование Yandex.Cloud OCR API и Python

Здравствуйте! В этом примере мы научимся использовать облачный сервис для распознавания текста из изображений при помощи API Яндекс.Облака и Python.


# Получение доступа к API

Есть два способа использования сервиса:

 1. При помощи токена авторизации IAM,  при этом токен необходимо своевременно продлять (им и воспользуемся).
 2. При помощи ключа API 

## Как запустить демо?

 1. Откройте в браузере консоль Яндекс.Облака: https://console.cloud.yandex.ru/
 2. Перейдите в созданный для мероприятия каталог
 3. Скопируйте из URL вида /folders/b1glv8a2h52e6dpg8ngb ID каталога (например b1glv8a2h52e6dpg8ngb)
 4. Откройте Jupyter Notebook "OCR", расположенный по адресу [http://84.201.157.101:8888/notebooks/my_project_dir/my_project_env/OCR.ipynb](http://84.201.157.101:8888/notebooks/my_project_dir/my_project_env/OCR.ipynb), (токен доступа  - 4831fad7cc6b83a8dca2a117960b1e77ef8f07ee44f84669  и подставьте его в 33 строку второй ячейки, в значение переменной folder_id.
 5. Получите токен по ссылке [https://oauth.yandex.ru/authorize?response_type=token&client_id=1a6990aa636648e9b2ef855fa7bec2fb](https://oauth.yandex.ru/authorize?response_type=token&client_id=1a6990aa636648e9b2ef855fa7bec2fb) 
 6. Скопируйте его и подставьте в 34-ю строку 2-й ячейки в значение переменной oauth_token.




## Тестирование сервиса
1. Выполните ячейки - (для этого нажмите Shift+Enter) 
## Поздравляем, у вас все получилось!
