# Windows PowerShell BuildFarm

Скрипт, позволяющий модифицировать WIM образ системы.

## Параметры

- `-AddPackages` `-AP`  
  Добавление `.cab` или `.msu` файлов в Windows WIM.
- `-AddDrivers` `-AD`  
  Добавление драйверов в Windows WIM.
- `-ResetBase` `-RB`  
  Уменьшение размера хранилища компонентов Windows WIM, путём удаления предыдущих версий компонентов.
- `-ScanHealth` `-SH`  
  Сканирование образа Windows WIM на предмет повреждения хранилища компонентов.
- `-SaveImage` `-SI`  
  Сохранение изменений в Windows WIM.
- `-ExportToESD` `-ESD`  
  Экспорт WIM файла в ESD формат.

## Директории

- `BuildFarm`
  - `Apps` - Приложения.
  - `Drivers` - Хранилище драйверов.
  - `ISO` - ISO образа системы.
  - `Logs` - Логи работы скрипта.
  - `Mount` - Директория для монтирования Windows WIM.
  - `Temp` - Директория для временных файлов.
  - `Updates` - Хранилище обновлений.
  - `WIM` - Директория расположения WIM файла.

## Синтаксис

Интегрировать обновления и драйверы в образ системы. Уменьшить размер хранилища компонентов. Запустить сканирование образа. Сохранить все изменения.

```
wim.build.ps1 -AP -AD -RB -SH -SI
```

Интегрировать обновления в образ системы. Уменьшить размер хранилища компонентов. Запустить сканирование образа. Сохранить все изменения.

```
wim.build.ps1 -AP -RB -SH -SI
```

Интегрировать обновления. Уменьшить размер хранилища компонентов. Запустить сканирование образа. Сохранить все изменения. Экспортировать WIM файл в ESD формат.

```
wim.build.ps1 -AP -RB -SH -SI -ESD
```
