# Использование AI.Cli.Plugin для анализа кода в сборочном процессе GitLab

Здесь описан пример интеграции сканирования кода с PT Application Inspector и плагином AI.Cli.Plugin в сборочный процесс GitLab посредством подключения шаблонов. Интеграция состоит из нескольких этапов:
1. Сборка docker-образа плагина
2. Настройка шаблонов сканирования
3. Подключение шаблонов сканирования в pipeline ваших проектов

## Сборка docker-образа плагина
Для сборки вам потребуется:
1. Создать проект в GitLab с файлами из \AI-Plugin-dockerbuild
2. Задать переменные проекта
- DOCKER_USERNAME – логин для docker registry
- DOCKER_PASSWORD – пароль для docker registry
- REGISTRY_ADDRESS – адрес docker registry, например registry.ptsecurity.com
- AI_URN – адрес сервера PT AI, например ai.ptsecurity.com
- PLUGIN_TOKEN – токен доступа для плагина CI/CD, сгенерированный на сервере PT AI
3. Задать теги используемых GitLab Runners в файле .gitlab-ci.yml
4. Запустить сборку

## Настройка шаблонов сканирования
Все подробности о работе шаблонов и используемых в них параметрах см. в документе ptaiee_integrationscenario_ru.pdf.
Для подключения шаблонов сканирования вам потребуется:
1. Создать проект в GitLab с файлами из \AI-Templates
2. Задать теги используемых GitLab Runners во всех файлах
3. В файлах AI-Run-in-parallel.yml, AI-Information-Mode.yml, AI-Lock-Mode.yml, AI-Strictest-Mode.yml заменить путь к вашему проекту, созданному в п.1, в блоке include:
```sh
project: 'ptai-demo/pt-ai-demo-templates'
```

## Подключение шаблонов сканирования в pipeline ваших проектов
Рассмотрим этот этап на примере проекта https://github.com/ptssdl/App01.git
Чтобы подключить анализ кода к проекту App01 вам потребуется:
1. Создать проект в GitLab, выполнив следующие команды
```sh
git clone https://github.com/ptssdl/App01.git
cd App01
git remote set-url origin https://<your_gitlab_address>/<project_group>/ptai-demo-App01.git
wget https://raw.githubusercontent.com/devopshq/dohq-ai-best-practices/master/GitLab_templates/AI.Cli.Plugin/demo-example.gitlab-ci.yml -O .gitlab-ci.yml
git add .
git commit -m "Initial commit"
git push -u origin master
```
2. Задать переменные проекта
- REGISTRY_ADDRESS – адрес docker registry, например registry.ptsecurity.com
- AI_GITLAB_BOT_TOKEN – токен доступа с правами на вызов API
- FTP_ADDRESS – адрес FTP сервера на веб-сервере Tomcat
- FTP_CREDENTIALS – учетные данные для подключения к FTP серверу
