# Windows PowerShell BuildFarm

Windows PowerShell BuildFarm - скрипт, позволяющий модифицировать WIM образ системы.

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
