# Windows PowerShell Build Farm

Скрипт, позволяющий модифицировать WIM-образ системы.

## Параметры

- `-ADK`  
  Путь к установленному [Windows ADK](https://docs.microsoft.com/en-us/windows-hardware/get-started/). По умолчанию: `$PSScriptRoot\_META\ADK`.
- `-CPU`  
  Архитектура образа WIM (`x86`, `amd64`, `arm64`). По умолчанию: `amd64`.
- `-WN`  
  Название файла WIM. По умолчанию: `install`.
- `-WL`  
  Язык системы, интегрированной в WIM. По умолчанию: `en-us`.
- `-NoWH`  
  Отключение вычисления хэш-суммы для WIM.
- `-AP`  
  Добавление `.cab` или `.msu` файлов в WIM.
- `-AD`  
  Добавление драйверов в WIM.
- `AA`  
  Добавление приложений в WIM (директория `%SYSTEMDRIVE%\_DATA\Apps`).
- `-RB`  
  Уменьшение размера хранилища компонентов WIM, путём удаления предыдущих версий компонентов.
- `-SH`  
  Сканирование образа WIM на предмет повреждения хранилища компонентов. *Не работает для образа WinPE.*
- `-SI`  
  Сохранение изменений в WIM.
- `-ESD`  
  Экспорт WIM файла в ESD формат.
- `WPE_AP`  
  Интеграция [дополнительных компонентов](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-adding-powershell-support-to-windows-pe) из ADK WinPE в образ `boot.wim`. *Только для образа WinPE.*

## Директории

- `BuildFarm`
  - `Apps` - Приложения.
  - `Drivers` - Хранилище драйверов.
  - `Logs` - Логи работы скрипта.
  - `Mount` - Директория для монтирования образа WIM.
  - `Temp` - Директория для временных файлов.
  - `Updates` - Хранилище обновлений.
  - `WIM` - Директория расположения файла WIM.

## Синтаксис

```powershell
.\BuildFarm.ps1 -AP -AD -RB -SH -SI
```

- Интегрировать обновления (`-AP`) и драйверы (`-AD`) в образ системы.
- Уменьшить размер хранилища компонентов (`-RB`).
- Запустить сканирование образа на предмет повреждения хранилища компонентов (`-SH`).
- Сохранить все изменения (`-SI`).

```powershell
.\BuildFarm.ps1 -AP -RB -SH -SI
```

- Интегрировать обновления в образ системы (`-AP`).
- Уменьшить размер хранилища компонентов (`-RB`).
- Запустить сканирование образа на предмет повреждения хранилища компонентов (`-SH`).
- Сохранить все изменения (`-SI`).

```powershell
.\BuildFarm.ps1 -AP -RB -SH -SI -ESD
```

- Интегрировать обновления (`-AP`).
- Уменьшить размер хранилища компонентов (`-RB`).
- Запустить сканирование образа на предмет повреждения хранилища компонентов (`-SH`).
- Сохранить все изменения (`-SI`).
- Экспортировать WIM файл в ESD формат (`-ESD`).

### Работа с WinPE

```powershell
.\BuildFarm.ps1 -WN 'boot' -WPE_AP -RB -SI
```

- Подключить образ WIM под названием `boot`, что является **WinPE** (`-WN 'boot'`).
- Интегрировать в образ WinPE дополнительные компоненты **Windows ADK** (`-AP_ADK`).
- Уменьшить размер хранилища компонентов (`-RB`).
- *...Произвести работы с образом...*
- Сохранить все изменения (`-SI`).

```powershell
.\BuildFarm.ps1 -WN 'boot' -SI
```

- Подключить образ WIM под названием `boot`, что является **WinPE** (`-WN 'boot'`).
- *...Произвести работы с образом...*
- Сохранить все изменения (`-SI`).
