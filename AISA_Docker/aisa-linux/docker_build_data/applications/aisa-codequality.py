#!/usr/bin/env python
# -*- coding: utf-8 -*-
# (c) DevOpsHQ, 2020

import json
import argparse
from pathlib import Path


def convert_items(items):
    for i in items:
        yield {
            "description": f"[{i['Level']['DisplayName']}] {i['Type']['DisplayName']}",
            "fingerprint": i['Id'],
            "location": {
                "path": i['SourceFile'].split(':')[0].replace('\\', '/').replace('./', '').strip(),
                "lines": {
                    "begin": i.get('BeginLine', i.get('NumberLine'))
                }
            }
        }


def read_reports(input_folder):
    for p in Path(input_folder).resolve().glob('*.json'):
        with p.open(encoding='utf-8-sig') as f:
            yield from convert_items(json.load(f)['Items'])


def main(input, output):
    result = list(read_reports(input))

    with open(output, 'w', encoding='utf-8') as f:
        json.dump(result, f)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', "--input_folder", action="store", help="The name of reports folder", required=True)
    parser.add_argument('-o', "--output_file", action="store", help="The name of json file",
                        required=True)
    arguments = parser.parse_args()
    return arguments


if __name__ == '__main__':
    args = parse_args()
    main(
        input=args.input_folder,  # Folder with json report from aisa
        output=args.output_file  # Output json file for code quality
    )
