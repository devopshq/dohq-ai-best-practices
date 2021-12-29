#!/usr/bin/env python
# -*- coding: utf-8 -*-
# (c) DevOpsHQ, 2021

import os
import re
import argparse
import sys


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--count_to_actualize", action="store", default=1, required=False)
    parser.add_argument("--level", action="store", default="Medium", required=False)
    parser.add_argument("--exploit", action="store", default='"."', required=False)
    parser.add_argument("--is_suspected", action="store", default="false", required=False)
    parser.add_argument("--approval_state", action="store", default="[^2]", required=False)
    args = parser.parse_args()
    return args


def create_json(args):
    json = '''
[
    {
        "CountToActualize": $count_to_actl,
        "Scopes": [
            {
                "Rules": [
                    {
                        "Field": "Level", 
                        "Value": "$level",
                        "IsRegex": false
                    },
                    {
                        "Field": "Exploit",
                        "Value": $exploit,
                        "IsRegex": true
                    },
                    {
                        "Field": "IsSuspected",
                        "Value": "$is_suspected",
                        "IsRegex": false
                    },
                    {
                        "Field": "ApprovalState",
                        "Value": "$approval_state",
                        "IsRegex": true
                    }
                ]
            }
        ]
    }
]
'''
    json = re.sub(r"\$count_to_actl", str(args.count_to_actualize), json, 1)
    json = re.sub(r"\$level", str(args.level), json, 1)
    json = re.sub(r"\$exploit", str(args.exploit), json, 1)
    json = re.sub(r"\$is_suspected", str(args.is_suspected), json, 1)
    json = re.sub(r"\$approval_state", str(args.approval_state), json, 1)

    return json


def print_info(count_to_actualize,
               level,
               exploit,
               is_suspected,
               approval_state):
    print("-" * 50)
    print("[INFO]: CountToActualize:  {count_to_actualize}".format(**locals()))
    print("[INFO]: Level:             {level}".format(**locals()))
    print("[INFO]: Exploit:           {exploit}".format(**locals()))
    print("[INFO]: IsSuspected:       {is_suspected}".format(**locals()))
    print("[INFO]: ApprovalState:     {approval_state}".format(**locals()))
    print("-" * 50)


def main(args):
    print("[INFO]: Start generating policy")

    print_info(count_to_actualize=args.count_to_actualize,
               level=args.level,
               exploit=args.exploit,
               is_suspected=args.is_suspected,
               approval_state=args.approval_state)

    json_file = create_json(args)

    file_name = "policy.json"

    if "{file_name}".format(**locals()) in os.listdir("."):
        sys.stderr.write("[ERROR]: File exists\n")
    else:
        proj = open("{file_name}".format(**locals()), "a")
        proj.write(json_file)
        proj.close()
        print("[INFO]: File {proj.name} was generated successfully".format(**locals()))


if __name__ == '__main__':
    arguments = parse_args()
    main(arguments)
