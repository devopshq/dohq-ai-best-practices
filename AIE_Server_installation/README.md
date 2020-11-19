# PT AI Install Wizard
Автоматический установщик для анализатора кода Positive Technologies Application Inspector Enterprise.

Раздел документации и скрипты инсталляции PT AI сопровождает Aleksandr Khudyshkin (AKhudyshkin@ptsecurity.com, [@alexkhudyshkin](https://github.com/alexkhudyshkin)). У него же вы можете запросить сертификаты для установки PT AI. 


Убедитесь, что ваш сервер соотвествует рекомендуемым системным требованиям

| PT AI Enterprise Server                                     |    PT AI Enterprise Agent                                                   |
|-------------------------------------------------------------|-----------------------------------------------------------------------------|
| Процессор Intel Core i7 с частотой 3,2 ГГц или аналоги      | Процессор Intel Core i7 с частотой 3,2 ГГц или аналоги                      |
| От 8 ГБ оперативной памяти                                  | От 8 ГБ оперативной памяти                                                  |
| Сетевой адаптер от 10 Мбит/с                                | Сетевой адаптер от 10 Мбит/с                                                |
| От 200 ГБ на жестком диске                                  | Браузер: Microsoft Edge, Mozilla Firefox 46 и выше, Google Chrome 50 и выше |
| 64-разрядная версия Windows Server 2012 R2 и выше           |                                                                             |
| Средство автоматизации Windows PowerShell версии 5.0 и выше |                                                                             |

Для запуска:
- Выполнить вход в Windows под учётной записью с правами администратора.
- Дополнительно установить следующие программы:

| Программное обеспечение                          | Ссылка на скачивание                                                                     |
|--------------------------------------------------|------------------------------------------------------------------------------------------|
| VC Redist x64                                    | https://aka.ms/vs/16/release/vc_redist.x64.exe                                           |
| Win64 OpenSSL v1.1.1h Light                      | https://slproweb.com/products/Win32OpenSSL.html                                          |
| .NET Framework 4.8 (Windows Server 2012 R2 only) | https://dotnet.microsoft.com/download/dotnet-framework/thank-you/net48-offline-installer |
| KB3191564 (Windows Server 2012 R2 only)          | http://www.catalog.update.microsoft.com/Search.aspx?q=3191564                            |

- Запустить Powershell с правами администратора.
- Запустить скрипт инсталляции, пример запуска:
```powershell
.\AI-one-click-install.ps1 -aiepath C:\Users\Administrator\Downloads\AIE -toolspath C:\TOOLS
# aiepath 	- путь до каталога с дистрибутивом AI (там где папки aic/aiv/aie)
# toolspath	– каталог, куда будут перемещены артефакты установки (сертификаты, пароли)
```
```powershell
# Если скрипт не запускается из-за ограничений доменной политики, выполните следующую команду
Set-ExecutionPolicy Unrestricted Process
```
