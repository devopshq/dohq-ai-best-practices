#!/usr/bin/env python
# -*- coding: utf-8 -*-
# (c) DevOpsHQ, 2021

import os
import requests
import json
import argparse
import yaml
import texttable
from pathlib import Path


def teamcity_open_block():
    print()
    print("##teamcity[blockOpened name='Vulnerabilities table']")


def teamcity_close_block():
    print("##teamcity[blockClosed name='Vulnerabilities table']")
    print()

def set_security_rules(items_info, items_minor, items_major, items_critical, items_blocker, CI, settings):
    if settings is None:
        mapping = {'info': 'Potential',
                   'minor': 'Low',
                   'major': 'Medium',
                   'critical': 'High',
                   'blocker': ''}
        settings = {'info': 0,
                    'minor': 0,
                    'major': 0,
                    'critical': 0,
                    'blocker': 0}
    else:
        for p in Path('./').resolve().glob(settings):
            with p.open(encoding='utf-8-sig') as f:
                settings = yaml.full_load(f)  # .get('security gates')
                mapping = settings['threats mapping']
                settings = settings['security gates']
    try:
        print('INFO - The AI Security gates is:')
        x = texttable.Texttable()
        x.header(['Gitlab Ci Code Quality', 'AI Severity Rules'])
        for key, value in settings.items():
            x.add_row([key, value])
        print(x.draw())
    except AttributeError as e:
        print('ERROR - We have bad settings file')
        print(e)
        exit(1)

    len_info = {'info': f' {len(items_info)}'}
    len_minor = {'minor': f' {len(items_minor)}'}
    len_major = {'major': f' {len(items_major)}'}
    len_critical = {'critical': f' {len(items_critical)}'}
    len_blocker = {'blocker': f' {len(items_blocker)}'}
    len_total = len_info, len_minor, len_major, len_critical, len_blocker

    CI.result_blocker_vars = []
    CI.block_mr = False

    for key, value in settings.items():
        for item in len_total:
            for i in item.items():
                if i[0] in key:
                    if value != 0:
                        if value < int(i[1]):
                            CI.block_mr = True
                            CI.result_blocker_vars.append(key)
                            CI.security_gates = 'Check Security Gates: FAILED'
                            print(f'WARNING - Exceeded the maximum number of allowed "{key}" level vulnerabilities')

    CI.result_blocker_body = '<hr><pre>**Threats Mapping:**'

    for key, value in mapping.items():
        CI.result_blocker_body = CI.result_blocker_body + f'<br>&ensp;&ensp;&ensp;&ensp;**{key}**: *{value}*'

    CI.result_blocker_body = CI.result_blocker_body + f'<br>**Security Gates:**'

    for key, value in settings.items():
        CI.result_blocker_body = CI.result_blocker_body + f'<br>&ensp;&ensp;&ensp;&ensp;**{key}**: *{value}*'

    CI.result_blocker_body = CI.result_blocker_body + f'<br></pre><hr>'


def get_items(items, CI):
    items_total = []
    items_info = []
    items_minor = []
    items_major = []
    items_critical = []
    items_blocker = []

    emoji = {'info': ':white_small_square:',
             'minor': ':small_blue_diamond:',
             'major': ':small_orange_diamond:',
             'critical': ':small_red_triangle:',
             'blocker': ':no_entry_sign:'}

    for key, value in emoji.items():
        for data in items:
            if key in data['severity']:
                row = f"{value} {data['description']} <br>in [{data['location']['path']}:" \
                      f"{data['location']['lines']['begin']}]({CI.project_url}/blob/" \
                      f"{CI.commit_sha}/{data['location']['path']}#L{data['location']['lines']['begin']})<br>"
                items_total.append(row)
                if key == 'info':
                    items_info.append(row)
                if key == 'minor':
                    items_minor.append(row)
                if key == 'major':
                    items_major.append(row)
                if key == 'critical':
                    items_critical.append(row)
                if key == 'blocker':
                    items_blocker.append(row)
            else:
                pass

    table = texttable.Texttable()
    table.header(['Level', 'Description', 'location'])
    for data in items:
        row = [f"{data['severity']}", f"{data['description']}",
               f"{data['location']['path']}#L{data['location']['lines']['begin']}"]
        table.add_row(row)
    table.set_cols_width((8, 50, 90))

    if CI.ci_name == 'TeamCity':
        teamcity_open_block()
        print(table.draw())
        teamcity_close_block()

    if len(items_total) == 0:
        print('WARNING - json file with vulnerabilities not found')
        print('Check Security Gates: PASSED')
        exit(0)

    return items_total, items_info, items_minor, items_major, items_critical, items_blocker


def convert_to_markdown(items_total, items_info, items_minor, items_major, items_critical, items_blocker, CI,
                        input_folder):

    print(f"INFO - Application Inspector detect {len(items_total)} vulnerabilities:\n\n"
          f"     {len(items_blocker)} Blocker\n"
          f"     {len(items_critical)} High\n"
          f"     {len(items_major)} Medium\n"
          f"     {len(items_minor)} Low\n"
          f"     {len(items_info)} Potential\n\n")

    if CI.commit_sha is not None:
        short_commit_sha = CI.commit_sha[:9]
    else:
        print('WARNING - SHA not found, no threads were generated.')
        print(CI.security_gates)
        exit(0)

    if CI.html_report is not None:
        if CI.ci_name == 'GitLab':
            gitlab_artifacts_url = os.environ.get('CI_JOB_URL')
            CI.gitlab_artifacts_url = f'{gitlab_artifacts_url}/artifacts/file/{input_folder}/ai_full_report.html'
            CI.footer = f'<hr>:chart_with_upwards_trend: See full [AI HTML report]({CI.gitlab_artifacts_url}) ' \
                        f'in [GitLab job]({gitlab_artifacts_url}).'
        elif CI.ci_name == 'TeamCity':
            CI.tc_build_url = f'{CI.teamcity_server_url}/viewLog.html?buildTypeId={CI.teamcity_buildType_id}&buildId=' \
                              f'{CI.teamcity_build_id}'
            CI.tc_artifacts_url = f'{CI.teamcity_server_url}/repository/download/{CI.teamcity_buildType_id}/' \
                                  f'{CI.teamcity_build_id}:id/ai_full_report.html'
            CI.footer = f'<hr>:chart_with_upwards_trend: See full [AI HTML report]({CI.tc_artifacts_url}) ' \
                        f'in [TeamCity build]({CI.tc_build_url}).'
        else:
            CI.footer = '<hr>:chart_with_upwards_trend: See full AI html-report in local job artifacts.'
    else:
        CI.footer = ''

    if CI.block_mr is True:
        result_blocker = '<details><summary>:no_entry_sign: Merge Request has been locked by ' \
                         'current AI Security Gates' \
                         f'</summary>{CI.result_blocker_body}</details>'
    else:
        result_blocker = '<br>'

    result = f"![](https://www.ptsecurity.com/local/templates/pt_corp2017/build/img/favicon.ico)" \
             f" Application Inspector detect **{len(items_total)}** vulnerabilities for *[{short_commit_sha}]" \
             f"({CI.project_url}/-/commit/{CI.commit_sha})*:<br>{result_blocker}" \
             f"**Found vulnerabilities:**<br>" \
             f":small_red_triangle: **{len(items_blocker)}** Blocker<br>" \
             f":small_red_triangle_down: **{len(items_critical)}** High<br>" \
             f":small_orange_diamond: **{len(items_major)}** Medium<br>" \
             f":small_blue_diamond: **{len(items_minor)}** Low<br>" \
             f":white_small_square: **{len(items_info)}** Potential<br>" \
             f"<details><summary>More results...</summary><p>"
    result_footer = f'</details>{CI.footer}'

    if len(items_blocker) > 0:
        result_blocker = '<hr><details><summary>:small_red_triangle: Blocker vulnerabilities list:</summary><p>'
        for x in items_blocker:
            result_blocker = result_blocker + x
        result_blocker = result_blocker + '</p></details>'
    else:
        result_blocker = ''
    if len(items_critical) > 0:
        result_critical = '<hr><details><summary>:small_red_triangle: High vulnerabilities list:</summary><p>'
        for x in items_critical:
            result_critical = result_critical + x
        result_critical = result_critical + '</p></details>'
    else:
        result_critical = ''
    if len(items_major) > 0:
        result_major = '<hr><details><summary>:small_orange_diamond: Medium vulnerabilities list:</summary><p>'
        for x in items_major:
            result_major = result_major + x
        result_major = result_major + '</p></details>'
    else:
        result_major = ''
    if len(items_minor) > 0:
        result_minor = '<hr><details><summary>:small_blue_diamond: Low vulnerabilities list:</summary><p>'
        for x in items_minor:
            result_minor = result_minor + x
        result_minor = result_minor + '</p></details>'
    else:
        result_minor = ''
    if len(items_info) > 0:
        result_info = '<hr><details><summary>:white_small_square: Potential vulnerabilities list:</summary><p>'
        for x in items_info:
            result_info = result_info + x
        result_info = result_info + '</p></details>'
    else:
        result_info = ''

    result = result + result_blocker + result_critical + result_major + result_minor + result_info + result_footer

    return result


def create_gitlab_thread(result, gitlab_token, CI):
    print('INFO - Script started generating Gitlab Merge Request threads.')
    headers = {'Content-Type': "application/x-www-form-urlencoded; charset=UTF-8", "attachment": "filename=file.md"}
    body = {'body': '{result}'.format(**locals())}

    gitlab_token = '&access_token=' + gitlab_token
    pages = '&per_page=100'

    opened_merge_requests = []

    count = 1
    while count < 40:
        page = "&page={count}".format(**locals())
        count += 1
        merge_requests_url = f"{CI.api_url}/projects/{CI.project_id}/merge_requests?{gitlab_token}{pages}{page}"

        response = requests.get(url=merge_requests_url, headers=headers)
        if response.status_code == 404:
            print('WARNING - Merge requests not found. Maybe you have no access to the GitLab projects or all merge '
                  'requests are merged..')
            print(f'DEBUG - URL: {merge_requests_url}')
            print(CI.security_gates)
            exit(0)

        json_response_body = json.loads(response.content.decode('utf-8'))

        for merge_request in json_response_body:
            if merge_request['state'] == 'opened':
                opened_merge_requests.append(merge_request)
        if len(json_response_body) == 0:
            break

    if len(opened_merge_requests) == 0:
        print('INFO - Opened merge requests not found')
        print(CI.security_gates)
        exit(0)

    founded_mr_with_needed_sha = 0
    for mr in opened_merge_requests:
        if mr['sha'] == CI.commit_sha:
            founded_mr_with_needed_sha += 1
            iid = mr['iid']
            mr_list = []
            modify = 0
            count = 1

            while count < 100:
                page = "&page={count}".format(**locals())
                count += 1
                merge_requests_url = f"{CI.api_url}/projects/{CI.project_id}/merge_requests/{iid}/discussions?" \
                                     f"{gitlab_token}{pages}{page}"
                response = requests.get(url=merge_requests_url, headers=headers)
                json_response_body = json.loads(response.content.decode('utf-8'))

                mr_list.append(json_response_body)

                if len(json_response_body) == 0:
                    break

            for x in mr_list[0]:
                if 'Application Inspector detect' in x['notes'][0]['body']:
                    new_merge_requests_url = f"{CI.api_url}/projects/{CI.project_id}/merge_requests/{iid}/" \
                                             f"discussions/{x['id']}/notes/{x['notes'][0]['id']}?" \
                                             f"{gitlab_token}"
                    requests.put(url=new_merge_requests_url, data=body, headers=headers)

                    if CI.block_mr is True:
                        if 'Draft: ' in str(mr['title']):
                            print('INFO - Merge request has been drafted already')
                        else:
                            title = f'Draft: {mr["title"]}'
                            new_title = {'title': '{title}'.format(**locals())}

                            blocked_merge_request_url = f"{CI.api_url}/projects/{CI.project_id}/merge_requests/{iid}?" \
                                                        f"{gitlab_token}"
                            requests.put(url=blocked_merge_request_url, data=new_title, headers=headers)
                            print(F"INFO - State on {CI.project_url}/-/merge_requests/{iid} was changed to draft.")
                    modify = 1
                    print(F"INFO - Thread on {CI.project_url}/-/merge_requests/{iid} was modified.")
                else:
                    pass
            if modify == 0:
                merge_requests_url = f"{CI.api_url}/projects/{CI.project_id}/merge_requests/{iid}/discussions?" \
                                     f"{gitlab_token}"
                response = requests.post(url=merge_requests_url, data=body, headers=headers)
                json_response_body = json.loads(response.content.decode('utf-8'))
                if CI.block_mr is True:
                    if 'Draft: ' in str(mr['title']):
                        print('INFO - Merge request has been drafted already')
                    else:
                        title = f'Draft: {mr["title"]}'
                        new_title = {'title': '{title}'.format(**locals())}

                        blocked_merge_request_url = f"{CI.api_url}/projects/{CI.project_id}/merge_requests/{iid}?" \
                                                    f"{gitlab_token}"
                        requests.put(url=blocked_merge_request_url, data=new_title, headers=headers)
                        print(F"INFO - State on {CI.project_url}/-/merge_requests/{iid} was changed to draft.")
                print(F"INFO - Thread on {CI.project_url}/-/merge_requests/{iid} was created.")
    if founded_mr_with_needed_sha > 0:
        pass
    else:
        print('WARNING - SHA not found, no threads were generated.')


def convert_items(items, settings):
    try:
        print('INFO - The threats mapping is:')
        x = texttable.Texttable()
        x.header(['Gitlab Ci Code Quality', 'AI Threats Mapping'])
        for key, value in settings.items():
            x.add_row([key, value])
        print(x.draw())
    except AttributeError as e:
        print('ERROR - We have bad settings file')
        print(e)
        exit(1)

    for key, value in settings.items():
        for i in items:
            if i['Level']['DisplayName'] in value:
                yield {
                    "description": f"[{i['Level']['DisplayName']}] {i['Type']['DisplayName']}",
                    "fingerprint": i['Id'],
                    "severity": f"{key}",
                    "location": {
                        "path": i['SourceFile'].split(':')[0].replace('\\', '/').replace('./', '').strip(),
                        "lines": {
                            "begin": i.get('BeginLine', i.get('NumberLine'))
                        }
                    }
                }
            else:
                pass


def read_reports(input_folder, settings):
    dir_files = os.listdir(input_folder)
    files = []

    if settings is None:
        settings = {'info': 'Potential',
                    'minor': 'Low',
                    'major': 'Medium',
                    'critical': 'High',
                    'blocker': ''}
    else:
        for p in Path('./').resolve().glob(settings):
            with p.open(encoding='utf-8-sig') as f:
                settings = yaml.full_load(f).get('threats mapping')

    for f in dir_files:
        if '.json' in f:
            f = input_folder + '/' + f
            files.append(f)
    if len(files) > 0:
        file = max(files, key=os.path.getctime)
        for p in Path('./').resolve().glob(file):
            with p.open(encoding='utf-8-sig') as f:
                x = json.load(f)
                try:
                    yield from convert_items(x['Items'], settings)
                except TypeError:
                    print('ERROR - In input folder we have bad json file')
                    exit(1)
    else:
        print('WARNING - Json report not found.')
        print('Check Security Gates: Unknown')
        exit(0)


def main(input_folder, output_file, gitlab_token, settings_file, block_mr, income_args):
    print('INFO - aisa-codequality started successfully!')

    def define_ci_server(arguments):
        """
        Return CI server type with specific environment
        """
        # Check predefined environment variable to define CI server, TC by default, Gitlab CI by checking CI variable
        # https://docs.gitlab.com/ee/ci/variables/
        if os.environ.get('CI', False):
            return GitlabCI()
        elif arguments.ci_type == 'GitLab':
            return GitlabCI()
        elif arguments.ci_type == 'TeamCity':
            return TeamCity(arguments)
        else:
            return Local(arguments)

    class GitlabCI(object):
        def __init__(self):
            self.ci_name = 'GitLab'
            self.commit_sha = os.environ.get('CI_COMMIT_SHA')
            self.project_id = os.environ.get('CI_PROJECT_ID')
            self.project_url = os.environ.get('CI_PROJECT_URL')
            self.api_url = os.environ.get('CI_API_V4_URL')

    class TeamCity(object):
        def __init__(self, arguments):
            self.ci_name = 'TeamCity'
            self.commit_sha = arguments.commit_sha
            self.teamcity_server_url = arguments.teamcity_server_url
            self.teamcity_build_id = arguments.teamcity_build_id
            self.teamcity_buildType_id = arguments.teamcity_buildType_id
            self.project_id = arguments.gitlab_project_id
            self.project_url = arguments.gitlab_project_url
            self.api_url = arguments.gitlab_api_url

    class Local(object):
        def __init__(self, arguments):
            self.ci_name = 'Local'
            self.commit_sha = arguments.commit_sha
            self.project_id = arguments.gitlab_project_id
            self.project_url = arguments.gitlab_project_url
            self.api_url = arguments.gitlab_api_url

    CI = define_ci_server(income_args)
    CI.security_gates = 'Check Security Gates: PASSED'
    CI.html_report = os.path.join(input_folder, "ai_full_report.html")
    
    print('\n+-- Variables -----------------------------------+')
    print(f'   CI name:      {CI.ci_name}\n'
          f'   Commit sha:   {CI.commit_sha}\n'
          f'   Project ID:   {CI.project_id}\n'
          f'   Project URL:  {CI.project_url}\n'
          f'   API URL:      {CI.api_url}\n'
          f'   Input folder: {input_folder}\n')
    print('+------------------------------------------------+')

    print('INFO - Try to convert report to {output_file}.'.format(**locals()))
    result = list(read_reports(input_folder, settings_file))
    if len(result) == 0:
        print('INFO - Result is null'.format(**locals()))
    else:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(result, f), f.close()
        print('INFO - File {output_file} was generated.'.format(**locals()))

    if gitlab_token is None:
        print('INFO - Script was completed without Thread.\n       '
              'Please specify GitLab personal token for create threads.')
        print('Check Security Gates: Unknown')
        exit(0)

    items_total, items_info, items_minor, items_major, items_critical, items_blocker = get_items(result, CI)
    set_security_rules(items_info, items_minor, items_major, items_critical, items_blocker, CI, settings=settings_file)

    result = convert_to_markdown(items_total, items_info, items_minor, items_major, items_critical, items_blocker,
                                 CI, input_folder)
    if block_mr is False:
        CI.block_mr = False

    create_gitlab_thread(result, gitlab_token, CI)
    print('INFO - aisa-codequality completed successfully!')
    print(CI.security_gates)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', "--input_folder", action="store", required=False, default='.report',
                        help="The name of reports folder")
    parser.add_argument('-o', "--output_file", action="store", required=False, default='codequality.json',
                        help="The name of json file")
    parser.add_argument('-t', "--token", action="store", required=False, help="Gitlab CI builder Token")
    parser.add_argument('-s', "--settings_file", action="store", required=False, help="The name of settings file")
    parser.add_argument('-sha', "--commit_sha", action="store", required=False, help="The commit sha")
    parser.add_argument('-gpid', "--gitlab_project_id", action="store", required=False, help="Gitlab project id")
    parser.add_argument('-gpurl', "--gitlab_project_url", action="store", required=False, help="Gitlab project url")
    parser.add_argument('-gaurl', "--gitlab_api_url", action="store", required=False, help="Gitlab api url")
    parser.add_argument('-tcbid', "--teamcity_build_id", action="store", required=False,
                        help="TeamCity build id %teamcity.build.id%")
    parser.add_argument('-tcbtid', "--teamcity_buildType_id", action="store", required=False,
                        help="TeamCity project build id %system.teamcity.buildType.id%")
    parser.add_argument('-tcurl', "--teamcity_server_url", action="store", required=False, help="TeamCity server url")
    parser.add_argument('-ci', "--ci_type", action="store", required=False, default='Local',
                        help="Variable for define CI system (TeamCity, GitLab, etc.)")
    parser.add_argument('-b', "--block_mr", action="store", required=False, default=False,
                        help="Rename MR from `title` to `draft: title`")
    arguments = parser.parse_args()
    return arguments


if __name__ == '__main__':
    args = parse_args()
    main(
        input_folder=args.input_folder,  # Folder with json report from aisa
        output_file=args.output_file,  # Output json file for code quality
        gitlab_token=args.token,  # Folder with json report from aisa
        settings_file=args.settings_file,  # The name of yaml file with settings
        block_mr=args.block_mr,  # Rename MR from `title` to `draft: title`
        income_args=args
    )
