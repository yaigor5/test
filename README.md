# Тестовое задание 
## Формулировка задачи

### Выполнить разбор файла почтового лога, залить данные в БД и организовать поиск по адресу получателя.
<u>_Исходные данные:_</u>
1. Файл лога maillog
2. Схема таблиц в БД (допускается использовать postgresql или mysql):
```mysql
CREATE TABLE message (
created TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
id VARCHAR NOT NULL,
int_id CHAR(16) NOT NULL,
str VARCHAR NOT NULL,
status BOOL,
CONSTRAINT message_id_pk PRIMARY KEY(id)
);
CREATE INDEX message_created_idx ON message (created);
CREATE INDEX message_int_id_idx ON message (int_id);
CREATE TABLE log (
created TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
int_id CHAR(16) NOT NULL,
str VARCHAR,
address VARCHAR
);
CREATE INDEX log_address_idx ON log USING hash (address);
```
<u>_Пояснения:_</u>
В качестве разделителя в файле лога используется символ пробела.
Значения первых полей:
__дата__
__время__
__внутренний id сообщения__
__флаг__
__адрес получателя (либо отправителя)__
__другая информация__
В качестве флагов используются следующие обозначения:
__<=__ прибытие сообщения (в этом случае за флагом следует адрес отправителя)
__=>__ нормальная доставка сообщения
__->__ дополнительный адрес в той же доставке
__**__ доставка не удалась
__==__ доставка задержана (временная проблема)
В случаях, когда в лог пишется общая информация, флаг и адрес получателя не указываются.

<u>_Задачи:_</u>
1. Выполнить разбор предлагаемого файла лога с заполнением таблиц БД: 
В таблицу message должны попасть только строки прибытия сообщения (с флагом <=). Поля таблицы 
должны содержать следующую информацию:
__created__ - timestamp строки лога
__id__ - значение поля id=xxxx из строки лога
__int_id__ - внутренний id сообщения
__str__ - строка лога (без временной метки)
В таблицу log записываются все остальные строки:
__created__ - timestamp строки лога
__int_id__ - внутренний id сообщения
__-str__ - строка лога (без временной метки)
__address__ - адрес получателя
2. Создать html-страницу с поисковой формой, содержащей одно поле (*type="text"*) для ввода адреса получателя.
Результатом отправки формы должен являться список найденных записей '<timestamp> <строка лога>' из двух 
таблиц, отсортированных по идентификаторам сообщений (*int_id*) и времени их появления в логе.
Отображаемый результат необходимо ограничить сотней записей, если количество найденных строк превышает 
указанный лимит, должно выдаваться соответствующее сообщение.

___

## Оставляем за рамками рассмотрения:
1. Способ запуска парсера логов, запускается разово в теле основной части для данного задания.
2. Ротацию лога и прочее системное.
3. Особенности архитектуры БД и степень соответствия с ТЗ, берем структуру совместимую с доступной в тестовой среде (mariadb) из предложенной в задании.
4. Способ формирования списка зависосмостей по модулям.
5. Способ первичной настройки окружения, в данном случае создан для этого скрипт **init.pl**.

## Методика реализации:
1. Входные данные отдельно от кода
2. Выбор способа реализации/модулей для конкретной задачи
3. Разбивка на модули, сегментация кода
4. Кодирование, оформление, документирование, тестирование

**init.pl** - использовался для настройки тестового окружения.
**config.ini** - входные данные для подключения к БД.
**cpabfile** - список зависимостей для установки, используется в *init.pl*.
**test.pl** - основная программа.
**libs/Lib1.pm** - процедуры в отдельном модуле.
**log/out** - лог файл из задания.
