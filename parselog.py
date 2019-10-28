#!/usr/bin/env python3

from pprint import pprint
import sys
import re

linepattern = '\[(.*?) (.*?) (.*?) (.*?):(.*?):(.*?) (.*?)\] \[(.*?)\] \[(.*?) (.*?):(.*?) (.*?)\] (.*?): (.*)'
ptids = []
for line in sys.stdin:
  splittedline = {'raw': line}
  try:
    s = re.match(linepattern,line).groups()
    time = float(s[5]) + 60*(int(s[4])+60*int(s[3]))
    ptid = s[9] + ':' + s[11]
    splittedline['time'] = time
    splittedline['ptid'] = ptid
    if ptid not in ptids:
      ptids.append(ptid)
    indent = ['|'] * len(ptids)
    indent[ptids.index(ptid)] = '*'
    indent = " ".join(indent)
  except AttributeError:
    pass

  print(indent,"  ",splittedline['ptid'],splittedline['time'],end='\r\n')

