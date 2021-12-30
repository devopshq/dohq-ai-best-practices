#!/usr/bin/env python
# -*- coding: utf-8 -*-
# (c) Positive Technologies, 2020

import sys
import os
import re
import argparse

import platform


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--projectname",
                        action="store",
                        help="The name of project",
                        required=True)
    parser.add_argument("--language",
                        action="store",
                        help="Programming language to find in project",
                        required=True)
    parser.add_argument("--path",
                        action="store",
                        help="Path to project for scan",
                        default="./",
                        required=False)
    parser.add_argument("--exclude-formats",
                        action="store",
                        help="Whether to exclude non-sources files from scanning (True or False)",
                        default="True",
                        required=False)
    parser.add_argument("--excluded-paths",
                        action="store",
                        nargs="+",
                        help="Exclude certain files and folders from scan. "
                             "Use single \\ with apostrophes and double \\ with quotes "
                             "(e.g. '\\devops-tools' "
                             '"\\\\.git\\\\")',
                        required=False)
    arguments = parser.parse_args()
    return arguments


def check_platform(os_type):
    if os_type == 'Windows':
        return "Windows"
    else:
        return "Linux"


def check_args(projectname, language, languages, path_to_folder):
    if "{projectname}.aiproj".format(**locals()) in os.listdir("."):
        print("-" * 50)
        print("[WARNING]: File {projectname}.aiproj exists".format(**locals()))
        print("           Try to overwrite")
        print("-" * 50)
    if language in languages:
        print("[INFO]: Arguments is correct")
    else:
        sys.stderr.write("[ERROR]: Unknown language\n")
        sys.exit(1)

# TODO: IsUsePublicAnalysisMethod вынести в args
def create_json(projectname, language, exclude_formats, excluded_paths_list):
    config = r'''{
    "ProjectName": "$ProjectName",
    "ProgrammingLanguage": "$LANG",
    "ScanAppType": "Configuration, Fingerprint, PmTaint, DependencyCheck, $COND",
    "Site": "http://localhost",
    "IsDownloadDependencies": true,

    "IsUsePublicAnalysisMethod": true,
    "IsUseEntryAnalysisPoint": true,

    "ScanUnitTimeout": 360,
    "PreprocessingTimeout": 60,
    "CustomParameters": $CUSTOM,

    "SkipFileFormats": $EXCLUDED_FILE_FORMATS,
    "SkipFilesFolders": ["\\devops-tools", "\\.git\\", "\\.gitignore", "\\.gitmodules", "\\.gitattributes", "\\$tf\\", "\\$BuildProcessTemplate\\", "\\.tfignore"$EXCLUDED_FILES_FOLDERS],

    "DisabledPatterns": ["145", "146", "148", "149"],
    "DisabledTypes": [],

    "UseIncrementalScan": true,
    "FullRescanOnNewFilesAdded": true,

    "ConsiderPreviousScan": true,
    "HideSuspectedVulnerabilities": false,
    "UseIssueTrackerIntegration": false,

    "IsUnpackUserPackages": false,
    "JavaParameters": null,
    "JavaVersion": 0,
    "UseJavaNormalizeVersionPattern": "true",
    "JavaNormalizeVersionPattern": "-\\d+(\\.\\d+)*",
    
    "JavaScriptProjectFile": null,
    "JavaScriptProjectFolder": null,

    "UseTaintAnalysis": true,
    "UsePmAnalysis": true,
    "DisableInterpretCores": false,

    "UseDefaultFingerprints": true,
    "UseCustomYaraRules": false,

    "CustomHeaders": [["", ""]],
    "Authentication": {
        "auth_item": {
            "domain": null,
            "credentials": {
                "cookie": null,
                "type": 2,
                "login": {
                    "name": null,
                    "value": null,
                    "regexp": null,
                    "is_regexp": false
                },
                "password": {
                    "name": null,
                    "value": null,
                    "regexp": null,
                    "is_regexp": false
                }
            },
            "test_url": null,
            "form_url": null,
            "form_xpath": ".//form",
            "regexp_of_success": null
        }
    },
    "ProxySettings": {
        "IsEnabled": false,
        "Host": null,
        "Port": null,
        "Type": 0,
        "Username": null,
        "Password": null
    },

    "RunAutocheckAfterScan": false,
    "AutocheckSite": "http://localhost",
    "AutocheckCustomHeaders": [["", ""]],
    "AutocheckAuthentication": {
        "auth_item": {
            "domain": null,
            "credentials": {
                "cookie": null,
                "cookies": null,
                "type": 2,
                "login": {
                    "name": null,
                    "value": null,
                    "regexp": null,
                    "is_regexp": false
                },
                "password": {
                    "name": null,
                    "value": null,
                    "regexp": null,
                    "is_regexp": false
                }
            },
            "test_url": null,
            "form_url": null,
            "form_xpath": ".//form",
            "regexp_of_success": null
        }
    },
    "AutocheckProxySettings": {
        "IsEnabled": false,
        "Host": null,
        "Port": null,
        "Type": 0,
        "Username": null,
        "Password": null
    },

    "SendEmailWithReportsAfterScan": false,
    "CompressReport": false,

    "EmailSettings": null,

    "ReportParameters": {
        "SaveAsPath": null,
        "UseElectronicSignature": false,
        "CertificatePath": null,
        "Password": null,
        "ShowSignatureTime": false,
        "SignatureReason": null,
        "Location": null,
        "DoSignatureVisible": false,
        "IncludeDiscardedVulnerabilities": false,
        "IncludeSuppressedVulnerabilities": true,
        "IncludeSuspectedVulnerabilities": false,
        "IncludeGlossary": false,
        "ConverHtmlToPdf": false,
        "RemoveHtml": false,
        "CreatePdfPrintVersion": false,
        "MakeAFReport": false,
        "IncludeDFD": false
    }
}
'''  # noqa
    json = re.sub(r"\$ProjectName", projectname, config, 1)
    json = re.sub(r"\$LANG", language, json, 1)

    if language == "Php":
        json = re.sub(r", \$COND", ", Php", json, 1)
    elif language == "Java":
        json = re.sub(r", \$COND", ", Java", json, 1)
    elif language == "JavaScript":
        json = re.sub(r", \$COND", ", JavaScript", json, 1)
    elif language == "Csharp" or language == "Vb":
        json = re.sub(r", \$COND", ", CSharp", json, 1)
    else:
        json = re.sub(r", \$COND", "", json, 1)

    if language == "Python":
        json = re.sub(r"\$CUSTOM", r'"--multifile"', json, 1)
    else:
        json = re.sub(r"\$CUSTOM", "null", json, 1)


    excluded_formats_list = '["*.7z", "*.bmp", "*.dib", "*.dll", "*.doc", "*.docx", "*.exe", "*.gif", "*.ico", ' \
                            '"*.jfif", "*.jpe", "*.jpe6", "*.jpeg", "*.jpg", "*.odt", "*.pdb", "*.pdf", "*.png", ' \
                            '"*.rar", "*.swf", "*.tif", "*.tiff", "*.zip"]'

    try:
        print("[INFO]: Exclude non-source files from scanning:  {exclude_formats}".format(**locals()))
        if exclude_formats in ('FALSE', 'False', 'false'):
            json = re.sub(r"\$EXCLUDED_FILE_FORMATS", "null", json, 1)
        elif exclude_formats in ('TRUE', 'True', 'true'):
            json = re.sub(r"\$EXCLUDED_FILE_FORMATS", excluded_formats_list, json, 1)
        else:
            raise ValueError()
    except (ValueError, Exception):
        print('[WARNING]: You have specified an invalid value. Used "True" as the default.')
        json = re.sub(r"\$EXCLUDED_FILE_FORMATS", excluded_formats_list, json, 1)

    try:
        print("[INFO]: Excluded files and folders list:  {excluded_paths_list}".format(**locals()))
        if excluded_paths_list is not None:
            excluded_paths_string = ''
            for excluded_item in excluded_paths_list:
                # Take raw value and remove apostrophes
                prepared_excluded_item = repr(excluded_item).replace("'", "")
                excluded_paths_string = excluded_paths_string + r', "{prepared_excluded_item}"'.format(**locals())
            json = json.replace("$EXCLUDED_FILES_FOLDERS", excluded_paths_string, 1)
        else:
            json = json.replace("$EXCLUDED_FILES_FOLDERS", '', 1)
    except (ValueError, Exception):
        print('[WARNING]: Something went wrong! The default values are used.')
        json = json.replace("$EXCLUDED_FILES_FOLDERS", '', 1)

    return json


def print_info(projectname, language, path_to_file):
    if path_to_file == '':
        folder = './'
    print("-" * 50)
    print("[INFO]: Project name: {projectname}".format(**locals()))
    print("[INFO]: File name:    {projectname}.aiproj".format(**locals()))
    print("[INFO]: Language:     {language}".format(**locals()))
    print("[INFO]: Path:         {path_to_file}".format(**locals()))
    print("-" * 50)


def main(prj, lang, path, exclude_formats, excluded_paths_list):
    # ---------- Variables ----------
    #lang = lang.lower()
    langs = ["Kotlin", "Java", "Swift", "Csharp", "Go", "ObjectiveC", "Vb", "JavaScript", "Sql", "CPlusPlus", "Php", "Python"]
    os_type = platform.system()

    # ------------- Run -------------

    check_args(prj, lang, langs, path)
    json_file = create_json(prj, lang, exclude_formats, excluded_paths_list)
    print_info(prj, lang, path)

    proj = open("{prj}.aiproj".format(**locals()), "w")
    proj.write(json_file)
    proj.close()
    print("[INFO]: File {proj.name} was generated successfully".format(**locals()))


if __name__ == '__main__':
    print("[INFO]: Start generating project")
    args = parse_args()
    main(
        prj=args.projectname,  # Project name
        lang=args.language,  # Language
        path=args.path,  # Path to folder
        exclude_formats=args.exclude_formats,  # Exclusion non-sources files from scanning (on/off)
        excluded_paths_list=args.excluded_paths  # Exclusion paths from scanning
    )